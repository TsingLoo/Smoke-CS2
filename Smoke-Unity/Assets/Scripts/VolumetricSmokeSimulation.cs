using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VolumetricSmokeSimulation : MonoBehaviour
{
    public enum SmokePhase
    {
        Idle,
        Precomputing,  // 预计算阶段
        Burst,         // 爆发阶段：快速扩张显示
        Spread,        // 扩散阶段：缓慢扩展显示
        Dissipate      // 消散阶段：逐渐淡出
    }

    static readonly Vector3Int[] AllDirs = {
        new Vector3Int(1,0,0), new Vector3Int(-1,0,0),
        new Vector3Int(0,0,1), new Vector3Int(0,0,-1),
        new Vector3Int(0,1,0), new Vector3Int(0,-1,0)
    };

    [SerializeField] Color TintColor = Color.white;

    [Header("Target Shape")]
    public Vector3 preferredSize = new Vector3(0.7f, 1.0f, 0.6f);
    public float roundness = 4.0f;

    [Header("Budget Settings")]
    [Tooltip("预计算的最大voxel数量")]
    public int maxPrecomputeBudget = 15000;
    
    [Tooltip("Burst阶段结束时显示的voxel比例 (相对于maxPrecomputeBudget)")]
    [Range(0.1f, 1.0f)]
    public float burstTargetRatio = 0.5f;
    
    [Tooltip("Spread阶段结束时显示的voxel比例")]
    [Range(0.1f, 1.0f)]
    public float spreadTargetRatio = 0.9f;

    [Header("Precompute Settings")]
    [Tooltip("预计算每帧处理的voxel数量")]
    public int precomputeVoxelsPerFrame = 500;

    [Header("Phase Timing")]
    public float burstDuration = 0.5f;
    public float spreadDuration = 3.0f;
    public float dissipateDuration = 2.0f;

    [Header("Phase Curves")]
    [Tooltip("Burst阶段的显示进度曲线 (时间0-1 → 显示比例0-1)")]
    public AnimationCurve burstProgressCurve = AnimationCurve.EaseInOut(0f, 0f, 1f, 1f);
    
    [Tooltip("Spread阶段的显示进度曲线")]
    public AnimationCurve spreadProgressCurve = AnimationCurve.EaseInOut(0f, 0f, 1f, 1f);
    
    [Tooltip("Dissipate阶段的透明度曲线")]
    public AnimationCurve dissipateAlphaCurve = AnimationCurve.EaseInOut(0f, 1f, 1f, 0f);

    [Header("Physics")]
    public LayerMask obstacleMask;
    [Range(0.1f, 0.9f)] public float collisionShrink = 0.5f;
    [Range(0.8f, 0.99f)] public float traceShrink = 0.95f;

    [Header("Gravity Control")]
    public float gravityBias = 10.0f;

    [Header("Density Control")]
    public AnimationCurve densityFalloff = new AnimationCurve(
        new Keyframe(0f, 1f),
        new Keyframe(1f, 0f)
    );

    [Header("References")]
    [SerializeField] SmokeVolumeShadowProxy shadowProxy;
    [SerializeField] SmokeVolumeManager volumeManager;

    // === Runtime State (Public Read-Only) ===
    public SmokePhase CurrentPhase { get; private set; } = SmokePhase.Idle;
    public float PhaseProgress { get; private set; } = 0f;
    public int PrecomputedCount => precomputedVoxels.Count;
    public int VisibleCount { get; private set; } = 0;
    public float PrecomputeProgress => maxPrecomputeBudget > 0 ? (float)precomputedVoxels.Count / maxPrecomputeBudget : 0f;

    // === Internal State ===
    private float voxelSize;
    private int mySlotIndex = -1;

    private byte[] densityBuffer;
    private byte[] nonBorderBuffer;
    private bool[,,] visited;

    // 预计算结果：按优先级排序的所有voxel
    private List<SmokeNode> precomputedVoxels = new List<SmokeNode>();
    // 每个voxel的基础密度（预计算时确定）
    private float[] precomputedDensities;
    
    private MinHeap<SmokeNode> priorityQueue;
    private float maxShapeCostReached = 0f;
    private int minY, maxY;

    private float phaseTimer = 0f;
    private float globalAlpha = 1f;
    
    // Burst结束时的目标数量
    private int burstTargetCount;
    // Spread结束时的目标数量
    private int spreadTargetCount;

    private int _gridRes => SmokeVolumeManager.VOXEL_RES;
    private float _gridWorldSize => SmokeVolumeManager.GRID_WORLD_SIZE;

    struct SmokeNode : IComparable<SmokeNode>
    {
        public Vector3Int pos;
        public float priority;
        public float shapeCost;
        public bool isWall;

        public int CompareTo(SmokeNode other) => priority.CompareTo(other.priority);
    }

    void Start()
    {
        InitializeSimulation();
    }

    void InitializeSimulation()
    {
        if (volumeManager == null)
        {
            Debug.LogError("VolumeManager is not assigned!");
            return;
        }

        mySlotIndex = volumeManager.AllocateSmokeSlot();
        if (mySlotIndex == -1)
        {
            Debug.LogError("Failed to allocate smoke slot!");
            return;
        }

        if (shadowProxy != null)
            shadowProxy.SetVolumeIndex(mySlotIndex);

        volumeManager.WriteSmokeMetadata(
            mySlotIndex, transform.position, Vector3.one * _gridWorldSize, TintColor, 1.0f
        );

        voxelSize = _gridWorldSize / _gridRes;

        int totalVoxels = _gridRes * _gridRes * _gridRes;
        densityBuffer = new byte[totalVoxels];
        nonBorderBuffer = new byte[totalVoxels];
        visited = new bool[_gridRes, _gridRes, _gridRes];

        priorityQueue = new MinHeap<SmokeNode>(4096);
        precomputedVoxels = new List<SmokeNode>(maxPrecomputeBudget);

        // 自动开始
        StartSimulation();
    }

    /// <summary>
    /// 开始烟雾模拟
    /// </summary>
    public void StartSimulation()
    {
        if (mySlotIndex == -1) return;

        ResetSimulationState();
        TransitionToPhase(SmokePhase.Precomputing);
    }

    void ResetSimulationState()
    {
        // 清空缓冲区
        Array.Clear(densityBuffer, 0, densityBuffer.Length);
        Array.Clear(nonBorderBuffer, 0, nonBorderBuffer.Length);
        Array.Clear(visited, 0, visited.Length);

        precomputedVoxels.Clear();
        //priorityQueue.Clear();

        // 初始化起始点
        int center = _gridRes / 2;
        Vector3Int startPos = new Vector3Int(center, center, center);
        float startShapeCost = CalculateShapeCost(startPos);
        float startTotalCost = CalculateTotalCost(startPos, startShapeCost);

        priorityQueue.Push(new SmokeNode
        {
            pos = startPos,
            priority = startTotalCost,
            shapeCost = startShapeCost,
            isWall = false
        });
        visited[center, center, center] = true;

        maxShapeCostReached = 0f;
        minY = center;
        maxY = center;
        globalAlpha = 1f;
        VisibleCount = 0;
        
        // 计算各阶段目标数量
        burstTargetCount = Mathf.RoundToInt(maxPrecomputeBudget * burstTargetRatio);
        spreadTargetCount = Mathf.RoundToInt(maxPrecomputeBudget * spreadTargetRatio);
    }

    void TransitionToPhase(SmokePhase newPhase)
    {
        CurrentPhase = newPhase;
        phaseTimer = 0f;
        PhaseProgress = 0f;

        switch (newPhase)
        {
            case SmokePhase.Precomputing:
                // 开始预计算
                break;
            case SmokePhase.Burst:
                // 预计算完成，计算密度
                FinalizePrecompute();
                break;
            case SmokePhase.Spread:
                // Spread从Burst结束的位置继续
                break;
            case SmokePhase.Dissipate:
                // 开始淡出
                break;
            case SmokePhase.Idle:
                // 完全清空
                Array.Clear(densityBuffer, 0, densityBuffer.Length);
                Array.Clear(nonBorderBuffer, 0, nonBorderBuffer.Length);
                UploadDensityData();
                break;
        }
    }

    void Update()
    {
        if (CurrentPhase == SmokePhase.Idle || mySlotIndex == -1) return;

        switch (CurrentPhase)
        {
            case SmokePhase.Precomputing:
                UpdatePrecomputePhase();
                break;
            case SmokePhase.Burst:
                UpdateBurstPhase();
                break;
            case SmokePhase.Spread:
                UpdateSpreadPhase();
                break;
            case SmokePhase.Dissipate:
                UpdateDissipatePhase();
                break;
        }
    }

    #region Precompute Phase

    void UpdatePrecomputePhase()
    {
        int processed = 0;

        while (priorityQueue.Count > 0 && 
               precomputedVoxels.Count < maxPrecomputeBudget && 
               processed < precomputeVoxelsPerFrame)
        {
            SmokeNode current = priorityQueue.Pop();
            precomputedVoxels.Add(current);
            processed++;

            // 更新垂直边界
            if (current.pos.y < minY) minY = current.pos.y;
            if (current.pos.y > maxY) maxY = current.pos.y;

            if (current.isWall) continue;
            if (current.shapeCost > maxShapeCostReached) maxShapeCostReached = current.shapeCost;

            // 探索邻居
            for (int i = 0; i < AllDirs.Length; i++)
            {
                Vector3Int neighbor = current.pos + AllDirs[i];
                if (!IsIndexValid(neighbor) || visited[neighbor.x, neighbor.y, neighbor.z]) continue;

                bool isTerminalNode = CheckCollision(neighbor) || !CheckConnectivity(current.pos, neighbor);
                float neighborShapeCost = CalculateShapeCost(neighbor);
                float neighborTotalCost = CalculateTotalCost(neighbor, neighborShapeCost);

                visited[neighbor.x, neighbor.y, neighbor.z] = true;
                priorityQueue.Push(new SmokeNode
                {
                    pos = neighbor,
                    priority = neighborTotalCost,
                    shapeCost = neighborShapeCost,
                    isWall = isTerminalNode
                });
            }
        }

        // 检查预计算是否完成
        bool precomputeDone = precomputedVoxels.Count >= maxPrecomputeBudget || priorityQueue.Count == 0;
        
        if (precomputeDone)
        {
            // 更新实际的目标数量（可能预计算没填满）
            int actualCount = precomputedVoxels.Count;
            burstTargetCount = Mathf.Min(burstTargetCount, actualCount);
            spreadTargetCount = Mathf.Min(spreadTargetCount, actualCount);
            
            TransitionToPhase(SmokePhase.Burst);
        }
    }

    /// <summary>
    /// 预计算完成后，计算每个voxel的基础密度
    /// </summary>
    void FinalizePrecompute()
    {
        int count = precomputedVoxels.Count;
        precomputedDensities = new float[count];
        
        float range = Mathf.Max(maxShapeCostReached, 0.01f);
        float heightSpan = Mathf.Max(maxY - this.transform.position.y, 1.0f);

        for (int i = 0; i < count; i++)
        {
            var node = precomputedVoxels[i];
            
            // 基于距离的密度
            float t = Mathf.Clamp01(node.shapeCost / range);
            float baseDensity = densityFalloff.Evaluate(t);

            // 垂直方向衰减
            float distToTop = maxY - node.pos.y;
            float verticalMask = 1.0f;
            
            verticalMask= Mathf.SmoothStep(0f, 1f, distToTop / (heightSpan * 0.25f + 0.01f));
            
            //verticalMask= Mathf.SmoothStep(0f, 1f, distToTop / (heightSpan * 0.25f + 0.01f));
            precomputedDensities[i] = baseDensity * verticalMask;
        }
    }

    #endregion

    #region Display Phases

    void UpdateBurstPhase()
    {
        // 更新时间进度
        phaseTimer += Time.deltaTime;
        PhaseProgress = Mathf.Clamp01(phaseTimer / burstDuration);

        // 通过曲线计算当前应该显示多少个voxel
        // Burst阶段: 从0到burstTargetCount
        float curveValue = burstProgressCurve.Evaluate(PhaseProgress);
        int targetVisible = Mathf.RoundToInt(curveValue * burstTargetCount);

        // 更新显示
        UpdateVisibleVoxels(targetVisible, globalAlpha);

        // 检查阶段结束
        if (PhaseProgress >= 1f)
        {
            TransitionToPhase(SmokePhase.Spread);
        }
    }

    void UpdateSpreadPhase()
    {
        phaseTimer += Time.deltaTime;
        PhaseProgress = Mathf.Clamp01(phaseTimer / spreadDuration);

        // Spread阶段: 从burstTargetCount到spreadTargetCount
        float curveValue = spreadProgressCurve.Evaluate(PhaseProgress);
        int targetVisible = Mathf.RoundToInt(
            Mathf.Lerp(burstTargetCount, spreadTargetCount, curveValue)
        );

        UpdateVisibleVoxels(targetVisible, globalAlpha);

        if (PhaseProgress >= 1f)
        {
            TransitionToPhase(SmokePhase.Dissipate);
        }
    }

    void UpdateDissipatePhase()
    {
        phaseTimer += Time.deltaTime;
        PhaseProgress = Mathf.Clamp01(phaseTimer / dissipateDuration);

        // Dissipate阶段: 数量不变，只是alpha变化
        globalAlpha = dissipateAlphaCurve.Evaluate(PhaseProgress);

        UpdateVisibleVoxels(VisibleCount, globalAlpha);

        if (PhaseProgress >= 1f)
        {
            TransitionToPhase(SmokePhase.Idle);
        }
    }

    private int lastVisibleCount = -0;
    private float lastAlpha = -0;
    /// <summary>
    /// 更新可见的voxel数量和透明度
    /// </summary>
    void UpdateVisibleVoxels(int targetCount, float alpha)
    {
        bool needRepaint = !Mathf.Approximately(alpha, lastAlpha) || !Mathf.Approximately(alpha, 1.0f);
        int drawStartIndex = needRepaint ? 0 : lastVisibleCount;

        if (lastVisibleCount > targetCount || lastAlpha > alpha)
        {
            Array.Clear(densityBuffer, 0, densityBuffer.Length);
            Array.Clear(nonBorderBuffer, 0, nonBorderBuffer.Length);
        }

        targetCount = Mathf.Clamp(targetCount, 0, precomputedVoxels.Count);
        VisibleCount = targetCount;

        // 清空缓冲区
        //Array.Clear(densityBuffer, 0, densityBuffer.Length);
        //Array.Clear(nonBorderBuffer, 0, nonBorderBuffer.Length);

        // 只渲染前targetCount个voxel
        for (int i = drawStartIndex; i < targetCount; i++)
        {
            var node = precomputedVoxels[i];
            float finalDensity = precomputedDensities[i] * alpha;

            int idx = GetFlatIndex(node.pos);
            byte densityByte = (byte)(finalDensity * 255);
            densityBuffer[idx] = densityByte;

            if (!node.isWall)
            {
                nonBorderBuffer[idx] = densityByte;
            }
        }
        
        lastVisibleCount = VisibleCount;
        lastAlpha = alpha;
        UploadDensityData();
    }

    void UploadDensityData()
    {
        if (mySlotIndex != -1 && SmokeVolumeManager.Instance != null)
        {
            SmokeVolumeManager.Instance.WriteDensityData(mySlotIndex, densityBuffer, nonBorderBuffer);
        }
    }

    #endregion

    #region Helper Methods

    float CalculateShapeCost(Vector3Int gridPos)
    {
        float halfRes = _gridRes / 2f;
        float ox = (gridPos.x - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oy = (gridPos.y - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oz = (gridPos.z - halfRes) * voxelSize + (voxelSize * 0.5f);
        float nx = Mathf.Abs(ox) / (preferredSize.x * 0.5f);
        float ny = Mathf.Abs(oy) / (preferredSize.y * 0.5f);
        float nz = Mathf.Abs(oz) / (preferredSize.z * 0.5f);
        float distPow = Mathf.Pow(nx, roundness) + Mathf.Pow(ny, roundness) + Mathf.Pow(nz, roundness);
        return Mathf.Pow(distPow, 1.0f / roundness);
    }

    float CalculateTotalCost(Vector3Int gridPos, float shapeCost)
    {
        float normalizedY = (gridPos.y - (_gridRes / 2f)) / (_gridRes / 2f);
        float gravityPenalty = normalizedY * gravityBias;
        return shapeCost + gravityPenalty;
    }

    bool IsIndexValid(Vector3Int p) =>
        p.x >= 0 && p.x < _gridRes &&
        p.y >= 0 && p.y < _gridRes &&
        p.z >= 0 && p.z < _gridRes;

    int GetFlatIndex(Vector3Int p) =>
        p.x + (p.y * _gridRes) + (p.z * _gridRes * _gridRes);

    Vector3 GridToWorld(Vector3Int p)
    {
        float halfRes = _gridRes / 2f;
        float ox = (p.x - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oy = (p.y - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oz = (p.z - halfRes) * voxelSize + (voxelSize * 0.5f);
        return transform.position + new Vector3(ox, oy, oz);
    }

    bool CheckConnectivity(Vector3Int from, Vector3Int to)
    {
        Vector3 start = GridToWorld(from);
        Vector3 end = GridToWorld(to);
        Vector3 dir = end - start;
        Vector3 halfExtents = Vector3.one * (voxelSize * 0.5f) * traceShrink;
        return !Physics.BoxCast(start, halfExtents, dir.normalized, out _, Quaternion.identity, dir.magnitude, obstacleMask);
    }

    bool CheckCollision(Vector3Int p)
    {
        Vector3 center = GridToWorld(p);
        Vector3 halfExtents = Vector3.one * (voxelSize * 0.5f) * collisionShrink;
        return Physics.CheckBox(center, halfExtents, Quaternion.identity, obstacleMask);
    }

    #endregion

    #region Public API

    /// <summary>
    /// 重新播放
    /// </summary>
    public void Replay()
    {
        StartSimulation();
    }

    /// <summary>
    /// 强制跳转到指定阶段
    /// </summary>
    public void ForceTransitionTo(SmokePhase phase)
    {
        // 如果还在预计算，不允许跳转到显示阶段
        if (CurrentPhase == SmokePhase.Precomputing && phase != SmokePhase.Idle)
        {
            Debug.LogWarning("Cannot transition while precomputing. Wait for precompute to finish.");
            return;
        }
        TransitionToPhase(phase);
    }

    /// <summary>
    /// 立即完成预计算（阻塞式，用于需要立即显示的情况）
    /// </summary>
    public void ForceCompletePrecompute()
    {
        if (CurrentPhase != SmokePhase.Precomputing) return;

        while (priorityQueue.Count > 0 && precomputedVoxels.Count < maxPrecomputeBudget)
        {
            SmokeNode current = priorityQueue.Pop();
            precomputedVoxels.Add(current);

            if (current.pos.y < minY) minY = current.pos.y;
            if (current.pos.y > maxY) maxY = current.pos.y;

            if (current.isWall) continue;
            if (current.shapeCost > maxShapeCostReached) maxShapeCostReached = current.shapeCost;

            for (int i = 0; i < AllDirs.Length; i++)
            {
                Vector3Int neighbor = current.pos + AllDirs[i];
                if (!IsIndexValid(neighbor) || visited[neighbor.x, neighbor.y, neighbor.z]) continue;

                bool isTerminalNode = CheckCollision(neighbor) || !CheckConnectivity(current.pos, neighbor);
                float neighborShapeCost = CalculateShapeCost(neighbor);
                float neighborTotalCost = CalculateTotalCost(neighbor, neighborShapeCost);

                visited[neighbor.x, neighbor.y, neighbor.z] = true;
                priorityQueue.Push(new SmokeNode
                {
                    pos = neighbor,
                    priority = neighborTotalCost,
                    shapeCost = neighborShapeCost,
                    isWall = isTerminalNode
                });
            }
        }

        int actualCount = precomputedVoxels.Count;
        burstTargetCount = Mathf.Min(burstTargetCount, actualCount);
        spreadTargetCount = Mathf.Min(spreadTargetCount, actualCount);

        TransitionToPhase(SmokePhase.Burst);
    }

    #endregion

    #region Lifecycle

    void OnDisable()
    {
        CurrentPhase = SmokePhase.Idle;
        if (mySlotIndex != -1 && volumeManager != null)
            volumeManager.ReleaseSmokeSlot(mySlotIndex);
    }

    #endregion

    #region Debug Visualization

    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.cyan;
        Gizmos.DrawWireCube(transform.position, preferredSize);

        Gizmos.color = Color.yellow;
        float gridSize = Application.isPlaying ? _gridWorldSize : SmokeVolumeManager.GRID_WORLD_SIZE;
        Gizmos.DrawWireCube(transform.position, Vector3.one * gridSize);

        if (Application.isPlaying && precomputedVoxels.Count > 0 && VisibleCount > 0)
        {
            float halfRes = _gridRes / 2f;
            int step = Mathf.Max(1, VisibleCount / 300);
            
            for (int i = 0; i < VisibleCount; i += step)
            {
                var node = precomputedVoxels[i];
                float density = precomputedDensities[i] * globalAlpha;
                
                if (density > 0.04f)
                {
                    Gizmos.color = new Color(0, 1, 0, density * 0.5f);
                    float ox = (node.pos.x - halfRes) * voxelSize + (voxelSize * 0.5f);
                    float oy = (node.pos.y - halfRes) * voxelSize + (voxelSize * 0.5f);
                    float oz = (node.pos.z - halfRes) * voxelSize + (voxelSize * 0.5f);
                    Gizmos.DrawCube(transform.position + new Vector3(ox, oy, oz), Vector3.one * voxelSize * 0.8f);
                }
            }
        }
    }

    #endregion
}
