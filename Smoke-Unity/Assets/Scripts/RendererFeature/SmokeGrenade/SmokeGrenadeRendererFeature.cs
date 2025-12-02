using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SmokeGrenadeRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        [Header("General")]
        [Range(1, 4)] public int downSample = 2;
        //[Range(1.0f, 640.0f)] public float VoxelSize = 4.0f;

        [Header("Composite Material")] 
        public Material compositeMat;
        
        [Header("SmokeMask")]
        public RenderPassEvent smokeMaskRenderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public Material smokeMaskMaterial;

        [Header("Raymarching")]
        public RenderPassEvent smokeRaymarchingPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public Material smokeRaymarchingPassMaterial;
    }
    
    public Settings settings = new Settings();
    private SmokeMaskPass smokeMaskPass;
    private SmokeRaymarchingPass smokeRaymarchingPass;
    
    public override void Create()
    {
        smokeMaskPass = new SmokeMaskPass(settings);
        smokeRaymarchingPass = new SmokeRaymarchingPass(settings);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(smokeMaskPass);
        renderer.EnqueuePass(smokeRaymarchingPass);
    }
    
    protected override void Dispose(bool disposing)
    {
        smokeMaskPass?.Dispose();
        smokeRaymarchingPass?.Dispose();
    }
}