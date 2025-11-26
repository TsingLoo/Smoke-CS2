Shader "Unlit/SmokeMask"
{
    Properties
    {
        //string here could be the default value
        _SmokeTex3D ("Smoke 3D Texture", 3D) = "" {}
        _MaxDDASteps ("Max DDA Steps", Integer) = 32
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        //ZTest Always
        ZWrite Off
        Cull Off
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Assets/Shaders/Include/Utils.hlsl"
            #include "Assets/Shaders/Include/Defines.hlsl"
            
            struct appdata
            {
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            StructuredBuffer<SmokeVolume> _SmokeVolumes;
            int _SmokeCount;
            Texture3D _SmokeTex3D;
            SamplerState sampler_SmokeTex3D;

            uint _MaxDDASteps;
            
            float _VolumeSize = 640.0;
            static const float _VoxelResolution = 32.0;
            static const float _AtlasSliceWidth = 34.0;
            static const float _AtlasTextureWidth = 542.0;

            
            float4x4 _InvVP;
            float3 _CameraPosition;
            
            v2f vert (appdata input)
            {
                v2f output;
                float2 uv = float2((input.vertexID << 1) & 2, input.vertexID & 2);
                output.positionCS  = float4(uv * 2.0 - 1.0, 0.0, 1.0);
                output.uv = uv;

                #if UNITY_UV_STARTS_AT_TOP
                    output.uv.y = 1.0 - output.uv.y;
                #endif
                
                return output;
            }

            float4 frag (v2f input) : SV_Target
            {
                //return float4(1,1,1,1);
                float rawDepth = SampleSceneDepth(input.uv);
                
                // #if defined(UNITY_REVERSED_Z)
                //     rawDepth = 1.0 - rawDepth;
                // #endif
                //return float4(rawDepth,rawDepth,rawDepth, 1);
                // if (rawDepth <= 0.0001 || rawDepth >= 0.9999)
                // {
                //     // Invalid Depth
                //     return float4(1, 0, 0, 1);  // 红色警告
                // }
                //return float4(rawDepth,rawDepth,rawDepth, 1);
                
                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );
                
                float4 worldPos = mul(_InvVP, ndc);
                float3 worldPosition = worldPos.xyz / worldPos.w;

                float3 cameraPos = _CameraPosition;
                float3 rayDir = normalize(worldPosition - cameraPos);
                float maxDist = length(worldPosition - cameraPos);

                //return float4(maxDist / 20.0, 0, 0, 1);
                
                uint smokeMask = 0;
                // iterate through smokes
                for (int i = 0; i < _SmokeCount; i++)
                {
                    SmokeVolume smoke = _SmokeVolumes[i];
                    if (smoke.volumeIndex < 0) continue;

                    float tMin, tMax;
                    
                    if (AABBIntersect(
                        smoke.aabbMin,
                        smoke.aabbMax,
                        cameraPos,
                        rayDir,
                        tMin,
                        tMax
                    ))
                    {
                        float rayStart = max(0.0, tMin);
                        if (rayStart >= maxDist) 
                            continue;
                        
                        float3 startPos = cameraPos + rayDir * rayStart;

                        float maxTraverseDist = min(tMax, maxDist) - rayStart;
                        
                        if (TraverseVoxels(
                            _SmokeTex3D,
                            sampler_SmokeTex3D,
                            startPos,
                            rayDir,
                            maxTraverseDist,
                            smoke.position,
                            smoke.volumeIndex,
                            _VolumeSize,
                            _VoxelResolution,
                            _AtlasTextureWidth,
                            _AtlasSliceWidth,
                            _MaxDDASteps
                        ))
                        {
                            smokeMask |= (1u << i);
                        }
                    }
                }
                
                if (smokeMask == 0)
                    discard;  // this fragment is not in smoke


                //return float4(1,1,1,1);
                return smokeMask;
            }
            ENDHLSL
        }
    }
}
