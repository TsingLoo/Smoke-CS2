using UnityEngine;
using System.Collections.Generic;

#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// CS2风格的烟雾体积管理器
/// 管理多个烟雾弹，并将数据传递给Shader
/// </summary>
public class SmokeVolumeManager : MonoBehaviour
{
    // ===== 烟雾体积数据结构 =====
    // 必须与Shader中的SmokeVolume结构体完全匹配！
    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    struct SmokeVolumeData
    {
        public Vector3 position;      // 12 bytes
        public int volumeIndex;       // 4 bytes
        public Vector3 aabbMin;       // 12 bytes
        public float padding1;
        public Vector3 aabbMax;       // 12 bytes (padding to 16-byte boundary)
        public float padding2;
        public Vector3 tint;          // 12 bytes
        public float intensity;       // 4 bytes
    }
    
    // ===== Inspector配置 =====
    [Header("References")]
    [Tooltip("烟雾遮罩Material（使用SmokeMask Shader）")]
    public Material smokeMaskMaterial;
    
    [Tooltip("烟雾3D纹理（542×32×32）")]
    public Texture3D smokeTexture3D;
    
    [Tooltip("目标相机（通常是主相机）")]
    public Camera targetCamera;
    
    [Header("Smoke Volumes")]
    [Tooltip("烟雾体积列表（最多16个）")]
    public List<SmokeVolume> smokeVolumes = new List<SmokeVolume>();
    
    [Header("Debug")]
    [Tooltip("显示AABB包围盒")]
    public bool showAABB = true;
    
    [Tooltip("显示烟雾中心点")]
    public bool showCenterGizmo = true;
    
    [Tooltip("Gizmo颜色")]
    public Color gizmoColor = new Color(0, 1, 0, 0.5f);
    
    // ===== 私有变量 =====
    private ComputeBuffer smokeBuffer;
    private SmokeVolumeData[] smokeData;
    private const int MAX_SMOKE_COUNT = 16;
    
    // ===== 烟雾体积类 =====
    [System.Serializable]
    public class SmokeVolume
    {
        [Header("Transform")]
        [Tooltip("烟雾中心位置")]
        public Vector3 position = Vector3.zero;
        
        [Tooltip("烟雾体积大小（游戏单位）")]
        public Vector3 size = new Vector3(640, 640, 640);
        
        [Header("Texture")]
        [Tooltip("使用哪个烟雾纹理（0-15）")]
        [Range(0, 15)]
        public int volumeIndex = 0;
        
        [Header("Appearance")]
        [Tooltip("烟雾颜色tint")]
        public Color tint = Color.white;
        
        [Tooltip("烟雾强度")]
        [Range(0f, 2f)]
        public float intensity = 1f;
        
        [Header("State")]
        [Tooltip("是否激活")]
        public bool active = true;
        
        // 辅助方法：获取AABB
        public Vector3 GetAABBMin()
        {
            return position - size * 0.5f;
        }
        
        public Vector3 GetAABBMax()
        {
            return position + size * 0.5f;
        }
    }
    
    // ===== Unity生命周期 =====
    
    void Start()
    {
        InitializeBuffer();
        
        if (targetCamera == null)
        {
            targetCamera = Camera.main;
            if (targetCamera == null)
            {
                Debug.LogError("[SmokeVolumeManager] No camera found! Please assign target camera.");
            }
        }
        
        if (smokeTexture3D == null)
        {
            Debug.LogWarning("[SmokeVolumeManager] No smoke texture assigned!");
        }
        
        if (smokeMaskMaterial == null)
        {
            Debug.LogError("[SmokeVolumeManager] No material assigned!");
        }
    }
    
    void Update()
    {
        UpdateSmokeData();
    }
    
    void OnDestroy()
    {
        ReleaseBuffer();
    }
    
    void OnDisable()
    {
        ReleaseBuffer();
    }
    
    // ===== Buffer管理 =====
    
    void InitializeBuffer()
    {
        // 每个SmokeVolumeData: 56 bytes
        // 16个烟雾 = 896 bytes
        int stride = System.Runtime.InteropServices.Marshal.SizeOf(typeof(SmokeVolumeData));
        smokeBuffer = new ComputeBuffer(MAX_SMOKE_COUNT, stride);
        smokeData = new SmokeVolumeData[MAX_SMOKE_COUNT];
        
        Debug.Log($"[SmokeVolumeManager] Buffer initialized: {MAX_SMOKE_COUNT} smokes, {stride} bytes/smoke, total {stride * MAX_SMOKE_COUNT} bytes");
    }
    
