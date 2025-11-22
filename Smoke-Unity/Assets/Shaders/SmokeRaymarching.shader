Shader "Unlit/SmokeRaymarching"
{
    Properties
    {
        //string here could be the default value
        _SmokeTex3D ("Smoke 3D Texture", 3D) = "" {}
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

            
            float _VolumeSize = 640.0;
            static const float _VoxelResolution = 32.0;
            static const float _AtlasSliceWidth = 34.0;
            static const float _AtlasTextureWidth = 542.0;
            static const uint _MaxDDASteps = 32;

            static const float _RaymarchingMaxDistance = 1000;
            static const float _RaymarchingStepSize = 10;
            
            ActiveSmoke activeSmokes[16];
            int activeSmokeCount = 0;
            
            struct RaymarchOutput
            {
                float  OpticalDepth  : SV_Target0; // RFloat
                float2 Moments       : SV_Target1; // RGFloat
                float4 HigherMoments : SV_Target2; // ARGBHalf
                float4 SmokeColor    : SV_Target3; // ARGBHalf
                float2 DepthRange    : SV_Target4; // RGFloat
            };

            TEXTURE2D(_SmokeMask);
            SAMPLER(sampler_SmokeMask);
            
            float4x4 _InvVP;
            float3 _CameraPosCS;

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
                float rawDepth = SampleSceneDepth(input.uv);
                uint maskRaw = SAMPLE_TEXTURE2D(_SmokeMask, sampler_SmokeMask, input.uv).x;
                return float4(maskRaw,maskRaw,maskRaw,1);

                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );
                
                float4 worldPos = mul(_InvVP, ndc);
                float3 worldPosition = worldPos.xyz / worldPos.w;
                
                float3 cameraPos = _CameraPosCS;
                float3 rayDir = normalize(worldPosition - cameraPos);
                
                // if (rawDepth <= 0.0001 || rawDepth >= 0.9999)
                // {
                //     // Invalid Depth
                //     return float4(1, 0, 0, 1);  // 红色警告
                // }
                //return float4(rawDepth,rawDepth,rawDepth, 1);

                //figure out which smokes this ray is hitting
                
                for (int i = 0; i <_SmokeCount; i++)
                {
                    if (maskRaw & (1u << i))
                    {
                        float3 aabbMin = _SmokeVolumes[i].aabbMin;
                        float3 aabbMax = _SmokeVolumes[i].aabbMax;
                        
                        float tMin, tMax;
                        if (AABBIntersect(aabbMin, aabbMax, cameraPos, rayDir, tMin, tMax ))
                        {
                            activeSmokes[activeSmokeCount].tMin = tMin;
                            activeSmokes[activeSmokeCount].tMax = tMax;
                            activeSmokes[activeSmokeCount].index = i;
                            activeSmokeCount++;
                        }
                    }
                }

                return float4(maskRaw,maskRaw,maskRaw,1);

                //raymarching
                for (float progress = 0; progress < _RaymarchingMaxDistance; progress += _RaymarchingStepSize)
                {
                    float t = _RaymarchingStepSize * float(progress);

                    if (t >= _RaymarchingMaxDistance)
                        break;

                    float3 samplePos = cameraPos + rayDir * t;
                    
                    for (int i = 0; i < activeSmokeCount; i++) 
                    {
                        // t is beyound the AABB box
                         if (t < activeSmokes[i].tMin || t > activeSmokes[i].tMax)
                             continue;

                        int smokeIdx = activeSmokes[i].index;
                        SmokeVolume smoke = _SmokeVolumes[smokeIdx];

                        float density = SampleSmokeDensity(
                            _SmokeTex3D,
                            sampler_SmokeTex3D,
                            samplePos,
                            smoke,
                            _VolumeSize,
                            _AtlasTextureWidth,
                            _AtlasSliceWidth,
                            _VoxelResolution
                        );

                        return float4(density, density, density, 1.0f);
                    }
                }

                return float4(1, 0, 0, 1);
            }
            ENDHLSL
        }
    }
}
