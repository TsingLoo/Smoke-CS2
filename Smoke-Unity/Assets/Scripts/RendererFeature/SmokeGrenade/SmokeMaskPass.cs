using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

 class SmokeMaskPass : ScriptableRenderPass
    {
        private int m_DownSample = 2;
        private Material material;
        private RTHandle m_SmokeMaskHandle;
        public RTHandle MSmokeMaskHandle => m_SmokeMaskHandle;
        private const string profilerTag = "SmokeMask";
        private float voxelSize = 1.0f;
        
        public SmokeMaskPass(SmokeGrenadeRendererFeature.Settings settings)
        {
            material = settings.smokeMaskMaterial;
            renderPassEvent = settings.smokeMaskRenderPassEvent;
            
            this.m_DownSample = settings.downSample;
            this.voxelSize = settings.VoxelSize;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.width /= m_DownSample;
            descriptor.height /= m_DownSample;
            descriptor.colorFormat = RenderTextureFormat.RHalf;
            descriptor.depthBufferBits = 0;
            descriptor.msaaSamples = 1;
            
            RenderingUtils.ReAllocateIfNeeded(ref m_SmokeMaskHandle, descriptor, name: "_SmokeMask");
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null || m_SmokeMaskHandle == null)
            {
                Debug.LogWarning("[SmokeMaskPass] Material or target is null!");
                return;
            }
            
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            
            cmd.SetGlobalFloat("_VolumeSize", voxelSize);
            
            using (new ProfilingScope(cmd, new ProfilingSampler(profilerTag)))
            {
                Camera cam = renderingData.cameraData.camera;
                Matrix4x4 viewMatrix = renderingData.cameraData.GetViewMatrix();
                Matrix4x4 projMatrix = renderingData.cameraData.GetGPUProjectionMatrix();
                Matrix4x4 vpMatrix = projMatrix * viewMatrix;
                Matrix4x4 invVPMatrix = vpMatrix.inverse;
                
                cmd.SetGlobalMatrix("_InvVP", invVPMatrix);
                cmd.SetGlobalVector("_CameraPosCS", cam.transform.position);
                
                
                CoreUtils.SetRenderTarget(cmd, m_SmokeMaskHandle, ClearFlag.Color, Color.clear);
                
                cmd.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, 3, 1);
                
                cmd.SetGlobalTexture("_SmokeMask", m_SmokeMaskHandle);
                
#if false
                RTHandle cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
                Blitter.BlitCameraTexture(cmd, m_SmokeMaskHandle, cameraTarget);
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
            m_SmokeMaskHandle?.Release();
        }
    }