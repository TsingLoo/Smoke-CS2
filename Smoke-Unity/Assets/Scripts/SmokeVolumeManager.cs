using System;
using UnityEngine;
using System.Collections.Generic;
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
    // 纹理总深度 = 单个分辨率 * 最大数量
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
    
    // ===== Inspector 配置 =====
    [Header("References")]
    public Material smokeMaskMaterial; 
    
    [Header("Optimization")]
    [Tooltip("每隔多少帧上传一次纹理到 GPU。设置为 5 表示每 5 帧更新一次。")]
    [Range(1, 10)]
    public int updateIntervalFrames = 5; 

    [Header("Debug")]
    public bool showGizmos = true;
    public Color gizmoColor = new Color(0, 1, 0, 0.3f);
    
    // ===== 内部资源 =====
    private Texture3D smokeAtlas;          
    private byte[] atlasDataCPU;           
    private ComputeBuffer metadataBuffer;  
    private SmokeVolumeData[] metadataArray;
    
    private class SlotInfo { public bool active; public Vector3 pos; public Vector3 size; }
    private SlotInfo[] slots = new SlotInfo[MAX_SMOKE_COUNT];

    private bool isTextureDirty = false;
    private bool isMetadataDirty = false;

    void Awake()
    {
        Instance = this;
        InitializeSystem();
    }

    private void Start()
    {
        Shader.SetGlobalFloat("_VolumeSize", GRID_WORLD_SIZE);
    }

    void OnDestroy()
    {
        if (metadataBuffer != null) metadataBuffer.Release();
        if (smokeAtlas != null) Destroy(smokeAtlas);
    }

    void InitializeSystem()
    {
        // 1. 初始化槽位
        for(int i=0; i<MAX_SMOKE_COUNT; i++) slots[i] = new SlotInfo();

        // 2. 初始化 3D 纹理图集 (32 x 32 x 512)
        // 注意：如果你需要更平滑的渐变，可以考虑使用 TextureFormat.RHalf (16bit浮点)，但 R8 最省显存
        smokeAtlas = new Texture3D(VOXEL_RES, VOXEL_RES, ATLAS_DEPTH, TextureFormat.RGBA32, false);
        smokeAtlas.wrapMode = TextureWrapMode.Clamp;
        smokeAtlas.filterMode = FilterMode.Trilinear;
        smokeAtlas.name = "DynamicSmokeAtlas";

        // 初始化全黑
        atlasDataCPU = new byte[VOXEL_RES * VOXEL_RES * ATLAS_DEPTH * 4];
        smokeAtlas.SetPixelData(atlasDataCPU, 0);
        smokeAtlas.Apply();

        // 3. 初始化 ComputeBuffer
        int stride = Marshal.SizeOf(typeof(SmokeVolumeData)); 
        metadataBuffer = new ComputeBuffer(MAX_SMOKE_COUNT, stride);
        metadataArray = new SmokeVolumeData[MAX_SMOKE_COUNT];
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
            // 释放时清理数据
            ClearSlotData(index);
        }
    }
    
    public void WriteDensityData(int slotIndex, byte[] allData, byte[] smokeData)
    {
        if (slotIndex < 0 || slotIndex >= MAX_SMOKE_COUNT) return;

        int voxelCount = VOXEL_RES * VOXEL_RES * VOXEL_RES;
        
        if (allData.Length != voxelCount || smokeData.Length != voxelCount)
        {
            Debug.LogError($"数据长度错误！需要 {voxelCount}，实际 allData:{allData.Length}, smokeData:{smokeData.Length}");
            return;
        }
        
        int startByteIndex = slotIndex * voxelCount * 4;
        
        for (int i = 0; i < voxelCount; i++)
        {
            // 当前像素在 atlasDataCPU 中的起始位置 (RGBA 的 R 位置)
            int ptr = startByteIndex + (i * 4);

            // --- 第一步：读取旧值 (History) ---
            // 必须先读出来，因为马上就要被覆盖了
            byte oldG = atlasDataCPU[ptr + 1]; // 读取旧的 G
            byte oldA = atlasDataCPU[ptr + 3]; // 读取旧的 A

            // --- 第二步：写入新值与旧值 ---
        
            // 逻辑1: 原 G 通道的值 -> 写入 R 通道
            atlasDataCPU[ptr + 0] = oldG;

            // 逻辑2: 新 allData -> 写入 G 通道
            atlasDataCPU[ptr + 1] = allData[i];

            // 逻辑3: 原 A 通道的值 -> 写入 B 通道
            atlasDataCPU[ptr + 2] = oldA;

            // 逻辑4: 新 smokeData -> 写入 A 通道
            atlasDataCPU[ptr + 3] = smokeData[i];
        }

        // 4. 标记脏数据，通知 Update 上传显存
        isTextureDirty = true;
    }

    public void WriteSmokeMetadata(int slotIndex, Vector3 pos, Vector3 size, Color tint, float intensity)
    {
        if (slotIndex < 0 || slotIndex >= MAX_SMOKE_COUNT) return;
        
        slots[slotIndex].pos = pos;
        slots[slotIndex].size = size;

        metadataArray[slotIndex] = new SmokeVolumeData
        {
            position = pos,
            volumeIndex = slotIndex,
            aabbMin = pos - size * 0.5f,
            padding1 = 0,
            aabbMax = pos + size * 0.5f,
            padding2 = 0,
            tint = new Vector3(tint.r, tint.g, tint.b),
            intensity = intensity
        };

        isMetadataDirty = true;
    }

    private void ClearSlotData(int slotIndex)
    {
        int oneVolSize = VOXEL_RES * VOXEL_RES * VOXEL_RES;
        int offset = slotIndex * oneVolSize;
        System.Array.Clear(atlasDataCPU, offset, oneVolSize);
        isTextureDirty = true;
    }
    
    void Update()
    {
        // 更新元数据 (Metadata) 必须每帧进行，因为烟雾可能会移动，或者相机在动
        // 这一步开销很小，只是几十个结构体的上传
        if (isMetadataDirty)
        {
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
                smokeMaskMaterial.SetBuffer("_SmokeVolumes", metadataBuffer);
                smokeMaskMaterial.SetInt("_SmokeCount", MAX_SMOKE_COUNT);
                smokeMaskMaterial.SetTexture("_SmokeTex3D", smokeAtlas);
            }
        
            Shader.SetGlobalBuffer("_SmokeVolumes", metadataBuffer);
            Shader.SetGlobalInt("_SmokeCount", MAX_SMOKE_COUNT);
            Shader.SetGlobalTexture("_SmokeTex3D", smokeAtlas);   
        }
    }

    // 核心修改：在 LateUpdate 中控制上传频率
    void LateUpdate()
    {
        // 1. 检查是否有数据变动
        // 2. 检查是否到了更新帧 (Time.frameCount % 5 == 0)
        if (isTextureDirty && (Time.frameCount % updateIntervalFrames == 0))
        {
            // 这一步是繁重的 GPU 带宽操作 (0.5MB 上传)
            // 现在它每秒只执行 60/5 = 12 次，而不是 60 次 
            smokeAtlas.SetPixelData(atlasDataCPU, 0);
            smokeAtlas.Apply();
            
            isTextureDirty = false;
        }
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
                
                Gizmos.color = Color.yellow;
                Gizmos.DrawSphere(slots[i].pos, 0.2f);
            }
        }
    }
}

#if UNITY_EDITOR
[CustomEditor(typeof(SmokeVolumeManager))]
public class SmokeVolumeManagerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        SmokeVolumeManager manager = (SmokeVolumeManager)target;

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Debug Controls", EditorStyles.boldLabel);
        
        if (GUILayout.Button("Force Clear All Slots"))
        {
             for(int i=0; i<SmokeVolumeManager.MAX_SMOKE_COUNT; i++) 
                 manager.ReleaseSmokeSlot(i);
        }
    }
}
#endif