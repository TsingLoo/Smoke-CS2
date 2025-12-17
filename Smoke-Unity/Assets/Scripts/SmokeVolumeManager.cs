using System;
using UnityEngine;
using System.Runtime.InteropServices;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class SmokeVolumeManager : MonoBehaviour
{
    public static SmokeVolumeManager Instance { get; private set; }
    
    public const float GRID_WORLD_SIZE = 14.0f; 
    public const int MAX_SMOKE_COUNT = 16;
    public const int VOXEL_RES = 32;
    public const int ATLAS_DEPTH = VOXEL_RES * MAX_SMOKE_COUNT; 
    
    [StructLayout(LayoutKind.Sequential)]
    struct SmokeVolumeData
    {
        public Vector3 position;      
        public int volumeIndex;
        public Vector3 aabbMin;       
        public float padding1;
        public Vector3 aabbMax;       
        public float padding2;
        public Vector3 tint;          
        public float intensity;       
    }
    
    struct SceneVolumeUniforms
    {
        public Matrix16x4 volumeMinBounds;
        public Matrix16x4 volumeMaxBounds;
        public Matrix16x4 volumeCenters;
        /// <summary>
        /// .x: Height, .y: AnimBlend, .z: SlotIndex 
        /// </summary>
        public Matrix16x4 volumeAnimState;
        /// <summary>
        /// .rgb: Tint Color
        /// </summary>
        public Matrix16x4 volumeTintColor; 
        /// <summary>
        /// .x: Density, .z: Saturation/Age, .w: HeightFade
        /// </summary>
        public Matrix16x4 volumeFadeParams;
        public Vector4  sceneAABBMin;
        public Vector4  sceneAABBMax;
        public Matrix16x4 bulletTracerStarts;
        public Matrix16x4 bulletTracerEnds;
        public Matrix16x4 tracerInfluenceParams;
        public Array5x4 explosionPositions;
        public Array2x4 volumeTracerMasks;
        public uint activeTracerCount;
        public float animationTime;
        public uint enableExplosions;
        public float padding;
    }

    // ===== Inspector 配置 =====
    [Header("References")]
    public Material smokeMaskMaterial; 
    
    [Header("Interpolation Settings")]
    [Tooltip("GPU插值的目标时间（秒）。只有当上一帧插值完全结束后，才会上传新数据。")]
    [Range(0.05f, 0.5f)]
    public float interpolationDuration = 0.1f;
    
    // [Removed] minUploadInterval 已移除，由 interpolationDuration 全权控制节奏

    [Header("Debug")]
    public bool showGizmos = true;
    public Color gizmoColor = new Color(0, 1, 0, 0.3f);
    
    [SerializeField, ReadOnly] private float currentInterpolationT;
    
    // ===== 内部资源 =====
    private Texture3D smokeAtlas;          
    private byte[] atlasDataCPU;           // 对应 Texture3D 的实际数据 (RGBA)
    private ComputeBuffer metadataBuffer;  
    private SmokeVolumeData[] metadataArray;

    //we actually upload buffer to GPu
    private ComputeBuffer sceneUniformBuffer;
    private SceneVolumeUniforms cpuData;
    private SceneVolumeUniforms[] dataArray;
    
    private class SlotInfo { public bool active; public Vector3 pos; public Vector3 size; }
    private SlotInfo[] slots = new SlotInfo[MAX_SMOKE_COUNT];

    // ===== 新增：Pending 缓冲区 (用于解决 R/G 通道数据一致的问题) =====
    // 存储最新的 Sim 数据，等待上传时机
    private byte[][] pendingDensityData;
    private byte[][] pendingSmokeData;

    // ===== 时间驱动插值状态 =====
    private float lastUploadTime = 0f;
    private bool isTextureDirty = false;
    private bool isMetadataDirty = false;
    
    // Shader属性ID缓存
    private static readonly int _InterpolationT = Shader.PropertyToID("_SmokeInterpolationT");
    private static readonly int _SmokeVolumes = Shader.PropertyToID("_SmokeVolumes");
    private static readonly int _SmokeCount = Shader.PropertyToID("_SmokeCount");
    private static readonly int _SmokeTex3D = Shader.PropertyToID("_SmokeTex3D");
    private static readonly int _VolumeSize = Shader.PropertyToID("_VolumeSize");

    private static readonly int _SceneVolumeUniforms = Shader.PropertyToID(nameof(_SceneVolumeUniforms)); 
    

    void Awake()
    {
        Instance = this;
        InitializeSystem();
    }

    private void Start()
    {
        sceneUniformBuffer = new ComputeBuffer(1, 2464, ComputeBufferType.Constant);

        dataArray = new SceneVolumeUniforms[1];
        cpuData = dataArray[0];
        cpuData.sceneAABBMin = new Vector4(-100, -100, -100, 1);
        cpuData.sceneAABBMax = new Vector4(100, 100, 100, 1);
        
        
        Shader.SetGlobalFloat(_VolumeSize, GRID_WORLD_SIZE);
        lastUploadTime = Time.time;
    }

    void OnDestroy()
    {
        if (metadataBuffer != null) metadataBuffer.Release();
        if (smokeAtlas != null) Destroy(smokeAtlas);
        if (sceneUniformBuffer != null) sceneUniformBuffer.Release();
    }

    void InitializeSystem()
    {
        for(int i=0; i<MAX_SMOKE_COUNT; i++) slots[i] = new SlotInfo();

        // R=HistoryAll, G=TargetAll, B=HistorySmoke, A=TargetSmoke
        smokeAtlas = new Texture3D(VOXEL_RES, VOXEL_RES, ATLAS_DEPTH, TextureFormat.RGBA32, false);
        smokeAtlas.wrapMode = TextureWrapMode.Clamp;
        smokeAtlas.filterMode = FilterMode.Trilinear;
        smokeAtlas.name = "DynamicSmokeAtlas";

        atlasDataCPU = new byte[VOXEL_RES * VOXEL_RES * ATLAS_DEPTH * 4];
        smokeAtlas.SetPixelData(atlasDataCPU, 0);
        smokeAtlas.Apply();

        int stride = Marshal.SizeOf(typeof(SmokeVolumeData)); 
        metadataBuffer = new ComputeBuffer(MAX_SMOKE_COUNT, stride);
        metadataArray = new SmokeVolumeData[MAX_SMOKE_COUNT];

        // 初始化 Pending 缓冲区
        int voxelsPerSlot = VOXEL_RES * VOXEL_RES * VOXEL_RES;
        pendingDensityData = new byte[MAX_SMOKE_COUNT][];
        pendingSmokeData = new byte[MAX_SMOKE_COUNT][];
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            pendingDensityData[i] = new byte[voxelsPerSlot];
            pendingSmokeData[i] = new byte[voxelsPerSlot];
        }
    }

    public int AllocateSmokeSlot()
    {
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            if (!slots[i].active)
            {
                slots[i].active = true;
                slots[i].pos = Vector3.zero;
                slots[i].size = Vector3.one;

                ClearSlotData(i); 
                return i;
            }
        }
        Debug.LogWarning("Smoke Manager: Max smoke limit reached!");
        return -1;
    }

    public void ReleaseSmokeSlot(int index)
    {
        if (index >= 0 && index < MAX_SMOKE_COUNT)
        {
            slots[index].active = false;
            ClearSlotData(index);
        }
    }
    
    /// <summary>
    /// 接收来自 Simulation 的新数据。
    /// 注意：这里只更新 Pending 缓存，不触碰 Texture，确保 R/G 差异。
    /// </summary>
    public void WriteDensityData(int slotIndex, byte[] allData, byte[] smokeData)
    {
        if (slotIndex < 0 || slotIndex >= MAX_SMOKE_COUNT) return;

        // 仅拷贝到 Pending 缓冲区
        Array.Copy(allData, pendingDensityData[slotIndex], allData.Length);
        Array.Copy(smokeData, pendingSmokeData[slotIndex], smokeData.Length);

        isTextureDirty = true;
    }

    public void WriteSmokeMetadata(int slotIndex, Vector3 pos, Vector3 size, Color tint, float intensity)
    {
        if (slotIndex < 0 || slotIndex >= MAX_SMOKE_COUNT) return;
        
        // slots[slotIndex].pos = pos;
        // slots[slotIndex].size = size;

        cpuData.volumeMinBounds[slotIndex] = pos - size * 0.5f;
        cpuData.volumeMaxBounds[slotIndex] = pos + size * 0.5f;
        cpuData.volumeCenters[slotIndex] = pos;
        cpuData.volumeAnimState[slotIndex] = new Vector4(2.0f, 0.5f, slotIndex, 0.0f); 
        cpuData.volumeTintColor[slotIndex] = tint;
        cpuData.volumeFadeParams[slotIndex] = new Vector4(1.0f, 0.5f, 0.5f, 0.0f);
        
        // metadataArray[slotIndex] = new SmokeVolumeData
        // {
        //     position = pos,
        //     volumeIndex = slotIndex,
        //     aabbMin = pos - size * 0.5f,
        //     padding1 = 0,
        //     aabbMax = pos + size * 0.5f,
        //     padding2 = 0,
        //     tint = new Vector3(tint.r, tint.g, tint.b),
        //     intensity = intensity
        // };

        isMetadataDirty = true;
    }

    public void WriteBulletMetaData()
    {
    }

    private void ClearSlotData(int slotIndex)
    {
        int voxelsPerSlot = VOXEL_RES * VOXEL_RES * VOXEL_RES;
        
        // 1. 清空 Pending
        Array.Clear(pendingDensityData[slotIndex], 0, voxelsPerSlot);
        Array.Clear(pendingSmokeData[slotIndex], 0, voxelsPerSlot);

        // 2. 清空 Texture CPU 缓存
        int oneVolBytes = voxelsPerSlot * 4; // RGBA
        int offset = slotIndex * oneVolBytes;
        Array.Clear(atlasDataCPU, offset, oneVolBytes);
        
        isTextureDirty = true;
    }
    
    void Update()
    {
        UpdateInterpolationFactor();
        
        if (isMetadataDirty)
        {
            UploadMetadata();
            isMetadataDirty = false;
        }
        dataArray[0] = cpuData;
        sceneUniformBuffer.SetData(dataArray);
        
        Shader.SetGlobalConstantBuffer(nameof(_SceneVolumeUniforms), sceneUniformBuffer, 0, 2464);
    }
    


    void LateUpdate()
    {
        // 检查是否需要上传纹理
        // 核心修改：只有当插值时间 >= 设定时间 (即上一段动画播完了)，才允许上传
        float timeSinceUpload = Time.time - lastUploadTime;
        bool animationFinished = timeSinceUpload >= interpolationDuration;
        
        if (isTextureDirty && animationFinished)
        {
            UploadTextureData();
        }
    }

    void UpdateInterpolationFactor()
    {
        float timeSinceUpload = Time.time - lastUploadTime;
        
        // 计算 t (0 -> 1)
        float t = Mathf.Clamp01(timeSinceUpload / interpolationDuration);
        
        // 缓动
        //t = SmoothStep(t);
        t = t * t * t * (t * (t * 6f - 15f) + 10f);
        currentInterpolationT = t;
        Shader.SetGlobalFloat(_InterpolationT, t);
    }

    /// <summary>
    /// 上传逻辑的核心：执行关键帧交换 (Swap)
    /// </summary>
    void UploadTextureData()
    {
        int voxelsPerSlot = VOXEL_RES * VOXEL_RES * VOXEL_RES;

        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            if (!slots[i].active) continue;

            byte[] newAll = pendingDensityData[i];
            byte[] newSmoke = pendingSmokeData[i];
            
            int startByteIndex = i * voxelsPerSlot * 4;

            for (int v = 0; v < voxelsPerSlot; v++)
            {
                int ptr = startByteIndex + (v * 4);

                // --- 关键逻辑：Frame Swap ---
                // 1. 读取当前的 Target (G/A)，它将成为下一帧的 History
                byte lastFrameTargetAll = atlasDataCPU[ptr + 1];
                byte lastFrameTargetSmoke = atlasDataCPU[ptr + 3];

                // 2. 写入 History (R/B) = 上一帧的 Target
                atlasDataCPU[ptr + 0] = lastFrameTargetAll;   // R
                atlasDataCPU[ptr + 2] = lastFrameTargetSmoke; // B

                // 3. 写入 Target (G/A) = Pending 中最新的 Sim 数据
                atlasDataCPU[ptr + 1] = newAll[v];   // G
                atlasDataCPU[ptr + 3] = newSmoke[v]; // A
            }
        }

        // 提交到 GPU
        smokeAtlas.SetPixelData(atlasDataCPU, 0);
        smokeAtlas.Apply();
        
        // 重置时间轴
        lastUploadTime = Time.time;
        isTextureDirty = false;
        
        // 立即重置插值因子，开始新一轮混合
        Shader.SetGlobalFloat(_InterpolationT, 0f);
        currentInterpolationT = 0f;
    }

    void UploadMetadata()
    {
        // 确保非活跃槽位数据清空
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            if (!slots[i].active)
            {
                metadataArray[i].intensity = 0;
                metadataArray[i].volumeIndex = -1;
            }
        }
        metadataBuffer.SetData(metadataArray);

        if (smokeMaskMaterial != null)
        {
            smokeMaskMaterial.SetBuffer(_SmokeVolumes, metadataBuffer);
            smokeMaskMaterial.SetInt(_SmokeCount, MAX_SMOKE_COUNT);
            smokeMaskMaterial.SetTexture(_SmokeTex3D, smokeAtlas);
        }
    
        Shader.SetGlobalBuffer(_SmokeVolumes, metadataBuffer);
        Shader.SetGlobalInt(_SmokeCount, MAX_SMOKE_COUNT);
        Shader.SetGlobalTexture(_SmokeTex3D, smokeAtlas);   
    }
    
    static float SmoothStep(float t)
    {
        return t * t * (3f - 2f * t);
    }
    
    void OnDrawGizmos()
    {
        if (!showGizmos) return;
        if (slots == null) return;
        
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            if (slots[i] == null) continue;
            
            if (slots[i].active)
            {
                Gizmos.color = gizmoColor;
                Gizmos.DrawWireCube(slots[i].pos, slots[i].size);
            }
        }
    }
}

// Editor Helper
#if UNITY_EDITOR
public class ReadOnlyAttribute : PropertyAttribute { }

[CustomPropertyDrawer(typeof(ReadOnlyAttribute))]
public class ReadOnlyDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        GUI.enabled = false;
        EditorGUI.PropertyField(position, property, label);
        GUI.enabled = true;
    }
}
#endif