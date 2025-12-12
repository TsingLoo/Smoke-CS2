#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

public class Texture3DViewer : EditorWindow
{
    private Texture3D texture3D;
    
    // 缓存数据
    private Color[] cachedPixels;
    private Texture3D lastCachedTexture;
    
    // 查看模式
    private enum ViewMode { SliceX, SliceY, SliceZ }
    private ViewMode currentMode = ViewMode.SliceZ;
    
    // Slice控制
    private int sliceIndex = 0;
    
    // 自动播放
    private bool isPlaying = false;
    private double lastPlayTime = 0;
    private float playSpeed = 0.1f;
    
    // 显示增强
    private float exposure = 1.0f; 
    private bool renderAsGrayscale = true;
    private bool ignoreAlpha = true; 
    
    // 通道
    private bool showR = true;
    private bool showG = false;
    private bool showB = false;
    private bool showA = false;
    
    // --- 视图控制变量 (Pan & Zoom) ---
    private float zoom = 1.0f;
    private Vector2 panOffset = Vector2.zero; // 记录平移偏移量

    // --- 运行时抓取相关变量 ---
    private string globalTextureName = "_SmokeTex3D";
    private bool autoRefresh = false; 
    private double lastRefreshTime = 0;

    [MenuItem("Tools/Texture3D Runtime Viewer")]
    static void ShowWindow()
    {
        var window = GetWindow<Texture3DViewer>("Runtime 3D Viewer");
        window.minSize = new Vector2(400, 600);
    }
    
    void Update()
    {
        // 自动播放切片逻辑
        if (isPlaying && texture3D != null)
        {
            if (EditorApplication.timeSinceStartup - lastPlayTime > playSpeed)
            {
                lastPlayTime = EditorApplication.timeSinceStartup;
                int maxSlice = GetMaxSlice() - 1;
                sliceIndex++;
                if (sliceIndex > maxSlice) sliceIndex = 0;
                Repaint();
            }
        }

        // 自动刷新纹理数据逻辑
        if (Application.isPlaying && autoRefresh && texture3D != null)
        {
            if (EditorApplication.timeSinceStartup - lastRefreshTime > 0.5f)
            {
                GrabPixelData();
                lastRefreshTime = EditorApplication.timeSinceStartup;
                Repaint();
            }
        }
    }
    
    void OnGUI()
    {
        EditorGUILayout.BeginVertical();
        DrawControlPanel();
        
        // 绘制分割线
        GUILayout.Box("", GUILayout.ExpandWidth(true), GUILayout.Height(1));
        
        DrawPreviewArea();
        EditorGUILayout.EndVertical();
    }
    
