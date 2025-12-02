using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SmokeRaymarchingPass : ScriptableRenderPass
{
    private int m_DownSample = 2;
    
    private Material compositeMat;
    private Material smokeRaymarchingPassMaterial;

    private RTHandle rt0_OpticalDepth;
    private RTHandle rt1_Moments;
    private RTHandle rt2_HigherMoments;
    private RTHandle rt3_SmokeColor;
    private RTHandle rt4_DepthRange;
    
    private RTHandle[] mrtArray = new RTHandle[5];
    private RenderTargetIdentifier[] mrtIDs = new RenderTargetIdentifier[5];

    
    private float[] m_smokeParams = new float[10];
    
    private const string profilerTag = "RaymarchingMask";
    
    public SmokeRaymarchingPass(SmokeGrenadeRendererFeature.Settings settings)
    {
        this.compositeMat = settings.compositeMat;
        
        this.smokeRaymarchingPassMaterial = settings.smokeRaymarchingPassMaterial;
        this.renderPassEvent = settings.smokeRaymarchingPassEvent;
        
        this.m_DownSample = settings.downSample;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.width /= m_DownSample;
        descriptor.height /= m_DownSample;
        descriptor.depthBufferBits = 0;
        descriptor.msaaSamples = 1;
        
        var desc0 = descriptor;
        desc0.colorFormat = RenderTextureFormat.ARGB32;
        RenderingUtils.ReAllocateIfNeeded(ref rt0_OpticalDepth, desc0, name: "_OpticalDepth");

        var desc1 = descriptor;
        desc1.colorFormat = RenderTextureFormat.RGFloat;
        RenderingUtils.ReAllocateIfNeeded(ref rt1_Moments, desc1, name: "_Moments");

        var desc2 = descriptor;
        desc2.colorFormat = RenderTextureFormat.ARGBHalf;
        RenderingUtils.ReAllocateIfNeeded(ref rt2_HigherMoments, desc2, name: "_HigherMoments");

        var desc3 = descriptor;
        desc3.colorFormat = RenderTextureFormat.ARGBHalf;
        RenderingUtils.ReAllocateIfNeeded(ref rt3_SmokeColor, desc3, name: "_SmokeColor");

        var desc4 = descriptor;
        desc4.colorFormat = RenderTextureFormat.RGFloat;
        RenderingUtils.ReAllocateIfNeeded(ref rt4_DepthRange, desc4, name: "_DepthRange");

        mrtArray[0] = rt0_OpticalDepth;
        mrtArray[1] = rt1_Moments;
        mrtArray[2] = rt2_HigherMoments;
        mrtArray[3] = rt3_SmokeColor;
        mrtArray[4] = rt4_DepthRange;
        
        mrtIDs[0] = rt0_OpticalDepth;
        mrtIDs[1] = rt1_Moments;
        mrtIDs[2] = rt2_HigherMoments;
        mrtIDs[3] = rt3_SmokeColor;
        mrtIDs[4] = rt4_DepthRange;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get(profilerTag);

        using (new ProfilingScope(cmd, new ProfilingSampler(profilerTag)))
        {
            // if (smokeRaymarchingPassMaterial == null)
            // {
            //     Debug.LogWarning("[SmokeMaskPass] Material or target is null!");
            //     return;
            // }
            
            CoreUtils.SetRenderTarget(
                cmd,
                mrtIDs,
                rt0_OpticalDepth,
                ClearFlag.Color,
                Color.clear
            );
            
            if (SmokeHoleManager.HoleBuffer != null)
            {
                cmd.SetGlobalBuffer("_BulletHoleBuffer", SmokeHoleManager.HoleBuffer);
                cmd.SetGlobalInt("_BulletHoleCount", SmokeHoleManager.ActiveCount);
            }
            else
            {
                cmd.SetGlobalInt("_BulletHoleCount", 0);
            }
            
            cmd.DrawProcedural(Matrix4x4.identity, smokeRaymarchingPassMaterial, 0, MeshTopology.Triangles, 3,1);

            cmd.SetGlobalTexture("_OpticalDepth", rt0_OpticalDepth);
            cmd.SetGlobalTexture("_Moments", rt1_Moments);
            cmd.SetGlobalTexture("_HigherMoments", rt2_HigherMoments);
            cmd.SetGlobalTexture("_SmokeColor", rt3_SmokeColor);
            cmd.SetGlobalTexture("_DepthRange", rt4_DepthRange);
            
#if false
            RTHandle cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
            Blitter.BlitCameraTexture(cmd, rt3_SmokeColor, cameraTarget);
#endif
            
#if true
            RTHandle cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
            Blitter.BlitCameraTexture(cmd, rt3_SmokeColor, cameraTarget, this.compositeMat, 0);
#endif 
        }
        
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
    
    public override void OnCameraCleanup(CommandBuffer cmd)
    {

    }
    
    public void Dispose()
    {
        rt0_OpticalDepth?.Release();
        rt1_Moments?.Release();
        rt2_HigherMoments?.Release();
        rt3_SmokeColor?.Release();
        rt4_DepthRange?.Release();
    }
}
