using UnityEngine;
using UnityEditor;
using System.IO;
using System;
using UnityEngine.Experimental.Rendering;

public class DDSToTexture3DConverter : EditorWindow
{
    [MenuItem("Tools/DDS to Texture3D (YZ Swap)")]
    public static void ShowWindow() => GetWindow<DDSToTexture3DConverter>("DDS Converter");

    string filePath = "";
    // 默认开启 YZ 交换按钮
    bool swapYZ = true;

    void OnGUI()
    {
        GUILayout.Label("RenderDoc DDS 3D 材质转换器", EditorStyles.boldLabel);
        
        if (GUILayout.Button("选择 .dds 文件"))
            filePath = EditorUtility.OpenFilePanel("选择 DDS 文件", "", "dds");

        EditorGUILayout.LabelField("当前路径: ", filePath);
        
        EditorGUILayout.Space();
        // 功能开关按钮
        swapYZ = EditorGUILayout.Toggle("交换 Y 和 Z 轴 (x,y,z -> x,z,y)", swapYZ);
        
        EditorGUILayout.HelpBox("提示：\n1. 已强制开启 Linear 空间以匹配物理数值。\n2. 默认执行 Y/Z 交换以适配 Unity 坐标系。", MessageType.Info);

        if (GUILayout.Button("开始转换并保存") && !string.IsNullOrEmpty(filePath))
            ConvertDDS(filePath);
    }

    void ConvertDDS(string path)
    {
        byte[] bytes = File.ReadAllBytes(path);

        // 解析原始尺寸
        int h_old = BitConverter.ToInt32(bytes, 12);
        int w_old = BitConverter.ToInt32(bytes, 16);
        int d_old = Mathf.Max(1, BitConverter.ToInt32(bytes, 24));
        int fourCC = BitConverter.ToInt32(bytes, 84);

        int headerSize = (fourCC == 0x30315844) ? 148 : 128; 
        int pixelSize = 4; // 针对 RGBA32

        // 计算目标维度
        int w_new = w_old;
        int h_new = swapYZ ? d_old : h_old;
        int d_new = swapYZ ? h_old : d_old;

        // 【关键】使用 linear: true 确保数据精度，不再产生 sRGB 转换导致的数值缩小
        Texture3D tex3d = new Texture3D(
            w_new, 
            h_new, 
            d_new, 
            GraphicsFormat.R8G8B8A8_UNorm,
            TextureCreationFlags.None
        );
        
        byte[] srcData = new byte[bytes.Length - headerSize];
        Array.Copy(bytes, headerSize, srcData, 0, srcData.Length);
        byte[] dstData = new byte[srcData.Length];

        // 核心重排逻辑
        for (int z = 0; z < d_old; z++)
        {
            for (int y = 0; y < h_old; y++)
            {
                int srcSliceOffset = z * (w_old * h_old * pixelSize);
                int srcRowOffset = y * (w_old * pixelSize);
                
                // 根据开关决定坐标映射
                int dstY = swapYZ ? z : y;
                int dstZ = swapYZ ? y : z;
                
                int dstSliceOffset = dstZ * (w_new * h_new * pixelSize);
                int dstRowOffset = dstY * (w_new * pixelSize);

                Array.Copy(srcData, srcSliceOffset + srcRowOffset, 
                           dstData, dstSliceOffset + dstRowOffset, 
                           w_old * pixelSize);
            }
        }

        tex3d.SetPixelData(dstData, 0);
        tex3d.Apply();

        string suffix = swapYZ ? "_YZSwap" : "_Direct";
        string savePath = "Assets/" + Path.GetFileNameWithoutExtension(path) + suffix + ".asset";
        
        AssetDatabase.CreateAsset(tex3d, savePath);
        AssetDatabase.SaveAssets();

        EditorUtility.DisplayDialog("成功", $"转换完成并保存至: {savePath}\n数据空间: Linear", "确定");
    }
}