    void DrawControlPanel()
    {
        GUILayout.Label("Runtime Texture3D Viewer", EditorStyles.boldLabel);
        EditorGUILayout.Space();
        
        // ================================================================
        // 1. 运行时抓取区域
        // ================================================================
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUILayout.LabelField("Runtime Capture", EditorStyles.boldLabel);
        
        globalTextureName = EditorGUILayout.TextField("Global Texture Name", globalTextureName);

        if (GUILayout.Button("Grab from Global Shader Variables"))
        {
            Texture globalTex = Shader.GetGlobalTexture(globalTextureName);
            if (globalTex is Texture3D t3d)
            {
                texture3D = t3d;
                GrabPixelData();
                ResetView(); // 抓取新纹理时重置视图
                Debug.Log($"Successfully grabbed {texture3D.name} ({texture3D.width}x{texture3D.height}x{texture3D.depth})");
            }
            else
            {
                Debug.LogError($"Could not find Texture3D with name '{globalTextureName}' in global shader variables. Make sure the game is running.");
            }
        }

        if (texture3D != null && Application.isPlaying)
        {
            autoRefresh = EditorGUILayout.Toggle("Auto Refresh Pixels (Slow!)", autoRefresh);
            if (autoRefresh)
            {
                EditorGUILayout.HelpBox("Warning: Auto-refreshing usually stalls the editor because extracting 3D pixels from GPU is slow.", MessageType.Warning);
            }
            else
            {
                if (GUILayout.Button("Refresh Pixels Manually"))
                {
                    GrabPixelData();
                }
            }
        }
        EditorGUILayout.EndVertical();

        EditorGUILayout.Space();
        
        // 2. 纹理手动选择
        EditorGUI.BeginChangeCheck();
        texture3D = (Texture3D)EditorGUILayout.ObjectField("Texture Asset", texture3D, typeof(Texture3D), false);
        if (EditorGUI.EndChangeCheck())
        {
            GrabPixelData();
            ResetView(); // 切换纹理时重置视图
            sliceIndex = 0;
        }
        
        if (texture3D == null) return;

        // 显示信息
        EditorGUILayout.LabelField($"Size: {texture3D.width} x {texture3D.height} x {texture3D.depth} ({texture3D.format})");
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("View Settings", EditorStyles.boldLabel);

        // 3. 模式与切片
        currentMode = (ViewMode)EditorGUILayout.EnumPopup("Slice Axis", currentMode);
        
        int maxSlice = GetMaxSlice();
        EditorGUILayout.BeginHorizontal();
        sliceIndex = EditorGUILayout.IntSlider("Slice Index", sliceIndex, 0, maxSlice - 1);
        
        if (GUILayout.Button(isPlaying ? "■" : "▶", GUILayout.Width(30)))
        {
            isPlaying = !isPlaying;
        }
        EditorGUILayout.EndHorizontal();

        // 4. 视觉增强
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Visualization", EditorStyles.boldLabel);
        
        exposure = EditorGUILayout.Slider("Exposure", exposure, 0.1f, 50.0f);
        if (GUILayout.Button("Auto Exposure")) AutoExposure();

        EditorGUILayout.BeginHorizontal();
        ignoreAlpha = EditorGUILayout.ToggleLeft("Ignore Alpha", ignoreAlpha, GUILayout.Width(100));
        renderAsGrayscale = EditorGUILayout.ToggleLeft("Grayscale", renderAsGrayscale);
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("Channels:", GUILayout.Width(70));
        showR = GUILayout.Toggle(showR, "R", "Button");
        showG = GUILayout.Toggle(showG, "G", "Button");
        showB = GUILayout.Toggle(showB, "B", "Button");
        showA = GUILayout.Toggle(showA, "A", "Button");
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.BeginHorizontal();
        zoom = EditorGUILayout.Slider("Zoom", zoom, 0.01f, 10.0f);
        if (GUILayout.Button("Reset View", GUILayout.Width(80)))
        {
            ResetView();
        }
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.HelpBox("Left Click/Drag to Pan. Scroll Wheel to Zoom.", MessageType.None);
    }
    
    // 从纹理读取像素数据
    void GrabPixelData()
    {
        if (texture3D == null) return;

        try 
        {
            cachedPixels = texture3D.GetPixels();
            lastCachedTexture = texture3D;
        }
        catch (System.Exception e)
        {
            Debug.LogError($"Error reading pixels: {e.Message}. Make sure the texture is readable.");
        }
    }

    void ResetView()
    {
        zoom = 1.0f;
        panOffset = Vector2.zero;
    }

    void DrawPreviewArea()
    {
        if (texture3D == null || cachedPixels == null) return;

        // 获取预览区域的矩形
        Rect rect = GUILayoutUtility.GetRect(100, 100, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(true));
        
        // 绘制深色背景
        EditorGUI.DrawRect(rect, new Color(0.1f, 0.1f, 0.1f));

        // --- 处理输入事件 (Pan & Zoom) ---
        HandlePreviewInput(rect);

        // 限制绘图区域在 rect 内部 (Clip)
        GUI.BeginGroup(rect);

        Texture2D sliceTex = ExtractSlice();
        if (sliceTex != null)
        {
            float aspect = (float)sliceTex.width / sliceTex.height;
            float w = rect.width * zoom;
            float h = w / aspect;
            
            // 居中显示，并加上平移偏移量
            // 注意：GUI.BeginGroup 之后，(0,0) 就是 rect 的左上角
            float x = (rect.width - w) * 0.5f + panOffset.x;
            float y = (rect.height - h) * 0.5f + panOffset.y;
            
            Rect drawRect = new Rect(x, y, w, h);
            
            GUI.DrawTexture(drawRect, sliceTex, ScaleMode.ScaleToFit, false);
            
            // 画边框
            Handles.color = new Color(1, 1, 1, 0.5f);
            Handles.DrawWireCube(drawRect.center, new Vector3(drawRect.width, drawRect.height, 0));
            
            DestroyImmediate(sliceTex);
        }
        
        GUI.EndGroup();
    }

