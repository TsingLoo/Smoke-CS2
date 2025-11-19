#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

public class Texture3DViewer : EditorWindow
{
    private Texture3D texture3D;
    private Material previewMaterial;
    
    // 查看模式
    private enum ViewMode { Volume, SliceX, SliceY, SliceZ, AllSlices }
    private ViewMode currentMode = ViewMode.SliceZ;
    
    // Slice控制
    private int sliceX = 0;
    private int sliceY = 0;
    private int sliceZ = 15;
    
    // Volume控制
    private float densityMultiplier = 1.0f;
    private float alphaThreshold = 0.01f;
    private Color tintColor = Color.white;
    
    // 显示控制
    private bool showGrid = true;
    private bool showChannelR = true;
    private bool showChannelG = true;
    private bool showChannelB = true;
    private bool showChannelA = true;
    
    // 烟雾弹选择
    private int selectedSmoke = 0;
    private bool isolateSmoke = false;
    
    // 缩放和滚动
    private Vector2 scrollPosition;
    private float zoom = 1.0f;
    
    // 统计信息
    private bool showStats = true;
    private string statsText = "";
    
    [MenuItem("Tools/Texture3D Viewer")]
    static void ShowWindow()
    {
        var window = GetWindow<Texture3DViewer>("Texture3D Viewer");
        window.minSize = new Vector2(600, 700);
    }
    
    void OnEnable()
    {
        CreatePreviewMaterial();
    }
    
    void CreatePreviewMaterial()
    {
        Shader shader = Shader.Find("Hidden/Texture3DPreview");
        if (shader == null)
        {
            // 创建简单的预览shader
            shader = Shader.Find("Unlit/Texture");
        }
        previewMaterial = new Material(shader);
    }
    
    void OnGUI()
    {
        EditorGUILayout.BeginHorizontal();
        
        // 左侧控制面板
        DrawControlPanel();
        
        // 右侧预览区域
        DrawPreviewArea();
        
        EditorGUILayout.EndHorizontal();
    }
    
    void DrawControlPanel()
    {
        EditorGUILayout.BeginVertical(GUILayout.Width(250));
        
        GUILayout.Label("Texture3D Viewer", EditorStyles.boldLabel);
        EditorGUILayout.Space();
        
        // 纹理选择
        EditorGUILayout.LabelField("Texture", EditorStyles.boldLabel);
        texture3D = (Texture3D)EditorGUILayout.ObjectField(texture3D, typeof(Texture3D), false);
        
        if (texture3D != null)
        {
            EditorGUILayout.LabelField($"Dimensions: {texture3D.width}×{texture3D.height}×{texture3D.depth}");
            EditorGUILayout.LabelField($"Format: {texture3D.format}");
            EditorGUILayout.Space();
        }
        
        EditorGUILayout.Space();
        
        // 查看模式
        EditorGUILayout.LabelField("View Mode", EditorStyles.boldLabel);
        currentMode = (ViewMode)EditorGUILayout.EnumPopup("Mode", currentMode);
        EditorGUILayout.Space();
        
        // Slice控制
        if (texture3D != null)
        {
            if (currentMode == ViewMode.SliceX || currentMode == ViewMode.AllSlices)
            {
                sliceX = EditorGUILayout.IntSlider("Slice X", sliceX, 0, texture3D.width - 1);
            }
            if (currentMode == ViewMode.SliceY || currentMode == ViewMode.AllSlices)
            {
                sliceY = EditorGUILayout.IntSlider("Slice Y", sliceY, 0, texture3D.height - 1);
            }
            if (currentMode == ViewMode.SliceZ || currentMode == ViewMode.AllSlices)
            {
                sliceZ = EditorGUILayout.IntSlider("Slice Z", sliceZ, 0, texture3D.depth - 1);
            }
        }
        
        EditorGUILayout.Space();
        
        // 烟雾弹选择（仅对542宽度的纹理）
        if (texture3D != null && texture3D.width == 542)
        {
            EditorGUILayout.LabelField("Smoke Selection", EditorStyles.boldLabel);
            selectedSmoke = EditorGUILayout.IntSlider("Smoke Index", selectedSmoke, 0, 15);
            isolateSmoke = EditorGUILayout.Toggle("Isolate Smoke", isolateSmoke);
            
            if (GUILayout.Button("Jump to Smoke Center"))
            {
                JumpToSmokeCenter();
            }
            
            EditorGUILayout.Space();
        }
        
        // 显示控制
        EditorGUILayout.LabelField("Display", EditorStyles.boldLabel);
        showChannelR = EditorGUILayout.Toggle("Show R", showChannelR);
        showChannelG = EditorGUILayout.Toggle("Show G", showChannelG);
        showChannelB = EditorGUILayout.Toggle("Show B", showChannelB);
        showChannelA = EditorGUILayout.Toggle("Show A", showChannelA);
        EditorGUILayout.Space();
        
        // Volume控制
        if (currentMode == ViewMode.Volume)
        {
            EditorGUILayout.LabelField("Volume Rendering", EditorStyles.boldLabel);
            densityMultiplier = EditorGUILayout.Slider("Density", densityMultiplier, 0.1f, 5.0f);
            alphaThreshold = EditorGUILayout.Slider("Threshold", alphaThreshold, 0.0f, 1.0f);
            tintColor = EditorGUILayout.ColorField("Tint Color", tintColor);
            EditorGUILayout.Space();
        }
        
        // 缩放
        zoom = EditorGUILayout.Slider("Zoom", zoom, 0.25f, 4.0f);
        showGrid = EditorGUILayout.Toggle("Show Grid", showGrid);
        EditorGUILayout.Space();
        
        // 统计信息
        showStats = EditorGUILayout.Toggle("Show Statistics", showStats);
        
        if (texture3D != null && GUILayout.Button("Calculate Statistics"))
        {
            CalculateStatistics();
        }
        
        if (showStats && !string.IsNullOrEmpty(statsText))
        {
            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Statistics", EditorStyles.boldLabel);
            EditorGUILayout.HelpBox(statsText, MessageType.Info);
        }
        
        EditorGUILayout.Space();
        
        // 导出功能
        EditorGUILayout.LabelField("Export", EditorStyles.boldLabel);
        if (GUILayout.Button("Export Current Slice as PNG"))
        {
            ExportCurrentSlice();
        }
        
        EditorGUILayout.EndVertical();
    }
    
