using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VolumetricSmokeSimulation : MonoBehaviour
{
    static Vector3Int[] allDirs = {
        new Vector3Int(1,0,0), new Vector3Int(-1,0,0),
        new Vector3Int(0,0,1), new Vector3Int(0,0,-1),
        new Vector3Int(0,1,0), new Vector3Int(0,-1,0) 
    };

    [SerializeField] Color TintColor = Color.white;
    
    [Header("Target Shape")]
    public Vector3 preferredSize = new Vector3(0.7f, 1.0f, 0.6f); 
    public float roundness = 4.0f;
    
    [Header("Budget & Grid")]
    public int voxelBudget = 10000; 

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
    
    [Header("Dynamics (Constrained)")]
    public bool enableDynamics = true;
    
    [Range(0.01f, 0.5f)] 
    public float flowSpeed = 0.1f;
    
    [Range(0.0f, 50.0f)]
    [Tooltip("最大扰动幅度：25 约等于 0.1 的密度 (byte范围 0-255)")]
    public float maxDeviation = 25.0f; 
    
    public float updateInterval = 0.05f;
    
    [SerializeField] SmokeVolumeShadowProxy shadowProxy;
    
    private float voxelSize;
    private int mySlotIndex = -1;
    
    private byte[] densityBuffer;   // 当前用于渲染的数据
    private byte[] nonBorderBuffer; // 用于渲染的数据，但是不包含碰撞
    private byte[] initialBuffer;   // 初始生成的静态数据（锚点）
    private byte[] backBuffer;      // 双缓冲计算用
    
    private bool[,,] visited;
    private List<SmokeNode> filledVoxels = new List<SmokeNode>();
    private float startWorldY;
    
    [SerializeField] SmokeVolumeManager volumeManager;

    private int _gridRes => SmokeVolumeManager.VOXEL_RES;
    private float _gridWorldSize => SmokeVolumeManager.GRID_WORLD_SIZE;
    
    struct SmokeNode : IComparable<SmokeNode>
    {
        public Vector3Int pos;
        public float priority;
        public float shapeCost;
        public bool isWall;

        public int CompareTo(SmokeNode other)
        {
            return priority.CompareTo(other.priority);
        }
    }

    IEnumerator Start()
    {
        if (volumeManager == null) yield break;
        mySlotIndex = volumeManager.AllocateSmokeSlot();
        if (mySlotIndex == -1) yield break;
        
        shadowProxy.SetVolumeIndex(mySlotIndex);

        volumeManager.WriteSmokeMetadata(
            mySlotIndex, transform.position, Vector3.one * _gridWorldSize, TintColor, 1.0f
        );
        
        voxelSize = _gridWorldSize / _gridRes;
        
        int totalVoxels = _gridRes * _gridRes * _gridRes;
        densityBuffer = new byte[totalVoxels];
        nonBorderBuffer = new byte[totalVoxels];
        initialBuffer = new byte[totalVoxels]; // 初始化锚点Buffer
        backBuffer = new byte[totalVoxels];
        
        visited = new bool[_gridRes, _gridRes, _gridRes];

        startWorldY = transform.position.y;
        
        yield return StartCoroutine(SimulatePriorityFill());
        
        Array.Copy(densityBuffer, initialBuffer, densityBuffer.Length);
        
        if (enableDynamics)
        {
            float timeAccumulator = 0f;
            while (true)
            {
                timeAccumulator += Time.deltaTime;
                // 执行受限扰动模拟
                //StepConstrainedSimulation(timeAccumulator);
                yield return new WaitForSeconds(updateInterval);
            }
        }
    }

    // void Update()
    // {
    //     if (volumeManager == null)
    //     {
    //         Debug.Log("FAiled to find ");
    //     }
    //
    //     if (mySlotIndex != -1)
    //     {
    //         volumeManager.WriteSmokeMetadata(
    //             mySlotIndex, transform.position, Vector3.one * _gridWorldSize, TintColor, 1.0f
    //         );
    //     }
    // }

    void OnDisable()
    {
        StopAllCoroutines();
        if (mySlotIndex != -1 && volumeManager != null)
            volumeManager.ReleaseSmokeSlot(mySlotIndex);
    }
    
    IEnumerator SimulatePriorityFill()
    {
        MinHeap<SmokeNode> pQueue = new MinHeap<SmokeNode>(2048);
        int center = _gridRes / 2;
        Vector3Int startPos = new Vector3Int(center, center, center);
        float startShapeCost = CalculateShapeCost(startPos);
        float startTotalCost = CalculateTotalCost(startPos, startShapeCost);

        pQueue.Push(new SmokeNode { pos = startPos, priority = startTotalCost, shapeCost = startShapeCost });
        visited[center, center, center] = true;
        filledVoxels.Clear();
        
        int processedPerFrame = 0;
        float maxShapeCostReached = 0f;

        // [新增] 追踪生成的垂直范围
        int minY = center;
        int maxY = center;

        while (pQueue.Count > 0 && filledVoxels.Count < voxelBudget)
        {
            SmokeNode current = pQueue.Pop();
            filledVoxels.Add(current);
            
            // [新增] 更新垂直边界
            if (current.pos.y < minY) minY = current.pos.y;
            if (current.pos.y > maxY) maxY = current.pos.y;
            
            if (current.isWall) continue;
            if (current.shapeCost > maxShapeCostReached) maxShapeCostReached = current.shapeCost;
            
            for (int i = 0; i < allDirs.Length; i++)
            {
                Vector3Int neighbor = current.pos + allDirs[i];
                if (!IsIndexValid(neighbor) || visited[neighbor.x, neighbor.y, neighbor.z]) continue;
                
                bool isTerminalNode = CheckCollision(neighbor) || !CheckConnectivity(current.pos, neighbor);
                float neighborShapeCost = CalculateShapeCost(neighbor);
                float neighborTotalCost = CalculateTotalCost(neighbor, neighborShapeCost);

                visited[neighbor.x, neighbor.y, neighbor.z] = true;
                pQueue.Push(new SmokeNode { pos = neighbor, priority = neighborTotalCost, shapeCost = neighborShapeCost, isWall = isTerminalNode });
            }

            processedPerFrame++;
            if (processedPerFrame > 1000)
            {
                processedPerFrame = 0;
                // 暂时传入 minY 和 maxY 进行预览，虽然中间过程可能不准确
                ApplyDensity(maxShapeCostReached, minY, maxY);
                yield return null;
            }
        }
        // 最终应用，传入准确的 minY 和 maxY
        ApplyDensity(maxShapeCostReached, minY, maxY);
    }

    // [修改] 增加 minY 和 maxY 参数
    void ApplyDensity(float maxCost, int minY, int maxY)
    {
        float range = Mathf.Max(maxCost, 0.01f);
        
        // 计算垂直高度差，防止除以0
        float heightSpan = Mathf.Max(maxY - minY, 1.0f);
        // 定义顶部柔和过渡的比例 (比如顶部的 20% 区域开始变淡)
        float topFadeRatio = 0.2f; 
        float fadeHeightStart = minY + heightSpan * (1.0f - topFadeRatio);

        foreach (var node in filledVoxels)
        {
            // 1. 原始的基于距离的密度 (这一步导致了平顶，因为maxCost由水平距离决定)
            float t = Mathf.Clamp01(node.shapeCost / range);
            float baseDensity = densityFalloff.Evaluate(t);

            // 2. [新增] 垂直方向的强制衰减 (Vertical Mask)
            // 计算当前点在垂直方向上的归一化位置 (0在底部, 1在顶部)
            // float normalizedY = (node.pos.y - minY) / heightSpan;
            
            // 或者更简单：距离顶部的距离
            float distToTop = maxY - node.pos.y;
            
            // 创建一个垂直遮罩：
            // 如果离顶部很近(distToTop 小)，mask 趋向于 0
            // 这里的 5.0f 是淡出的体素格数，你可以改成 heightSpan * 0.2f
            float verticalMask = Mathf.SmoothStep(0f, 1f, distToTop / (heightSpan * 0.25f + 0.01f));

            // 3. 混合密度
            float finalDensity = baseDensity * verticalMask;

            int idx = GetFlatIndex(node.pos);
            densityBuffer[idx] = (byte)(finalDensity * 255);
            if (!node.isWall)
            {
                nonBorderBuffer[idx] = (byte)(finalDensity * 255);
            }
            
            //densityBuffer[idx] = (byte)(1.0 * 255);
        }

        if (mySlotIndex != -1)
            SmokeVolumeManager.Instance.WriteDensityData(mySlotIndex, densityBuffer, nonBorderBuffer);
    }
    
    // void StepConstrainedSimulation(float time)
    // {
    //     int res = _gridRes;
    //     int resSqr = res * res;
    //     
    //     // 遍历所有格子 (注意：边界保留1格不处理，防止索引越界)
    //     for (int z = 1; z < res - 1; z++)
    //     {
    //         for (int y = 1; y < res - 1; y++)
    //         {
    //             for (int x = 1; x < res - 1; x++)
    //             {
    //                 int idx = x + y * res + z * resSqr;
    //                 
    //                 float baseVal = initialBuffer[idx];    // 初始锚点（理想形状）
    //                 float currentVal = densityBuffer[idx]; // 当前这一帧的数值
    //                 
    //                 // 1. 先计算邻居情况（看看有没有烟雾流过来）
    //                 float neighborSum = 0;
    //                 neighborSum += densityBuffer[idx + 1];       
    //                 neighborSum += densityBuffer[idx - 1];       
    //                 neighborSum += densityBuffer[idx + res];     
    //                 neighborSum += densityBuffer[idx - res];     
    //                 neighborSum += densityBuffer[idx + resSqr];  
    //                 neighborSum += densityBuffer[idx - resSqr];  
    //                 float avg = neighborSum / 6.0f;
    //                 
    //                 // 如果：
    //                 // 1. 这里本来就没烟 (baseVal 低)
    //                 // 2. 现在也没烟 (currentVal 低)
    //                 // 3. 邻居也没烟流过来 (avg 低)
    //                 // 则跳过
    //                 if (baseVal < 1.0f && currentVal < 1.0f && avg < 1.0f) 
    //                 {
    //                     backBuffer[idx] = 0;
    //                     continue;
    //                 }
    //
    //                 // 2. 噪声扰动 (保持不变，用于产生动态纹理)
    //                 float noise = Mathf.Sin(x * 0.3f + time * flowSpeed) * Mathf.Cos(z * 0.3f + time * flowSpeed * 0.8f) * Mathf.Sin(y * 0.5f + time * flowSpeed * 1.2f);
    //                 
    //                 // 3. 混合与扩散
    //                 // 让当前值慢慢向邻居平均值靠拢 (Lerp)，同时叠加噪声
    //                 float dynamicVal = Mathf.Lerp(currentVal, avg, 0.2f);
    //
    //                 // 4. [锚定约束] 
    //                 // 即使是空地 (baseVal=0)，这里也允许它增长到 maxDeviation (例如 25)。
    //                 // 这就允许了烟雾向外“晕染”出一层薄薄的动态边缘。
    //                 float minLimit = Mathf.Max(0, baseVal - maxDeviation);
    //                 float maxLimit = Mathf.Min(255, baseVal + maxDeviation);
    //                 
    //                 dynamicVal = Mathf.Clamp(dynamicVal, minLimit, maxLimit);
    //
    //                 // 5. [低值剔除]
    //                 // 扩散到一定程度太淡了就直接抹掉，防止无限计算极小值
    //                 if (dynamicVal < 2.0f) dynamicVal = 0;
    //
    //                 backBuffer[idx] = (byte)dynamicVal;
    //             }
    //         }
    //     }
    //     
    //     // 交换双缓冲
    //     var temp = densityBuffer;
    //     densityBuffer = backBuffer;
    //     backBuffer = temp;
    //     
    //     // 上传数据
    //     if (mySlotIndex != -1)
    //         SmokeVolumeManager.Instance.WriteDensityData(mySlotIndex, densityBuffer);
    // }

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
    
    
    bool IsIndexValid(Vector3Int p) => p.x >= 0 && p.x < _gridRes && p.y >= 0 && p.y < _gridRes && p.z >= 0 && p.z < _gridRes;
    int GetFlatIndex(Vector3Int p) => p.x + (p.y * _gridRes) + (p.z * _gridRes * _gridRes);

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
    
    void OnDrawGizmosSelected()
    {
        if (!false) return;
        Gizmos.color = Color.cyan;
        Gizmos.DrawWireCube(transform.position, preferredSize);
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireCube(transform.position, Vector3.one * _gridWorldSize);
        Gizmos.color = Color.red;
        float limitY = (Application.isPlaying ? startWorldY : transform.position.y);
        Gizmos.DrawWireCube(new Vector3(transform.position.x, limitY, transform.position.z), new Vector3(_gridWorldSize, 0.1f, _gridWorldSize));

        if (Application.isPlaying && densityBuffer != null)
        {
            float halfRes = _gridRes / 2f;
            for (int x=0; x<_gridRes; x+=2) for (int y=0; y<_gridRes; y+=2) for (int z=0; z<_gridRes; z+=2)
            {
                int idx = x + y*_gridRes + z*_gridRes*_gridRes;
                if (densityBuffer[idx] > 10)
                {
                    Gizmos.color = new Color(0,1,0, densityBuffer[idx]/255f);
                    float ox = (x - halfRes) * voxelSize + (voxelSize * 0.5f);
                    float oy = (y - halfRes) * voxelSize + (voxelSize * 0.5f);
                    float oz = (z - halfRes) * voxelSize + (voxelSize * 0.5f);
                    Gizmos.DrawCube(transform.position + new Vector3(ox, oy, oz), Vector3.one * voxelSize * 0.9f);
                }
            }
        }
    }
}