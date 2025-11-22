using System.Globalization;
using UnityEngine;
using System.IO;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class Texture3DGenerator128 : MonoBehaviour
{
    [Header("Source Data")]
    [Tooltip("拖入你的 .txt 或 .csv 文件")]
    public TextAsset sourceDataFile; 

    [Header("Settings")]
    // 你的数据规格
    public int size = 128; 
    public string saveFilename = "GeneratedTexture128.asset";

    [Header("Preview")]
    public Texture3D generatedTexture;

#if UNITY_EDITOR
    
    [ContextMenu("Generate Texture 3D")]
    public void GenerateTexture()
    {
        if (sourceDataFile == null)
        {
            Debug.LogError("请先赋值 Source Data File!");
            return;
        }

        // 1. 准备基本参数
        int width = size;
        int height = size;
        int depth = size;
        int totalPixels = width * height * depth; // 2,097,152
        int pixelsPerSlice = width * height;      // 16,384

        Debug.Log($"开始生成... 目标尺寸: {width}x{height}x{depth}, 总像素: {totalPixels:N0}");

        // 2. 创建 Texture3D 容器
        Texture3D texture = new Texture3D(width, height, depth, TextureFormat.RGBA32, false);
        texture.wrapMode = TextureWrapMode.Clamp;
        texture.filterMode = FilterMode.Bilinear;

        // 3. 准备颜色数组 (初始全黑)
        Color32[] colors = new Color32[totalPixels];
        for (int i = 0; i < colors.Length; i++) colors[i] = new Color32(0, 0, 0, 0);

        // 4. 读取并解析文本
        // 注意：Split 大文件会消耗内存，但对于 200万行在 Editor 下通常是安全的
        string[] lines = sourceDataFile.text.Split(new[] { '\n', '\r' }, System.StringSplitOptions.RemoveEmptyEntries);

        Debug.Log($"文件行数: {lines.Length:N0}");

        if (lines.Length != totalPixels)
        {
            Debug.LogWarning($"警告: 文件行数 ({lines.Length}) 与 目标像素数 ({totalPixels}) 不匹配。可能会导致部分像素未填充或截断。");
        }

        try
        {
            int parsedCount = 0;
            int loopMax = Mathf.Min(lines.Length, totalPixels);

            // 开始循环解析
            for (int i = 0; i < loopMax; i++)
            {
                // 显示进度条 (每处理 10000 行更新一次，避免拖慢速度)
                if (i % 10000 == 0)
                {
                    float progress = (float)i / loopMax;
                    EditorUtility.DisplayProgressBar("Generating Texture3D", $"Parsing line {i}/{loopMax}...", progress);
                }

                string line = lines[i];
                
                // 简单的逗号分隔解析
                // 假设格式严格为: R,G,B,A (例如 0.1294,0.1412,0.4039,0.1529)
                string[] values = line.Split(',');

                if (values.Length >= 4)
                {
                    // 解析 Float (0.0 - 1.0) 并转为 Byte (0 - 255)
                    byte r = FloatToByte(ParseFloat(values[0]));
                    byte g = FloatToByte(ParseFloat(values[1]));
                    byte b = FloatToByte(ParseFloat(values[2]));
                    byte a = FloatToByte(ParseFloat(values[3]));

                    // 计算 3D 坐标
                    // 数据顺序通常是: 先填满一行 X，再换行 Y，填满一个面后换 Z
                    // i = x + width * (y + height * z)
                    // 所以反推：
                    int z = i / pixelsPerSlice;          // 第几层 (0-127)
                    int remainderSlice = i % pixelsPerSlice;
                    int y = remainderSlice / width;      // 层内的第几行 (0-127)
                    int x = remainderSlice % width;      // 行内的第几列 (0-127)

                    // 计算 Unity Texture3D 的一维数组索引
                    int textureIndex = x + width * (y + height * z);
                    
                    colors[textureIndex] = new Color32(r, g, b, a);
                    parsedCount++;
                }
            }
            
            Debug.Log($"解析完成。有效像素: {parsedCount:N0}");

            // 5. 应用像素数据
            texture.SetPixels32(colors);
            texture.Apply();

            // 6. 保存文件
            SaveAsset(texture);
        }
        catch (System.Exception e)
        {
            Debug.LogError("发生错误: " + e.Message);
        }
        finally
        {
            EditorUtility.ClearProgressBar();
        }
    }

    void SaveAsset(Texture3D tex)
    {
        string path = "Assets/" + saveFilename;
        
        // 检查是否存在，存在则覆盖
        Texture3D existing = AssetDatabase.LoadAssetAtPath<Texture3D>(path);
        if (existing != null)
        {
            AssetDatabase.DeleteAsset(path);
        }

        AssetDatabase.CreateAsset(tex, path);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        generatedTexture = AssetDatabase.LoadAssetAtPath<Texture3D>(path);
        
        // 选中生成的文件
        EditorGUIUtility.PingObject(generatedTexture);
        Selection.activeObject = generatedTexture;
        
        Debug.Log($"保存成功: {path}");
    }

    // --- 辅助函数 ---

    float ParseFloat(string val)
    {
        // 使用 InvariantCulture 确保 "." 被识别为小数点，而不是千位符
        if (float.TryParse(val, NumberStyles.Float, CultureInfo.InvariantCulture, out float result))
        {
            return result;
        }
        return 0f;
    }

    byte FloatToByte(float val)
    {
        // 将 0.0-1.0 映射到 0-255
        return (byte)Mathf.Clamp(val * 255f, 0f, 255f);
    }
#endif
}