    void DrawPreviewArea()
    {
        EditorGUILayout.BeginVertical();
        
        if (texture3D == null)
        {
            EditorGUILayout.HelpBox("Please select a Texture3D to preview", MessageType.Info);
            EditorGUILayout.EndVertical();
            return;
        }
        
        Rect previewRect = GUILayoutUtility.GetRect(100, 100, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(true));
        
        // 绘制背景
        EditorGUI.DrawRect(previewRect, new Color(0.2f, 0.2f, 0.2f));
        
        switch (currentMode)
        {
            case ViewMode.SliceX:
                DrawSlicePreview(previewRect, 0); // YZ平面
                break;
            case ViewMode.SliceY:
                DrawSlicePreview(previewRect, 1); // XZ平面
                break;
            case ViewMode.SliceZ:
                DrawSlicePreview(previewRect, 2); // XY平面
                break;
            case ViewMode.AllSlices:
                DrawAllSlicesPreview(previewRect);
                break;
            case ViewMode.Volume:
                DrawVolumePreview(previewRect);
                break;
        }
        
        EditorGUILayout.EndVertical();
    }
    
    void DrawSlicePreview(Rect rect, int axis)
    {
        // 根据axis提取2D切片
        Texture2D sliceTexture = Extract2DSlice(axis);
        
        if (sliceTexture != null)
        {
            // 计算居中显示的矩形
            float aspectRatio = (float)sliceTexture.width / sliceTexture.height;
            float displayWidth = rect.width * zoom;
            float displayHeight = displayWidth / aspectRatio;
            
            if (displayHeight > rect.height * zoom)
            {
                displayHeight = rect.height * zoom;
                displayWidth = displayHeight * aspectRatio;
            }
            
            float x = rect.x + (rect.width - displayWidth) * 0.5f;
            float y = rect.y + (rect.height - displayHeight) * 0.5f;
            
            Rect displayRect = new Rect(x, y, displayWidth, displayHeight);
            
            // 绘制纹理
            GUI.DrawTexture(displayRect, sliceTexture, ScaleMode.ScaleToFit, true);
            
            // 绘制网格
            if (showGrid)
            {
                DrawGrid(displayRect, sliceTexture.width, sliceTexture.height);
            }
            
            // 绘制烟雾弹边界（如果是XY平面且隔离模式）
            if (axis == 2 && texture3D.width == 542 && isolateSmoke)
            {
                DrawSmokeBounds(displayRect);
            }
            
            // 显示信息
            DrawSliceInfo(rect, axis);
            
            DestroyImmediate(sliceTexture);
        }
    }
    
