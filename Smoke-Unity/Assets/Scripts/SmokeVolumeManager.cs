using UnityEngine;
using System.Collections.Generic;
using System.Runtime.InteropServices;

#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// CS2风格的动态烟雾管理器 (融合版)
/// 负责：
/// 1. 维护 3D 纹理图集 (Z-Stack Atlas)
/// 2. 分配槽位给烟雾弹
/// 3. 将位置和密度数据传给 GPU
/// </summary>
public class SmokeVolumeManager : MonoBehaviour
{
    public static SmokeVolumeManager Instance { get; private set; }

    // ===== 核心配置 =====
    public const int MAX_SMOKE_COUNT = 16;
    public const int VOXEL_RES = 32; // 单个烟雾分辨率
    
    // ===== Shader 数据结构 (64 Bytes) =====
    [StructLayout(LayoutKind.Sequential)]
    struct SmokeVolumeData
    {
        public Vector3 position;      
        public int volumeIndex;       // 对应图集中的 Z 层级 (0-15)
        public Vector3 aabbMin;       
        public float padding1;
        public Vector3 aabbMax;       
        public float padding2;
        public Vector3 tint;          
        public float intensity;       
    }
    
    // ===== Inspector 配置 =====
    [Header("References")]
    public Material smokeMaskMaterial; // 挂载了 Smoke Shader 的材质
    
    [Header("Debug")]
    public bool showGizmos = true;
    public Color gizmoColor = new Color(0, 1, 0, 0.3f);
    
    // ===== 内部资源 =====
    private Texture3D smokeAtlas;          // 动态生成的图集 (32 x 32 x 512)
    private byte[] atlasDataCPU;           // CPU 端内存镜像
    private ComputeBuffer metadataBuffer;  // 传给 Shader 的结构体数据
    private SmokeVolumeData[] metadataArray;
    
    // 槽位管理：记录哪些 index 被占用了
    // 我们用一个固定的数组来管理 slot，而不是 List，因为 Index 必须固定对应 Texture 层级
    private class SlotInfo { public bool active; public Vector3 pos; public Vector3 size; }
    private SlotInfo[] slots = new SlotInfo[MAX_SMOKE_COUNT];

    private bool isTextureDirty = false;

    void Awake()
    {
        Instance = this;
        InitializeSystem();
    }

    void OnDestroy()
    {
        if (metadataBuffer != null) metadataBuffer.Release();
    }

    void InitializeSystem()
    {
        // 1. 初始化槽位
        for(int i=0; i<MAX_SMOKE_COUNT; i++) slots[i] = new SlotInfo();

        // 2. 初始化 3D 纹理图集 (Z轴堆叠: 32x32x512)
        // 使用 R8 格式 (单通道 Byte)，极大节省内存
        smokeAtlas = new Texture3D(VOXEL_RES, VOXEL_RES, VOXEL_RES * MAX_SMOKE_COUNT, TextureFormat.R8, false);
        smokeAtlas.wrapMode = TextureWrapMode.Clamp;
        smokeAtlas.filterMode = FilterMode.Bilinear;
        smokeAtlas.name = "DynamicSmokeAtlas";

        // 初始化全黑
        atlasDataCPU = new byte[VOXEL_RES * VOXEL_RES * VOXEL_RES * MAX_SMOKE_COUNT];
        smokeAtlas.SetPixelData(atlasDataCPU, 0);
        smokeAtlas.Apply();

        // 3. 初始化 ComputeBuffer
        int stride = Marshal.SizeOf(typeof(SmokeVolumeData)); // 64
        metadataBuffer = new ComputeBuffer(MAX_SMOKE_COUNT, stride);
        metadataArray = new SmokeVolumeData[MAX_SMOKE_COUNT];
    }

    // =========================================================
    // API: 供 VolumetricSmokeSimulation 调用
    // =========================================================