    void ReleaseBuffer()
    {
        if (smokeBuffer != null)
        {
            smokeBuffer.Release();
            smokeBuffer = null;
        }
    }
    
    // ===== 数据更新 =====
    
    void UpdateSmokeData()
    {
        if (smokeBuffer == null)
        {
            InitializeBuffer();
        }
        
        if (smokeMaskMaterial == null)
        {
            return;
        }
        
        // 清空数据
        for (int i = 0; i < MAX_SMOKE_COUNT; i++)
        {
            smokeData[i] = new SmokeVolumeData
            {
                volumeIndex = -1  // -1表示无效
            };
        }
        
        // 填充激活的烟雾数据
        int activeCount = 0;
        for (int i = 0; i < smokeVolumes.Count && activeCount < MAX_SMOKE_COUNT; i++)
        {
            if (smokeVolumes[i] != null && smokeVolumes[i].active)
            {
                var smoke = smokeVolumes[i];
                
                smokeData[activeCount] = new SmokeVolumeData
                {
                    position = smoke.position,
                    volumeIndex = smoke.volumeIndex,
                    aabbMin = smoke.GetAABBMin(),
                    aabbMax = smoke.GetAABBMax(),
                    tint = new Vector3(smoke.tint.r, smoke.tint.g, smoke.tint.b),
                    intensity = smoke.intensity
                };
                
                activeCount++;
            }
        }
        
        // 上传到GPU
        smokeBuffer.SetData(smokeData);
        
        // 设置Shader参数
        smokeMaskMaterial.SetBuffer("_SmokeVolumes", smokeBuffer);
        smokeMaskMaterial.SetInt("_SmokeCount", activeCount);
        
        if (smokeTexture3D != null)
        {
            smokeMaskMaterial.SetTexture("_SmokeTex3D", smokeTexture3D);
        }
        
        // 设置为全局（可选，如果其他Shader也需要访问）
        Shader.SetGlobalBuffer("_SmokeVolumes", smokeBuffer);
        Shader.SetGlobalInt("_SmokeCount", activeCount);
        Shader.SetGlobalTexture("_SmokeTex3D", smokeTexture3D);
    }
    
    // ===== 公共方法 =====
    
    /// <summary>
    /// 添加新烟雾
    /// </summary>
    public SmokeVolume AddSmoke(Vector3 position, int textureIndex = 0)
    {
        if (smokeVolumes.Count >= MAX_SMOKE_COUNT)
        {
            Debug.LogWarning("[SmokeVolumeManager] Cannot add more smoke! Max limit reached.");
            return null;
        }
        
        var smoke = new SmokeVolume
        {
            position = position,
            volumeIndex = textureIndex,
            active = true
        };
        
        smokeVolumes.Add(smoke);
        Debug.Log($"[SmokeVolumeManager] Added smoke at {position}, index {textureIndex}");
        
        return smoke;
    }
    
    /// <summary>
    /// 移除烟雾
    /// </summary>
    public void RemoveSmoke(SmokeVolume smoke)
    {
        if (smokeVolumes.Remove(smoke))
        {
            Debug.Log("[SmokeVolumeManager] Smoke removed");
        }
    }
    
    /// <summary>
    /// 清空所有烟雾
    /// </summary>
    public void ClearAllSmoke()
    {
        smokeVolumes.Clear();
        Debug.Log("[SmokeVolumeManager] All smoke cleared");
    }
    
    /// <summary>
    /// 获取激活的烟雾数量
    /// </summary>
    public int GetActiveSmokeCount()
    {
        int count = 0;
        foreach (var smoke in smokeVolumes)
        {
            if (smoke != null && smoke.active)
                count++;
        }
        return count;
    }
    
    // ===== Gizmos绘制 =====
    