    Texture2D Extract2DSlice(int axis)
    {
        int width, height;
        Color[] pixels;
        
        switch (axis)
        {
            case 0: // YZ平面 (X切片)
                width = texture3D.depth;
                height = texture3D.height;
                pixels = new Color[width * height];
                
                for (int z = 0; z < texture3D.depth; z++)
                {
                    for (int y = 0; y < texture3D.height; y++)
                    {
                        Color c = texture3D.GetPixel(sliceX, y, z);
                        pixels[z + y * width] = ApplyChannelMask(c);
                    }
                }
                break;
                
            case 1: // XZ平面 (Y切片)
                width = texture3D.width;
                height = texture3D.depth;
                pixels = new Color[width * height];
                
                for (int z = 0; z < texture3D.depth; z++)
                {
                    for (int x = 0; x < texture3D.width; x++)
                    {
                        Color c = texture3D.GetPixel(x, sliceY, z);
                        pixels[x + z * width] = ApplyChannelMask(c);
                    }
                }
                break;
                
            case 2: // XY平面 (Z切片)
            default:
                width = texture3D.width;
                height = texture3D.height;
                pixels = new Color[width * height];
                
                for (int y = 0; y < texture3D.height; y++)
                {
                    for (int x = 0; x < texture3D.width; x++)
                    {
                        Color c = texture3D.GetPixel(x, y, sliceZ);
                        
                        // 如果隔离烟雾弹，只显示选中的
                        if (isolateSmoke && texture3D.width == 542)
                        {
                            int smokeStart = selectedSmoke * 34;
                            int smokeEnd = smokeStart + 32;
                            if (x < smokeStart || x > smokeEnd)
                            {
                                c = Color.black;
                            }
                        }
                        
                        pixels[x + y * width] = ApplyChannelMask(c);
                    }
                }
                break;
        }
        
        Texture2D texture = new Texture2D(width, height, TextureFormat.RGBA32, false);
        texture.SetPixels(pixels);
        texture.Apply();
        texture.filterMode = FilterMode.Point; // 像素风格
        
        return texture;
    }
    
    Color ApplyChannelMask(Color c)
    {
        return new Color(
            showChannelR ? c.r : 0,
            showChannelG ? c.g : 0,
            showChannelB ? c.b : 0,
            showChannelA ? c.a : 1
        );
    }
    
    void DrawGrid(Rect rect, int gridWidth, int gridHeight)
    {
        Handles.BeginGUI();
        Handles.color = new Color(1, 1, 1, 0.2f);
        
        // 垂直线
        for (int x = 0; x <= gridWidth; x += 8)
        {
            float xPos = rect.x + (x / (float)gridWidth) * rect.width;
            Handles.DrawLine(new Vector3(xPos, rect.y), new Vector3(xPos, rect.yMax));
        }
        
        // 水平线
        for (int y = 0; y <= gridHeight; y += 8)
        {
            float yPos = rect.y + (y / (float)gridHeight) * rect.height;
            Handles.DrawLine(new Vector3(rect.x, yPos), new Vector3(rect.xMax, yPos));
        }
        
        Handles.EndGUI();
    }
    
    void DrawSmokeBounds(Rect rect)
    {
        Handles.BeginGUI();
        Handles.color = Color.yellow;
        
        int smokeStart = selectedSmoke * 34;
        int smokeEnd = smokeStart + 32;
        
        float startX = rect.x + (smokeStart / (float)texture3D.width) * rect.width;
        float endX = rect.x + (smokeEnd / (float)texture3D.width) * rect.width;
        
        // 绘制边界框
        Handles.DrawLine(new Vector3(startX, rect.y), new Vector3(startX, rect.yMax));
        Handles.DrawLine(new Vector3(endX, rect.y), new Vector3(endX, rect.yMax));
        
        Handles.EndGUI();
    }
    
    void DrawSliceInfo(Rect rect, int axis)
    {
        string axisName = axis == 0 ? "X" : (axis == 1 ? "Y" : "Z");
        int sliceIndex = axis == 0 ? sliceX : (axis == 1 ? sliceY : sliceZ);
        
        GUIStyle style = new GUIStyle(GUI.skin.label);
        style.normal.textColor = Color.white;
        style.fontSize = 12;
        
        GUI.Label(new Rect(rect.x + 10, rect.y + 10, 200, 20), 
            $"{axisName} Slice: {sliceIndex}", style);
    }
    
