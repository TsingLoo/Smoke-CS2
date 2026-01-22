using UnityEngine;
using UnityEditor;
using System.IO;
using System;

public class DDSToTexture3DConverter : EditorWindow
{
    [MenuItem("Tools/DDS to Texture3D Converter (Axis Swap)")]
    public static void ShowWindow()
    {
        GetWindow<DDSToTexture3DConverter>("DDS Converter");
    }

    string filePath = "";
    bool swapYZ = true;

    void OnGUI()
    {
        GUILayout.Label("RenderDoc DDS 3D材质转换器", EditorStyles.boldLabel);
        
        if (GUILayout.Button("选择 .dds 文件"))
        {
            filePath = EditorUtility.OpenFilePanel("选择 DDS 文件", "", "dds");
        }

        EditorGUILayout.LabelField("当前路径: ", filePath);
        swapYZ = EditorGUILayout.Toggle("交换 Y 和 Z 轴 (Z-up to Y-up)", swapYZ);

        if (GUILayout.Button("开始转换并保存") && !string.IsNullOrEmpty(filePath))
        {
            ConvertDDS(filePath);
        }
    }

    void ConvertDDS(string path)
    {
        byte[] bytes = File.ReadAllBytes(path);

        // 解析 DDS 基础信息
        int origHeight = BitConverter.ToInt32(bytes, 12);
        int origWidth = BitConverter.ToInt32(bytes, 16);
        int origDepth = Mathf.Max(1, BitConverter.ToInt32(bytes, 24));
        int fourCC = BitConverter.ToInt32(bytes, 84);

        int headerSize = (fourCC == 0x30315844) ? 148 : 128; // 处理 DX10 扩展头部
        
        // 假设格式为 RGBA32 (每个像素 4 字节)
        // 注意：如果是其他格式，这里的 pixelSize 需要修改
        int pixelSize = 4; 
        TextureFormat format = TextureFormat.RGBA32;

        int newWidth = origWidth;
        int newHeight = swapYZ ? origDepth : origHeight;
        int newDepth = swapYZ ? origHeight : origDepth;

        Texture3D tex3d = new Texture3D(newWidth, newHeight, newDepth, format, false);
        byte[] srcData = new byte[bytes.Length - headerSize];
        Array.Copy(bytes, headerSize, srcData, 0, srcData.Length);

        if (swapYZ)
        {
            Debug.Log($"执行轴转换: 原({origWidth}x{origHeight}x{origDepth}) -> 新({newWidth}x{newHeight}x{newDepth})");
            byte[] dstData = new byte[srcData.Length];

            // 核心逻辑：三维像素重排
            for (int z = 0; z < origDepth; z++)
            {
                for (int y = 0; y < origHeight; y++)
                {
                    // 将原 z 映射到新 y，原 y 映射到新 z
                    int srcSliceOffset = z * (origWidth * origHeight * pixelSize);
                    int srcRowOffset = y * (origWidth * pixelSize);
                    
                    int dstY = z; // 原 Z 变新 Y
                    int dstZ = y; // 原 Y 变新 Z
                    
                    int dstSliceOffset = dstZ * (newWidth * newHeight * pixelSize);
                    int dstRowOffset = dstY * (newWidth * pixelSize);

                    Array.Copy(srcData, srcSliceOffset + srcRowOffset, 
                               dstData, dstSliceOffset + dstRowOffset, 
                               origWidth * pixelSize);
                }
            }
            tex3d.SetPixelData(dstData, 0);
        }
        else
        {
            tex3d.SetPixelData(srcData, 0);
        }

        tex3d.Apply();

        string fileName = Path.GetFileNameWithoutExtension(path);
        string savePath = "Assets/" + fileName + "_3D_Converted.asset";
        AssetDatabase.CreateAsset(tex3d, savePath);
        AssetDatabase.SaveAssets();

        EditorUtility.DisplayDialog("成功", $"已完成坐标转换并保存: {savePath}", "确定");
    }
}