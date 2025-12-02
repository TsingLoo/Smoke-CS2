using UnityEngine;

public class CloudTexture3DGenerator : MonoBehaviour
{
    [Header("Compute Shader")]
    public ComputeShader cloudShader;
    
    [Header("Texture Settings")]
    [Range(32, 256)]
    public int resolution = 128;
    
    [Header("Cloud Parameters")]
    [Range(0.5f, 8f)]
    public float frequency = 2f;
    
    [Range(1, 8)]
    public int octaves = 4;
    
    [Range(1.5f, 4f)]
    public float lacunarity = 2f;
    
    [Range(0.3f, 0.8f)]
    public float persistence = 0.5f;
    
    public Vector3 offset = Vector3.zero;
    
    [Header("Cloud Appearance")]
    [Range(0f, 1f)]
    [Tooltip("云覆盖度 - 越高云越多")]
    public float cloudCoverage = 0.5f;
    
    [Range(0.5f, 8f)]
    [Tooltip("云边缘锐度 - 越高边缘越清晰")]
    public float cloudSharpness = 3f;
    
    [Range(0f, 1f)]
    [Tooltip("细节强度 - 添加小尺度扰动")]
    public float detailStrength = 0.3f;
    
    [Header("Channel Selection")]
    public bool writeToRed = true;
    public bool writeToGreen = true;
    public bool writeToBlue = true;
    public bool writeToAlpha = false;
    
    [Header("Output")]
    public RenderTexture cloudTexture3D;
    public Material previewMaterial; // 用于预览的材质
    
    private int kernelMain;
    private int kernelClear;
    
    void Start()
    {
        InitializeTexture();
        GenerateCloudTexture();
    }
    
    void InitializeTexture()
    {
        if (cloudTexture3D != null)
            cloudTexture3D.Release();
        
        cloudTexture3D = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGBFloat)
        {
            dimension = UnityEngine.Rendering.TextureDimension.Tex3D,
            volumeDepth = resolution,
            enableRandomWrite = true,
            wrapMode = TextureWrapMode.Repeat,
            filterMode = FilterMode.Trilinear
        };
        cloudTexture3D.Create();
        
        // 将纹理传递给预览材质
        if (previewMaterial != null)
            previewMaterial.SetTexture("_Volume", cloudTexture3D);
    }
    
    [ContextMenu("Generate Cloud Texture")]
    public void GenerateCloudTexture()
    {
        if (cloudShader == null)
        {
            Debug.LogError("Cloud Shader is not assigned!");
            return;
        }
        
        if (cloudTexture3D == null)
            InitializeTexture();
        
        // 查找 kernel
        kernelMain = cloudShader.FindKernel("CSMain");
        kernelClear = cloudShader.FindKernel("CSClear");
        
        // 清空纹理
        cloudShader.SetTexture(kernelClear, "Result", cloudTexture3D);
        int threadGroups = Mathf.CeilToInt(resolution / 8f);
        cloudShader.Dispatch(kernelClear, threadGroups, threadGroups, threadGroups);
        
        // 设置参数
        cloudShader.SetTexture(kernelMain, "Result", cloudTexture3D);
        cloudShader.SetInt("resolution", resolution);
        cloudShader.SetFloat("frequency", frequency);
        cloudShader.SetInt("octaves", octaves);
        cloudShader.SetFloat("lacunarity", lacunarity);
        cloudShader.SetFloat("persistence", persistence);
        cloudShader.SetVector("offset", offset);
        
        // 新增参数
        cloudShader.SetFloat("cloudCoverage", cloudCoverage);
        cloudShader.SetFloat("cloudSharpness", cloudSharpness);
        cloudShader.SetFloat("detailStrength", detailStrength);
        
        // 通道掩码
        Vector4 channelMask = new Vector4(
            writeToRed ? 1f : 0f,
            writeToGreen ? 1f : 0f,
            writeToBlue ? 1f : 0f,
            writeToAlpha ? 1f : 0f
        );
        cloudShader.SetVector("channelMask", channelMask);
        
        // 执行计算
        cloudShader.Dispatch(kernelMain, threadGroups, threadGroups, threadGroups);
        
        Debug.Log("Cloud texture generated!");
    }
    
    // 实时更新(谨慎使用,性能开销大)
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space))
        {
            GenerateCloudTexture();
        }
    }
    
    void OnValidate()
    {
        // 在编辑器中修改参数时自动更新
        if (Application.isPlaying && cloudTexture3D != null)
        {
            GenerateCloudTexture();
        }
    }
    
    void OnDestroy()
    {
        if (cloudTexture3D != null)
            cloudTexture3D.Release();
    }
}