    void DrawAllSlicesPreview(Rect rect)
    {
        // 绘制所有Z切片的缩略图网格
        int cols = Mathf.CeilToInt(Mathf.Sqrt(texture3D.depth));
        int rows = Mathf.CeilToInt((float)texture3D.depth / cols);
        
        float thumbWidth = rect.width / cols;
        float thumbHeight = rect.height / rows;
        
        for (int z = 0; z < texture3D.depth; z++)
        {
            int col = z % cols;
            int row = z / cols;
            
            Rect thumbRect = new Rect(
                rect.x + col * thumbWidth,
                rect.y + row * thumbHeight,
                thumbWidth - 2,
                thumbHeight - 2
            );
            
            // 临时切换到这个slice
            int oldSlice = sliceZ;
            sliceZ = z;
            
            Texture2D thumb = Extract2DSlice(2);
            if (thumb != null)
            {
                GUI.DrawTexture(thumbRect, thumb);
                
                // 标签
                GUIStyle style = new GUIStyle(GUI.skin.label);
                style.normal.textColor = Color.white;
                style.fontSize = 10;
                GUI.Label(new Rect(thumbRect.x + 2, thumbRect.y + 2, 30, 15), $"Z{z}", style);
                
                DestroyImmediate(thumb);
            }
            
            sliceZ = oldSlice;
        }
    }
    
    void DrawVolumePreview(Rect rect)
    {
        EditorGUI.HelpBox(rect, "Volume rendering preview (basic visualization)\nUse Unity's built-in Inspector Volume mode for advanced preview", MessageType.Info);
    }
    
    void JumpToSmokeCenter()
    {
        if (texture3D != null && texture3D.width == 542)
        {
            sliceX = selectedSmoke * 34 + 16; // 中心
        }
    }
    
    void CalculateStatistics()
    {
        if (texture3D == null) return;
        
        int totalPixels = texture3D.width * texture3D.height * texture3D.depth;
        int nonZeroPixels = 0;
        float avgR = 0, avgG = 0, avgB = 0, avgA = 0;
        float maxR = 0, maxG = 0, maxB = 0, maxA = 0;
        
        for (int z = 0; z < texture3D.depth; z++)
        {
            for (int y = 0; y < texture3D.height; y++)
            {
                for (int x = 0; x < texture3D.width; x++)
                {
                    Color c = texture3D.GetPixel(x, y, z);
                    
                    if (c.r > 0 || c.g > 0 || c.b > 0 || c.a > 0)
                    {
                        nonZeroPixels++;
                        avgR += c.r;
                        avgG += c.g;
                        avgB += c.b;
                        avgA += c.a;
                        
                        maxR = Mathf.Max(maxR, c.r);
                        maxG = Mathf.Max(maxG, c.g);
                        maxB = Mathf.Max(maxB, c.b);
                        maxA = Mathf.Max(maxA, c.a);
                    }
                }
            }
        }
        
        if (nonZeroPixels > 0)
        {
            avgR /= nonZeroPixels;
            avgG /= nonZeroPixels;
            avgB /= nonZeroPixels;
            avgA /= nonZeroPixels;
        }
        
        float fillRate = (nonZeroPixels / (float)totalPixels) * 100f;
        
        statsText = $"Total Pixels: {totalPixels:N0}\n" +
                    $"Non-Zero: {nonZeroPixels:N0} ({fillRate:F2}%)\n" +
                    $"Avg RGBA: ({avgR:F3}, {avgG:F3}, {avgB:F3}, {avgA:F3})\n" +
                    $"Max RGBA: ({maxR:F3}, {maxG:F3}, {maxB:F3}, {maxA:F3})";
    }
    
    void ExportCurrentSlice()
    {
        if (texture3D == null) return;
        
        string path = EditorUtility.SaveFilePanel(
            "Export Slice as PNG",
            "Assets",
            $"Slice_{currentMode}_{sliceZ}.png",
            "png"
        );
        
        if (!string.IsNullOrEmpty(path))
        {
            Texture2D slice = Extract2DSlice(currentMode == ViewMode.SliceX ? 0 : (currentMode == ViewMode.SliceY ? 1 : 2));
            byte[] bytes = slice.EncodeToPNG();
            System.IO.File.WriteAllBytes(path, bytes);
            DestroyImmediate(slice);
            
            Debug.Log($"Slice exported to {path}");
        }
    }
}
#endif