    void OnDrawGizmos()
    {
        if (!showAABB && !showCenterGizmo)
            return;
        
        Gizmos.color = gizmoColor;
        
        foreach (var smoke in smokeVolumes)
        {
            if (smoke == null || !smoke.active)
                continue;
            
            //
            // 绘制AABB包围盒
            if (showAABB)
            {
                Gizmos.color = gizmoColor;
                Gizmos.DrawWireCube(smoke.position, smoke.size);
                
                // 绘制半透明立方体
                Color fillColor = gizmoColor;
                fillColor.a *= 0.1f;
                Gizmos.color = fillColor;
                Gizmos.DrawCube(smoke.position, smoke.size);
            }
            
            // 绘制中心点
            if (showCenterGizmo)
            {
                Gizmos.color = Color.yellow;
                Gizmos.DrawSphere(smoke.position, 5f);
                
                // 绘制坐标轴
                Gizmos.color = Color.red;
                Gizmos.DrawLine(smoke.position, smoke.position + Vector3.right * 50);
                Gizmos.color = Color.green;
                Gizmos.DrawLine(smoke.position, smoke.position + Vector3.up * 50);
                Gizmos.color = Color.blue;
                Gizmos.DrawLine(smoke.position, smoke.position + Vector3.forward * 50);
            }
            
            // 绘制标签
            #if UNITY_EDITOR
            UnityEditor.Handles.Label(
                smoke.position + Vector3.up * (smoke.size.y * 0.5f + 20),
                $"Smoke {smoke.volumeIndex}\n{smoke.position}",
                new GUIStyle
                {
                    normal = { textColor = Color.white },
                    fontSize = 12,
                    alignment = TextAnchor.MiddleCenter
                }
            );
            #endif
        }
    }
    
    void OnDrawGizmosSelected()
    {
        // 选中时绘制更详细的信息
        Gizmos.color = Color.cyan;
        
        foreach (var smoke in smokeVolumes)
        {
            if (smoke == null || !smoke.active)
                continue;
            
            // 绘制体素网格（简化版，只画几条线）
            Vector3 min = smoke.GetAABBMin();
            Vector3 max = smoke.GetAABBMax();
            
            // 画几条分割线显示体素网格
            for (int i = 0; i <= 4; i++)
            {
                float t = i / 4f;
                
                // X方向
                Vector3 p0 = Vector3.Lerp(min, new Vector3(max.x, min.y, min.z), t);
                Vector3 p1 = Vector3.Lerp(new Vector3(min.x, max.y, min.z), new Vector3(max.x, max.y, min.z), t);
                Gizmos.DrawLine(p0, p1);
                
                // Y方向
                p0 = Vector3.Lerp(min, new Vector3(min.x, max.y, min.z), t);
                p1 = Vector3.Lerp(new Vector3(max.x, min.y, min.z), new Vector3(max.x, max.y, min.z), t);
                Gizmos.DrawLine(p0, p1);
            }
        }
    }
}

// ===== Editor扩展 =====
#if UNITY_EDITOR
[CustomEditor(typeof(SmokeVolumeManager))]
public class SmokeVolumeManagerEditor : Editor
{
    private SmokeVolumeManager manager;
    
    void OnEnable()
    {
        manager = (SmokeVolumeManager)target;
    }
    
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        
        EditorGUILayout.Space(10);
        EditorGUILayout.LabelField("Quick Actions", EditorStyles.boldLabel);
        
        // 统计信息
        int activeCount = manager.GetActiveSmokeCount();
        EditorGUILayout.HelpBox(
            $"Active Smokes: {activeCount} / {manager.smokeVolumes.Count}\n" +
            $"Max Limit: 16",
            activeCount > 0 ? MessageType.Info : MessageType.Warning
        );
        
        EditorGUILayout.Space(5);
        
        // 快速添加按钮
        EditorGUILayout.BeginHorizontal();
        
        if (GUILayout.Button("Add Smoke at Origin", GUILayout.Height(30)))
        {
            Undo.RecordObject(manager, "Add Smoke");
            manager.AddSmoke(Vector3.zero, manager.smokeVolumes.Count);
            EditorUtility.SetDirty(manager);
        }
        
        if (GUILayout.Button("Add at Camera", GUILayout.Height(30)))
        {
            Undo.RecordObject(manager, "Add Smoke at Camera");
            Vector3 camPos = SceneView.lastActiveSceneView != null 
                ? SceneView.lastActiveSceneView.camera.transform.position
                : Vector3.zero;
            manager.AddSmoke(camPos + Vector3.forward * 500, manager.smokeVolumes.Count);
            EditorUtility.SetDirty(manager);
        }
        
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.Space(5);
        