    void HandlePreviewInput(Rect rect)
    {
        Event e = Event.current;
        
        // 只有鼠标在预览区域内才响应
        if (rect.Contains(e.mousePosition))
        {
            // 1. 鼠标滚轮缩放
            if (e.type == EventType.ScrollWheel)
            {
                float zoomDelta = -e.delta.y * 0.05f * zoom; // 基于当前zoom速度缩放
                zoom += zoomDelta;
                zoom = Mathf.Clamp(zoom, 0.01f, 10.0f);
                e.Use(); // 消耗事件，防止滚动列表
                Repaint();
            }
            // 2. 鼠标拖拽平移 (左键或中键)
            else if (e.type == EventType.MouseDrag && (e.button == 0 || e.button == 2))
            {
                panOffset += e.delta;
                e.Use();
                Repaint();
            }
        }
    }

    Texture2D ExtractSlice()
    {
        int w = 0, h = 0;
        switch (currentMode)
        {
            case ViewMode.SliceX: w = texture3D.depth; h = texture3D.height; break;
            case ViewMode.SliceY: w = texture3D.width; h = texture3D.depth; break;
            case ViewMode.SliceZ: w = texture3D.width; h = texture3D.height; break;
        }

        Color[] sliceColors = new Color[w * h];
        int texW = texture3D.width;
        int texH = texture3D.height;
        int texD = texture3D.depth; 

        if (sliceIndex >= (currentMode == ViewMode.SliceX ? texW : (currentMode == ViewMode.SliceY ? texH : texD)))
            sliceIndex = 0;

        for (int v = 0; v < h; v++)
        {
            for (int u = 0; u < w; u++)
            {
                int x=0, y=0, z=0;
                switch (currentMode)
                {
                    case ViewMode.SliceX: x = sliceIndex; y = v; z = u; break;
                    case ViewMode.SliceY: x = u; y = sliceIndex; z = v; break;
                    case ViewMode.SliceZ: x = u; y = v; z = sliceIndex; break;
                }

                int flatIndex = x + (y * texW) + (z * texW * texH);
                
                if (flatIndex >= 0 && flatIndex < cachedPixels.Length)
                {
                    sliceColors[u + v * w] = ProcessColor(cachedPixels[flatIndex]);
                }
            }
        }

        Texture2D result = new Texture2D(w, h);
        result.filterMode = FilterMode.Point;
        result.SetPixels(sliceColors);
        result.Apply();
        return result;
    }

    Color ProcessColor(Color c)
    {
        float r = showR ? c.r : 0;
        float g = showG ? c.g : 0;
        float b = showB ? c.b : 0;
        float a = showA ? c.a : 1;

        r *= exposure;
        g *= exposure;
        b *= exposure;
        
        if (ignoreAlpha) a = 1.0f;

        if (renderAsGrayscale)
        {
            int activeChannels = (showR?1:0) + (showG?1:0) + (showB?1:0);
            if (activeChannels == 1)
            {
                float val = showR ? r : (showG ? g : b);
                return new Color(val, val, val, a);
            }
        }
        return new Color(r, g, b, a);
    }

    int GetMaxSlice()
    {
        if (texture3D == null) return 0;
        switch (currentMode)
        {
            case ViewMode.SliceX: return texture3D.width;
            case ViewMode.SliceY: return texture3D.height;
            case ViewMode.SliceZ: return texture3D.depth;
        }
        return 0;
    }
    
    void AutoExposure()
    {
        if (cachedPixels == null) return;
        float maxVal = 0f;
        for(int i=0; i<cachedPixels.Length; i+=10) 
        {
            Color c = cachedPixels[i];
            if(showR) maxVal = Mathf.Max(maxVal, c.r);
        }
        
        if (maxVal > 0.0001f) exposure = 1.0f / maxVal;
        else exposure = 100.0f;
    }
}
#endif