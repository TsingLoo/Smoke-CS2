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
    
    [Header("Interpolation Settings")]
    [Tooltip("GPU插值的目标时间（秒）。数据上传后，GPU会在这个时间内平滑过渡到新值")]
    [Range(0.05f, 0.5f)]
    public float interpolationDuration = 0.1f;
    
    [Tooltip("最小上传间隔（秒）。防止过于频繁的GPU上传")]
    [Range(0.016f, 0.2f)]
    public float minUploadInterval = 0.05f;

    [Header("Debug")]
    public bool showGizmos = true;
    public Color gizmoColor = new Color(0, 1, 0, 0.3f);
    [SerializeField, ReadOnly] private float currentInterpolationT;
    [SerializeField, ReadOnly] private float timeSinceLastUpload;
    
    // ===== 内部资源 =====
    private Texture3D smokeAtlas;          
    private byte[] atlasDataCPU;           
    private ComputeBuffer metadataBuffer;  
    private SmokeVolumeData[] metadataArray;
    
    private class SlotInfo { public bool active; public Vector3 pos; public Vector3 size; }
    private SlotInfo[] slots = new SlotInfo[MAX_SMOKE_COUNT];

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

    void Awake()
    {
        Instance = this;
        InitializeSystem();
    }

    private void Start()
    {
        Shader.SetGlobalFloat(_VolumeSize, GRID_WORLD_SIZE);
        lastUploadTime = Time.time;
    }

    void OnDestroy()
    {
        if (metadataBuffer != null) metadataBuffer.Release();
        if (smokeAtlas != null) Destroy(smokeAtlas);
    }

    void InitializeSystem()
    {
        for(int i=0; i<MAX_SMOKE_COUNT; i++) slots[i] = new SlotInfo();

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
    /// 写入密度数据。数据会被编码到RGBA通道中：
    /// R = 历史 allData (用于插值起点)
    /// G = 当前 allData (用于插值终点)
    /// B = 历史 smokeData
    /// A = 当前 smokeData
    /// </summary>
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
            int ptr = startByteIndex + (i * 4);

            // 读取当前值作为历史
            byte oldG = atlasDataCPU[ptr + 1];
            byte oldA = atlasDataCPU[ptr + 3];

            // 编码：R=历史All, G=新All, B=历史Smoke, A=新Smoke
            atlasDataCPU[ptr + 0] = oldG;      // R: 历史 allData
            atlasDataCPU[ptr + 1] = allData[i]; // G: 新 allData
            atlasDataCPU[ptr + 2] = oldA;      // B: 历史 smokeData
            atlasDataCPU[ptr + 3] = smokeData[i]; // A: 新 smokeData
        }

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
        int oneVolSize = VOXEL_RES * VOXEL_RES * VOXEL_RES * 4; // RGBA
        int offset = slotIndex * oneVolSize;
        System.Array.Clear(atlasDataCPU, offset, oneVolSize);
        isTextureDirty = true;
    }
    
    void Update()
    {
        // 每帧更新插值因子
        UpdateInterpolationFactor();
        
        // 更新元数据
        if (isMetadataDirty)
        {
            UploadMetadata();
            isMetadataDirty = false;
        }
    }

    void LateUpdate()
    {
        // 检查是否需要上传纹理
        // 条件：有脏数据 AND 距离上次上传超过最小间隔
        float timeSinceUpload = Time.time - lastUploadTime;
        
        if (isTextureDirty && timeSinceUpload >= minUploadInterval)
        {
            UploadTextureData();
        }
    }

    /// <summary>
    /// 计算并更新GPU插值因子
    /// </summary>
    void UpdateInterpolationFactor()
    {
        timeSinceLastUpload = Time.time - lastUploadTime;
        
        // 计算插值进度 (0 -> 1)
        // 当 timeSinceLastUpload >= interpolationDuration 时，t = 1（完全使用新值）
        float t = Mathf.Clamp01(timeSinceLastUpload / interpolationDuration);
        
        // 可选：使用缓动函数让过渡更平滑
        t = SmoothStep(t);
        
        currentInterpolationT = t;
        
        // 传给Shader
        Shader.SetGlobalFloat(_InterpolationT, t);
    }

    /// <summary>
    /// 上传纹理数据到GPU
    /// </summary>
    void UploadTextureData()
    {
        smokeAtlas.SetPixelData(atlasDataCPU, 0);
        smokeAtlas.Apply();
        
        // 重置插值计时器
        lastUploadTime = Time.time;
        isTextureDirty = false;
        
        // 立即将插值因子设为0（从历史值开始）
        Shader.SetGlobalFloat(_InterpolationT, 0f);
    }

    void UploadMetadata()
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
            smokeMaskMaterial.SetBuffer(_SmokeVolumes, metadataBuffer);
            smokeMaskMaterial.SetInt(_SmokeCount, MAX_SMOKE_COUNT);
            smokeMaskMaterial.SetTexture(_SmokeTex3D, smokeAtlas);
        }
    
        Shader.SetGlobalBuffer(_SmokeVolumes, metadataBuffer);
        Shader.SetGlobalInt(_SmokeCount, MAX_SMOKE_COUNT);
        Shader.SetGlobalTexture(_SmokeTex3D, smokeAtlas);   
    }
    
    /// <summary>
    /// SmoothStep缓动函数
    /// </summary>
    static float SmoothStep(float t)
    {
        return t * t * (3f - 2f * t);
    }
    
    /// <summary>
    /// 更平滑的SmootherStep (Ken Perlin's版本)
    /// </summary>
    static float SmootherStep(float t)
    {
        return t * t * t * (t * (t * 6f - 15f) + 10f);
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

/// <summary>
/// 用于在Inspector中显示只读字段的特性
/// </summary>
public class ReadOnlyAttribute : PropertyAttribute { }

#if UNITY_EDITOR
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
        
        // 实时显示插值状态
        if (Application.isPlaying)
        {
            Repaint();
        }
    }
}
#endif