    /// <summary>
    /// 申请一个空的烟雾槽位 (相当于 AddSmoke)
    /// 返回槽位 ID (0-15)，失败返回 -1
    /// </summary>
    public int AllocateSmokeSlot()
    {
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            if (!slots[i].active)
            {
                slots[i].active = true;
                slots[i].pos = Vector3.zero;
                slots[i].size = Vector3.one;
                return i;
            }
        }
        Debug.LogWarning("Smoke Manager: Max smoke limit reached!");
        return -1;
    }

    /// <summary>
    /// 释放槽位 (相当于 RemoveSmoke)
    /// </summary>
    public void ReleaseSmokeSlot(int index)
    {
        if (index >= 0 && index < MAX_SMOKE_COUNT)
        {
            slots[index].active = false;
            // 可选：清空该区域的纹理数据（设为0），防止残留
            ClearSlotData(index);
        }
    }

    /// <summary>
    /// 上传密度数据 (核心逻辑)
    /// </summary>
    public void UploadDensityData(int slotIndex, byte[] localData)
    {
        if (slotIndex < 0 || slotIndex >= MAX_SMOKE_COUNT) return;
        
        int oneVolSize = VOXEL_RES * VOXEL_RES * VOXEL_RES;
        if (localData.Length != oneVolSize) return;

        // 极速拷贝到 CPU 镜像的对应 Z 轴层级
        int offset = slotIndex * oneVolSize;
        System.Buffer.BlockCopy(localData, 0, atlasDataCPU, offset, oneVolSize);
        
        isTextureDirty = true;
    }

    /// <summary>
    /// 更新元数据 (位置、大小)
    /// </summary>
    public void UpdateSmokeMetadata(int slotIndex, Vector3 pos, Vector3 size, Color tint, float intensity)
    {
        if (slotIndex < 0 || slotIndex >= MAX_SMOKE_COUNT) return;
        
        // 更新本地记录供 Gizmos 使用
        slots[slotIndex].pos = pos;
        slots[slotIndex].size = size;

        // 准备传给 GPU 的数据
        metadataArray[slotIndex] = new SmokeVolumeData
        {
            position = pos,
            volumeIndex = slotIndex, // 这一点至关重要，Shader靠它找 Z 层级
            aabbMin = pos - size * 0.5f,
            padding1 = 0,
            aabbMax = pos + size * 0.5f,
            padding2 = 0,
            tint = new Vector3(tint.r, tint.g, tint.b),
            intensity = intensity
        };
    }

    private void ClearSlotData(int slotIndex)
    {
        int oneVolSize = VOXEL_RES * VOXEL_RES * VOXEL_RES;
        int offset = slotIndex * oneVolSize;
        System.Array.Clear(atlasDataCPU, offset, oneVolSize);
        isTextureDirty = true;
    }

    // =========================================================
    // Update Loop
    // =========================================================

    void Update()
    {
        // 1. 更新 Metadata Buffer (位置/状态)
        // 这是一个比较粗暴的做法，每帧全部更新。
        // 如果想优化，可以把 metadataArray 的非 active 槽位设为无效数据
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            if (!slots[i].active)
            {
                metadataArray[i].intensity = 0; // 只要强度为0，Shader就不会画
                metadataArray[i].volumeIndex = -1;
            }
        }
        metadataBuffer.SetData(metadataArray);

        // 2. 设置全局 Shader 参数
        if (smokeMaskMaterial != null)
        {
            smokeMaskMaterial.SetBuffer("_SmokeVolumes", metadataBuffer);
            smokeMaskMaterial.SetInt("_SmokeCount", MAX_SMOKE_COUNT);
            smokeMaskMaterial.SetTexture("_SmokeTex3D", smokeAtlas);
        }
        
        // 全局设置，方便其他物体也能接受烟雾
        Shader.SetGlobalBuffer("_SmokeVolumes", metadataBuffer);
        Shader.SetGlobalInt("_SmokeCount", MAX_SMOKE_COUNT);
        Shader.SetGlobalTexture("_SmokeTex3D", smokeAtlas);
    }

    void LateUpdate()
    {
        // 3. 只有当数据变脏时才上传纹理 (节省带宽)
        if (isTextureDirty)
        {
            smokeAtlas.SetPixelData(atlasDataCPU, 0);
            smokeAtlas.Apply();
            isTextureDirty = false;
        }
    }

    // =========================================================
    // Gizmos (保留你的可视化逻辑)
    // =========================================================
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
                
                // 画中心点
                Gizmos.color = Color.yellow;
                Gizmos.DrawSphere(slots[i].pos, 0.2f);
                
                #if UNITY_EDITOR
                Handles.Label(slots[i].pos + Vector3.up, $"ID:{i}");
                #endif
            }
        }
    }
}

// =========================================================
// Editor (保留快捷调试功能)
// =========================================================
#if UNITY_EDITOR
[CustomEditor(typeof(SmokeVolumeManager))]
public class SmokeVolumeManagerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        SmokeVolumeManager manager = (SmokeVolumeManager)target;

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Debug Info", EditorStyles.boldLabel);
        
        // 简单的统计
        int active = 0;
        // 这里需要通过反射或者公开 Slots 才能统计，暂时略过
        
        if (GUILayout.Button("Clear All Slots"))
        {
             for(int i=0; i<SmokeVolumeManager.MAX_SMOKE_COUNT; i++) 
                 manager.ReleaseSmokeSlot(i);
        }
    }
}
#endif