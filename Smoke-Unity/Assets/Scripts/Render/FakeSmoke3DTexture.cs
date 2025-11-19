using System.Globalization;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class SmokeGrenadeTexture3D : MonoBehaviour
{
    [Header("Source Data")]
    public TextAsset smokeDataCSV; // 支持逗号或Tab分隔
    
    [Header("Generated Texture")]
    public Texture3D smokeTexture;
    
    [Header("Settings")]
    public int startSlice = 15;
    public string savePath = "Assets/Textures/CS2_SmokeGrenade_542x32x32.asset";
    
    [Header("Debug Info")]
    [SerializeField] private string detectedFormat = "";
    [SerializeField] private int totalLinesProcessed = 0;
    
#if UNITY_EDITOR
    [ContextMenu("Generate and Save Texture")]
    void GenerateAndSaveTexture()
    {
        if (smokeDataCSV == null)
        {
            Debug.LogError("Please assign smokeDataCSV first!");
            return;
        }
        
        Debug.Log("Starting texture generation...");
        
        Texture3D newTexture = CreateSmokeTexture3D();
        
        string directory = System.IO.Path.GetDirectoryName(savePath);
        if (!System.IO.Directory.Exists(directory))
        {
            System.IO.Directory.CreateDirectory(directory);
        }
        
        Texture3D existingTexture = AssetDatabase.LoadAssetAtPath<Texture3D>(savePath);
        if (existingTexture != null)
        {
            Debug.Log("Updating existing texture asset...");
            AssetDatabase.DeleteAsset(savePath);
        }
        
        AssetDatabase.CreateAsset(newTexture, savePath);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        
        smokeTexture = AssetDatabase.LoadAssetAtPath<Texture3D>(savePath);
        
        Debug.Log($"=== Texture Saved Successfully ===");
        Debug.Log($"Path: {savePath}");
        Debug.Log($"Dimensions: {newTexture.width}x{newTexture.height}x{newTexture.depth}");
        Debug.Log($"Format: {newTexture.format}");
        Debug.Log($"Size: {(newTexture.width * newTexture.height * newTexture.depth * 4) / 1024f:F1} KB");
        Debug.Log($"Detected Format: {detectedFormat}");
        Debug.Log($"Lines Processed: {totalLinesProcessed:N0}");
        
        EditorGUIUtility.PingObject(smokeTexture);
        Selection.activeObject = smokeTexture;
    }
    
    [ContextMenu("Analyze CSV Format")]
    void AnalyzeCSVFormat()
    {
        if (smokeDataCSV == null)
        {
            Debug.LogError("Please assign smokeDataCSV first!");
            return;
        }
        
        string[] lines = smokeDataCSV.text.Split(new[] { '\n', '\r' }, System.StringSplitOptions.RemoveEmptyEntries);
        
        if (lines.Length == 0)
        {
            Debug.LogError("CSV is empty!");
            return;
        }
        
        // 分析前10行
        Debug.Log("=== CSV Format Analysis ===");
        Debug.Log($"Total lines: {lines.Length:N0}");
        
        char delimiter = DetectDelimiter(lines[0]);
        Debug.Log($"Detected delimiter: '{delimiter}' ({(delimiter == '\t' ? "TAB" : "COMMA")})");
        
        Debug.Log("\nFirst 5 lines sample:");
        for (int i = 0; i < Mathf.Min(5, lines.Length); i++)
        {
            string[] values = lines[i].Split(delimiter);
            Debug.Log($"Line {i}: {values.Length} columns - [{string.Join(", ", values)}]");
        }
        
        // 检测预期的slice数量
        int pixelsPerSlice = 542 * 32;
        int expectedSlices = lines.Length / pixelsPerSlice;
        Debug.Log($"\nExpected slices: {expectedSlices} (at {pixelsPerSlice} pixels/slice)");
        Debug.Log($"Will cover Z slices: {startSlice} to {startSlice + expectedSlices - 1}");
    }
#endif
    
    Texture3D CreateSmokeTexture3D()
    {
        int width = 542;
        int height = 32;
        int depth = 32;
        
        Texture3D texture = new Texture3D(width, height, depth, TextureFormat.RGBA32, false);
        Color32[] colors = new Color32[width * height * depth];
        
        for (int i = 0; i < colors.Length; i++)
        {
            colors[i] = new Color32(0, 0, 0, 0);
        }
        
        if (smokeDataCSV != null)
        {
            ParseCSVData(smokeDataCSV.text, colors, width, height, depth, startSlice);
        }
        else
        {
            Debug.LogError("smokeDataCSV is null!");
        }
        
        texture.SetPixels32(colors);
        texture.Apply();
        
        texture.wrapMode = TextureWrapMode.Clamp;
        texture.filterMode = FilterMode.Bilinear;
        texture.anisoLevel = 0;
        
        return texture;
    }
    
    void ParseCSVData(string csvData, Color32[] colors, int width, int height, int depth, int startZ)
    {
        string[] lines = csvData.Split(new[] { '\n', '\r' }, System.StringSplitOptions.RemoveEmptyEntries);
        
        if (lines.Length == 0)
        {
            Debug.LogError("CSV file is empty!");
            return;
        }
        
        // 自动检测分隔符
        char delimiter = DetectDelimiter(lines[0]);
        detectedFormat = delimiter == '\t' ? "Tab-separated" : "Comma-separated";
        Debug.Log($"Detected format: {detectedFormat}");
        
        int pixelsPerSlice = width * height;
        int expectedLines = lines.Length;
        int numSlices = expectedLines / pixelsPerSlice;
        
        Debug.Log($"CSV has {expectedLines:N0} lines");
        Debug.Log($"Pixels per slice: {pixelsPerSlice:N0}");
        Debug.Log($"Number of slices in CSV: {numSlices}");
        Debug.Log($"Will fill slices {startZ} to {startZ + numSlices - 1}");
        
        int lineIndex = 0;
        int skippedLines = 0;
        
        foreach (string line in lines)
        {
            string trimmed = line.Trim();
            if (string.IsNullOrEmpty(trimmed)) continue;
            
            string[] values = trimmed.Split(delimiter);
            
            if (values.Length >= 4)
            {
                byte r = FloatToByte(ParseFloat(values[0]));
                byte g = FloatToByte(ParseFloat(values[1]));
                byte b = FloatToByte(ParseFloat(values[2]));
                byte a = FloatToByte(ParseFloat(values[3]));
                
                int localZ = lineIndex / pixelsPerSlice;
                int remainder = lineIndex % pixelsPerSlice;
                int y = remainder / width;
                int x = remainder % width;
                
                int actualZ = startZ + localZ;
                
                if (actualZ < depth)
                {
                    int index = x + width * (y + height * actualZ);
                    colors[index] = new Color32(r, g, b, a);
                }
                
                lineIndex++;
            }
            else
            {
                skippedLines++;
                if (skippedLines <= 5)
                {
                    Debug.LogWarning($"Line {lineIndex}: Invalid format, expected 4 values, got {values.Length}");
                }
            }
        }
        
        totalLinesProcessed = lineIndex;
        
        if (skippedLines > 0)
        {
            Debug.LogWarning($"Skipped {skippedLines} invalid lines");
        }
        
        Debug.Log($"Processed {lineIndex:N0} valid lines");
        CheckSliceData(colors, width, height, depth);
    }
    
    char DetectDelimiter(string sampleLine)
    {
        int commaCount = sampleLine.Split(',').Length - 1;
        int tabCount = sampleLine.Split('\t').Length - 1;
        
        Debug.Log($"Delimiter detection - Commas: {commaCount}, Tabs: {tabCount}");
        
        if (tabCount >= commaCount && tabCount >= 3)
        {
            return '\t';
        }
        else if (commaCount >= 3)
        {
            return ',';
        }
        else
        {
            Debug.LogWarning("Could not reliably detect delimiter, defaulting to comma");
            return ',';
        }
    }
    
    void CheckSliceData(Color32[] colors, int width, int height, int depth)
    {
        Debug.Log("=== Slice Data Summary ===");
        
        for (int z = 0; z < depth; z++)
        {
            int nonZeroCount = 0;
            int totalAlpha = 0;
            
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int index = x + width * (y + height * z);
                    Color32 c = colors[index];
                    
                    if (c.r > 0 || c.g > 0 || c.b > 0 || c.a > 0)
                    {
                        nonZeroCount++;
                        totalAlpha += c.a;
                    }
                }
            }
            
            if (nonZeroCount > 0)
            {
                float avgAlpha = totalAlpha / (float)nonZeroCount;
                Debug.Log($"Slice {z}: {nonZeroCount:N0} pixels with data (avg alpha: {avgAlpha:F1})");
            }
        }
    }
    
    float ParseFloat(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return 0f;
        }
        
        value = value.Trim();
        
        if (value == "" || value == ".")
        {
            return 0f;
        }
        
        float result;
        if (float.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out result))
        {
            return result;
        }
        
        if (float.TryParse(value, NumberStyles.Float, CultureInfo.CurrentCulture, out result))
        {
            return result;
        }
        
        return 0f;
    }
    
    byte FloatToByte(float value)
    {
        return (byte)Mathf.Clamp(value * 255f, 0f, 255f);
    }
}