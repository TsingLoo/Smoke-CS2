using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SmokeRaymarchingPass : ScriptableRenderPass
{
    private int m_DownSample = 2;
    
    private Material smokeRaymarchingPassMaterial;

    private RTHandle rt0_OpticalDepth;
    private RTHandle rt1_Moments;
    private RTHandle rt2_HigherMoments;
    private RTHandle rt3_SmokeColor;
    private RTHandle rt4_DepthRange;
    
    private RTHandle[] mrtArray = new RTHandle[5];
    
    private const int IDX_NOISE_SCALE = 0;
    private const int IDX_NOISE_STRENGTH = 1;
    private const int IDX_DETAIL_NOISE_SCALE = 2;
    private const int IDX_ANISOTROPY = 3;
    private const int IDX_AMBIENT_STRENGTH = 4;
    private const int IDX_PHASE_STRENGTH = 5;
    private const int IDX_COLOR_BOOST = 6;
    private const int IDX_SATURATION = 7;
    private const int IDX_DENSITY_MULTIPLIER = 8;
    private const int IDX_NOISE_SPEED = 9;
    
    private float[] m_smokeParams = new float[10];
    
    private const string profilerTag = "RaymarchingMask";
    
    public SmokeRaymarchingPass(SmokeGrenadeRendererFeature.Settings settings)
    {
        this.smokeRaymarchingPassMaterial = settings.smokeRaymarchingPassMaterial;
        this.renderPassEvent = settings.smokeRaymarchingPassEvent;
        
        this.m_DownSample = settings.downSample;
        
        this.m_smokeParams[IDX_NOISE_SCALE] = settings.noiseScale;
        this.m_smokeParams[IDX_NOISE_STRENGTH] = settings.noiseStrength;
        this.m_smokeParams[IDX_DETAIL_NOISE_SCALE] = settings.detailNoiseScale;
        this.m_smokeParams[IDX_ANISOTROPY]    = settings.anisotropy;
        this.m_smokeParams[IDX_AMBIENT_STRENGTH] = settings.ambientStrength;
        this.m_smokeParams[IDX_PHASE_STRENGTH] = settings.phaseStrength;
        this.m_smokeParams[IDX_COLOR_BOOST] = settings.colorBoost;
        this.m_smokeParams[IDX_SATURATION] = settings.saturation;
        this.m_smokeParams[IDX_DENSITY_MULTIPLIER] = settings.densityMultiplier;
        this.m_smokeParams[IDX_NOISE_SPEED] = settings.noiseSpeed;
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
                mrtArray,
                rt0_OpticalDepth,
                ClearFlag.Color,
                Color.clear
            );
            
            cmd.DrawProcedural(Matrix4x4.identity, smokeRaymarchingPassMaterial, 0, MeshTopology.Triangles, 3,1);

            cmd.SetGlobalTexture("_OpticalDepth", rt0_OpticalDepth);
            cmd.SetGlobalTexture("_Moments", rt1_Moments);
            cmd.SetGlobalTexture("_HigherMoments", rt2_HigherMoments);
            cmd.SetGlobalTexture("_SmokeColor", rt3_SmokeColor);
            cmd.SetGlobalTexture("_DepthRange", rt4_DepthRange);
            
            cmd.SetGlobalFloatArray(Shader.PropertyToID("_SmokeParams"), m_smokeParams);
            
#if true
            RTHandle cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
            Blitter.BlitCameraTexture(cmd, rt0_OpticalDepth, cameraTarget);
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
