using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SmokeGrenadeRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent smokeMaskRenderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public Material smokeMaskMaterial;
        [Range(1, 4)] public int downSample = 2;

        [Range(1.0f, 640.0f)] public float VoxelSize = 4.0f;
    }
    
    public Settings settings = new Settings();
    private SmokeMaskPass smokeMaskPass;
    
    public override void Create()
    {
        smokeMaskPass = new SmokeMaskPass(settings);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(smokeMaskPass);
    }
    
    protected override void Dispose(bool disposing)
    {
        smokeMaskPass?.Dispose();
    }
}