        // 批量操作
        EditorGUILayout.BeginHorizontal();
        
        if (GUILayout.Button("Clear All", GUILayout.Height(25)))
        {
            if (EditorUtility.DisplayDialog(
                "Clear All Smoke",
                "Are you sure you want to remove all smoke volumes?",
                "Yes", "Cancel"))
            {
                Undo.RecordObject(manager, "Clear All Smoke");
                manager.ClearAllSmoke();
                EditorUtility.SetDirty(manager);
            }
        }
        
        if (GUILayout.Button("Deactivate All", GUILayout.Height(25)))
        {
            Undo.RecordObject(manager, "Deactivate All Smoke");
            foreach (var smoke in manager.smokeVolumes)
            {
                if (smoke != null)
                    smoke.active = false;
            }
            EditorUtility.SetDirty(manager);
        }
        
        if (GUILayout.Button("Activate All", GUILayout.Height(25)))
        {
            Undo.RecordObject(manager, "Activate All Smoke");
            foreach (var smoke in manager.smokeVolumes)
            {
                if (smoke != null)
                    smoke.active = true;
            }
            EditorUtility.SetDirty(manager);
        }
        
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.Space(5);
        
        // 测试网格生成
        if (GUILayout.Button("Generate Test Grid (4×4)", GUILayout.Height(30)))
        {
            Undo.RecordObject(manager, "Generate Test Grid");
            manager.ClearAllSmoke();
            
            Vector3 startPos = manager.targetCamera != null 
                ? manager.targetCamera.transform.position + manager.targetCamera.transform.forward * 1000
                : new Vector3(0, 0, 1000);
            
            for (int x = 0; x < 4; x++)
            {
                for (int z = 0; z < 4; z++)
                {
                    Vector3 pos = startPos + new Vector3(x * 800, 0, z * 800);
                    manager.AddSmoke(pos, (x + z * 4) % 16);
                }
            }
            
            EditorUtility.SetDirty(manager);
        }
        
        EditorGUILayout.Space(10);
        
        // 验证
        EditorGUILayout.LabelField("Validation", EditorStyles.boldLabel);
        
        if (manager.smokeMaskMaterial == null)
        {
            EditorGUILayout.HelpBox("No Material assigned!", MessageType.Error);
        }
        
        if (manager.smokeTexture3D == null)
        {
            EditorGUILayout.HelpBox("No Smoke Texture3D assigned!", MessageType.Warning);
        }
        else
        {
            EditorGUILayout.HelpBox(
                $"Texture: {manager.smokeTexture3D.width}×{manager.smokeTexture3D.height}×{manager.smokeTexture3D.depth}\n" +
                $"Format: {manager.smokeTexture3D.format}",
                MessageType.Info
            );
        }
        
        if (manager.targetCamera == null)
        {
            EditorGUILayout.HelpBox("No Camera assigned! Will use Camera.main at runtime.", MessageType.Warning);
        }
        
        EditorGUILayout.Space(10);
        
        // Buffer信息
        EditorGUILayout.LabelField("Buffer Info", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox(
            "Struct Size: 56 bytes\n" +
            "Max Count: 16\n" +
            "Total Buffer: 896 bytes",
            MessageType.Info
        );
    }
    
    // Scene视图工具
    void OnSceneGUI()
    {
        manager = (SmokeVolumeManager)target;
        
        // 为每个烟雾添加Position Handle
        for (int i = 0; i < manager.smokeVolumes.Count; i++)
        {
            var smoke = manager.smokeVolumes[i];
            if (smoke == null || !smoke.active)
                continue;
            
            EditorGUI.BeginChangeCheck();
            
            // 位置控制
            Vector3 newPos = Handles.PositionHandle(smoke.position, Quaternion.identity);
            
            if (EditorGUI.EndChangeCheck())
            {
                Undo.RecordObject(manager, "Move Smoke");
                smoke.position = newPos;
                EditorUtility.SetDirty(manager);
            }
            
            // 显示索引标签
            Handles.Label(
                smoke.position,
                $"[{i}] Smoke {smoke.volumeIndex}",
                new GUIStyle
                {
                    normal = { textColor = Color.yellow },
                    fontSize = 14,
                    fontStyle = FontStyle.Bold
                }
            );
        }
    }
}
#endif