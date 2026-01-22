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
    
    // 新增：X轴堆叠相关常量
    public const int STRIDE = 2;  // 每个体积之间的黑像素列数
    // 总宽度 = 32*16 + 2*(16-1) = 512 + 30 = 542
    public const int ATLAS_WIDTH = VOXEL_RES * MAX_SMOKE_COUNT + STRIDE * (MAX_SMOKE_COUNT - 1);
    public const int ATLAS_HEIGHT = VOXEL_RES;  // 32
    public const int ATLAS_DEPTH = VOXEL_RES;   // 32
    
    // 每个slot在X轴上的步进（包含stride）
    public const int SLOT_STRIDE = VOXEL_RES + STRIDE;  // 34
    
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

    [Header("Debug")]
    public bool showGizmos = true;
    public Color gizmoColor = new Color(0, 1, 0, 0.3f);
    
    [SerializeField, ReadOnly] private float currentInterpolationT;
    
    // ===== 内部资源 =====
    private Texture3D smokeAtlas;          
    private byte[] atlasDataCPU;           // 对应 Texture3D 的实际数据 (RGBA)
    private ComputeBuffer metadataBuffer;  
    private SmokeVolumeData[] metadataArray;

    // we actually upload buffer to GPU
    private ComputeBuffer sceneUniformBuffer;
    private SceneVolumeUniforms cpuData;
    private SceneVolumeUniforms[] dataArray;
    
    private class SlotInfo { public bool active; public Vector3 pos; public Vector3 size; }
    private SlotInfo[] slots = new SlotInfo[MAX_SMOKE_COUNT];

    // ===== Pending 缓冲区 =====
    private byte[][] pendingDensityData;
    private byte[][] pendingSmokeData;

    // ===== 时间驱动插值状态 =====
    private float lastUploadTime = 0f;
    private bool isTextureDirty = false;
    private bool isMetadataDirty = false;
    
    // Shader属性ID缓存
    private static readonly int _InterpolationT = Shader.PropertyToID("_SmokeInterpolationT");
    private static readonly int _SmokeVolumes = Shader.PropertyToID("_SmokeVolumes");
    private static readonly int _SmokeCount = Shader.PropertyToID(nameof(_SmokeCount));
    private static readonly int _SmokeTex3D = Shader.PropertyToID(nameof(_SmokeTex3D));
    private static readonly int _VolumeSize = Shader.PropertyToID("_VolumeSize");
    private static readonly int _SceneVolumeUniforms = Shader.PropertyToID(nameof(_SceneVolumeUniforms)); 
    
    // 新增：传递给Shader的atlas参数
    private static readonly int _AtlasWidth = Shader.PropertyToID("_SmokeAtlasWidth");
    private static readonly int _SlotStride = Shader.PropertyToID("_SmokeSlotStride");

    void Awake()
    {
        Instance = this;
        InitializeSystem();
        dataArray = new SceneVolumeUniforms[1];
        sceneUniformBuffer = new ComputeBuffer(1, 2464, ComputeBufferType.Constant);
        cpuData = new SceneVolumeUniforms();
    }

    private void Start()
    {
        cpuData.sceneAABBMin = new Vector4(float.MaxValue, float.MaxValue, float.MaxValue, 1);
        cpuData.sceneAABBMax = new Vector4(float.MinValue, float.MinValue, float.MinValue, 1);
        
        Shader.SetGlobalFloat(_VolumeSize, GRID_WORLD_SIZE);
        
        // 传递新的atlas布局参数给Shader
        Shader.SetGlobalInt(_AtlasWidth, ATLAS_WIDTH);
        Shader.SetGlobalInt(_SlotStride, SLOT_STRIDE);
        
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
        for(int i = 0; i < MAX_SMOKE_COUNT; i++) slots[i] = new SlotInfo();

        // 修改：X轴堆叠，维度为 542 x 32 x 32
        // R=HistoryAll, G=TargetAll, B=HistorySmoke, A=TargetSmoke
        smokeAtlas = new Texture3D(ATLAS_WIDTH, ATLAS_HEIGHT, ATLAS_DEPTH, TextureFormat.RGBA32, false);
        smokeAtlas.wrapMode = TextureWrapMode.Clamp;
        smokeAtlas.filterMode = FilterMode.Trilinear;
        smokeAtlas.name = "DynamicSmokeAtlas";

        // 修改：新的数据大小
        atlasDataCPU = new byte[ATLAS_WIDTH * ATLAS_HEIGHT * ATLAS_DEPTH * 4];
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

    /// <summary>
    /// 计算slot在X轴上的起始位置
    /// Slot 0: X = 0
    /// Slot 1: X = 34 (32 + 2)
    /// Slot i: X = i * 34
    /// </summary>
    private int GetSlotStartX(int slotIndex)
    {
        return slotIndex * SLOT_STRIDE;
    }

    /// <summary>
    /// 将本地体素坐标转换为atlas中的线性字节索引
    /// </summary>
    private int LocalToAtlasIndex(int slotIndex, int localX, int localY, int localZ)
    {
        int globalX = GetSlotStartX(slotIndex) + localX;
        int globalY = localY;
        int globalZ = localZ;
        
        // 3D纹理线性索引：x + y * width + z * width * height
        int voxelIndex = globalX + globalY * ATLAS_WIDTH + globalZ * ATLAS_WIDTH * ATLAS_HEIGHT;
        return voxelIndex * 4;  // RGBA, 4 bytes per voxel
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

        cpuData.volumeMinBounds[slotIndex] = pos - size * 0.5f;
        cpuData.volumeMaxBounds[slotIndex] = pos + size * 0.5f;
        cpuData.volumeCenters[slotIndex] = pos;
        cpuData.volumeAnimState[slotIndex] = new Vector4(2.0f, 0.5f, slotIndex, 0.0f); 
        cpuData.volumeTintColor[slotIndex] = tint;
        cpuData.volumeFadeParams[slotIndex] = new Vector4(1.0f, 0.5f, 0.5f, 1.0f);

        Vector3 sceneMin = new Vector3(float.MaxValue, float.MaxValue, float.MaxValue);
        Vector3 sceneMax = new Vector3(float.MinValue, float.MinValue, float.MinValue);

        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            Vector3 vMin = cpuData.volumeMinBounds[i];
            Vector3 vMax = cpuData.volumeMaxBounds[i];
            
            if (vMin != Vector3.zero || vMax != Vector3.zero) 
            {
                sceneMin = Vector3.Min(sceneMin, vMin);
                sceneMax = Vector3.Max(sceneMax, vMax);
            }
        }

        cpuData.sceneAABBMin = new Vector4(sceneMin.x, sceneMin.y, sceneMin.z, 1.0f);
        cpuData.sceneAABBMax = new Vector4(sceneMax.x, sceneMax.y, sceneMax.z, 1.0f);
        
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

        // 2. 清空 Texture CPU 缓存中对应slot的区域
        for (int z = 0; z < VOXEL_RES; z++)
        {
            for (int y = 0; y < VOXEL_RES; y++)
            {
                for (int x = 0; x < VOXEL_RES; x++)
                {
                    int byteIndex = LocalToAtlasIndex(slotIndex, x, y, z);
                    atlasDataCPU[byteIndex + 0] = 0;  // R
                    atlasDataCPU[byteIndex + 1] = 0;  // G
                    atlasDataCPU[byteIndex + 2] = 0;  // B
                    atlasDataCPU[byteIndex + 3] = 0;  // A
                }
            }
        }
        
        isTextureDirty = true;
    }
    
    void Update()
    {
        UpdateInterpolationFactor();
        
        if (isMetadataDirty)
        {
            SortAndUploadVolumes();
            isMetadataDirty = false;
        }
    }

    void LateUpdate()
    {
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
        
        float t = Mathf.Clamp01(timeSinceUpload / interpolationDuration);
        t = t * t * t * (t * (t * 6f - 15f) + 10f);
        currentInterpolationT = t;
        Shader.SetGlobalFloat(_InterpolationT, t);
    }

    /// <summary>
    /// 上传逻辑的核心：执行关键帧交换 (Swap)
    /// 修改为X轴堆叠的索引方式
    /// </summary>
    void UploadTextureData()
    {
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            if (!slots[i].active) continue;

            byte[] newAll = pendingDensityData[i];
            byte[] newSmoke = pendingSmokeData[i];

            // 遍历本地体素坐标
            for (int z = 0; z < VOXEL_RES; z++)
            {
                for (int y = 0; y < VOXEL_RES; y++)
                {
                    for (int x = 0; x < VOXEL_RES; x++)
                    {
                        // pending数据中的本地索引
                        int localVoxelIndex = x + y * VOXEL_RES + z * VOXEL_RES * VOXEL_RES;
                        
                        // atlas中的字节索引
                        int atlasPtr = LocalToAtlasIndex(i, x, y, z);

                        // --- 关键逻辑：Frame Swap ---
                        // 1. 读取当前的 Target (G/A)
                        byte lastFrameTargetAll = atlasDataCPU[atlasPtr + 1];
                        byte lastFrameTargetSmoke = atlasDataCPU[atlasPtr + 3];

                        // 2. 写入 History (R/B) = 上一帧的 Target
                        atlasDataCPU[atlasPtr + 0] = lastFrameTargetAll;   // R
                        atlasDataCPU[atlasPtr + 2] = lastFrameTargetSmoke; // B

                        // 3. 写入 Target (G/A) = Pending 中最新的 Sim 数据
                        atlasDataCPU[atlasPtr + 1] = newAll[localVoxelIndex];   // G
                        atlasDataCPU[atlasPtr + 3] = newSmoke[localVoxelIndex]; // A
                    }
                }
            }
        }

        // 提交到 GPU
        smokeAtlas.SetPixelData(atlasDataCPU, 0);
        smokeAtlas.Apply();
        
        lastUploadTime = Time.time;
        isTextureDirty = false;
        
        Shader.SetGlobalFloat(_InterpolationT, 0f);
        currentInterpolationT = 0f;
    }

    void SortAndUploadVolumes()
    {
        Shader.SetGlobalInt(_SmokeCount, MAX_SMOKE_COUNT);
        Shader.SetGlobalTexture(_SmokeTex3D, smokeAtlas);   
        
        dataArray[0] = cpuData;
        sceneUniformBuffer.SetData(dataArray);
        
        Shader.SetGlobalConstantBuffer(_SceneVolumeUniforms, sceneUniformBuffer, 0, 2464);
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
