using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SmokeMaskFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public Material smokeMaskMaterial;
        public RenderTexture targetRenderTexture;
        
        [Header("Camera Filtering")]
        public bool gameViewOnly = true;
    }
    
    public Settings settings = new Settings();
    private SmokeMaskPass smokeMaskPass;
    
    public override void Create()
    {
        smokeMaskPass = new SmokeMaskPass(settings);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.smokeMaskMaterial == null)
        {
            Debug.LogWarning("[SmokeMaskFeature] No material assigned!");
            return;
        }
        
        var cameraType = renderingData.cameraData.cameraType;
        if (settings.gameViewOnly && cameraType == CameraType.SceneView)
        {
            return;
        }
        
        if (cameraType != CameraType.Game && cameraType != CameraType.Reflection)
        {
            return;
        }
        
        smokeMaskPass.Setup(settings.targetRenderTexture);
        renderer.EnqueuePass(smokeMaskPass);
    }
    
    class SmokeMaskPass : ScriptableRenderPass
    {
        private Material material;
        private RenderTexture userTargetTexture;
        private RTHandle targetHandle;
        private const string profilerTag = "SmokeMask";
        
        public SmokeMaskPass(Settings settings)
        {
            material = settings.smokeMaskMaterial;
            renderPassEvent = settings.renderPassEvent;
        }
        
        public void Setup(RenderTexture target)
        {
            this.userTargetTexture = target;
        }
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            if (userTargetTexture != null)
            {
                // 使用用户指定的RT
                targetHandle = RTHandles.Alloc(userTargetTexture);
            }
            else
            {
                // 如果没有指定，创建临时RT
                var descriptor = renderingData.cameraData.cameraTargetDescriptor;
                descriptor.colorFormat = RenderTextureFormat.RFloat;
                descriptor.depthBufferBits = 0;
                descriptor.msaaSamples = 1;
                
                RenderingUtils.ReAllocateIfNeeded(ref targetHandle, descriptor, name: "_SmokeMaskRT");
            }
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null || targetHandle == null)
            {
                Debug.LogWarning("[SmokeMaskPass] Material or target is null!");
                return;
            }
            
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            
            using (new ProfilingScope(cmd, new ProfilingSampler(profilerTag)))
            {
                // 设置渲染目标
                CoreUtils.SetRenderTarget(cmd, targetHandle, ClearFlag.Color, Color.clear);
                
                // ⭐ 绘制全屏三角形（3个顶点）
                cmd.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, 3, 1);
                
                // 设置全局纹理
                cmd.SetGlobalTexture("_SmokeMask", targetHandle);
            }
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (userTargetTexture == null && targetHandle != null)
            {
                // 只释放自动创建的RT
                targetHandle?.Release();
            }
            targetHandle = null;
        }
    }
}