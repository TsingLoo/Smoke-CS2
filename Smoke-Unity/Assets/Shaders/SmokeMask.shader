Shader "Unlit/SmokeMask"
{
    Properties
    {
        //string here could be the default value
        _CS2SmokeTex3D ("Smoke 3D Texture", 3D) = "" {}
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

            CBUFFER_START(_SceneVolumeUniforms)
            
                float4 volumeMinBounds[16];
                float4 volumeMaxBounds[16];
                float4 volumeCenters[16];
                float4 volumeAnimState[16];
                float4 volumeTintColor[16];
                float4 volumeFadeParams[16];
                
                float4 sceneAABBMin;
                float4 sceneAABBMax;
                
                float4 bulletTracerStarts[16];
                float4 bulletTracerEnds[16];
                float4 tracerInfluenceParams[16];
            
                float4 explosionPositions[5];
            
                float4 volumeTracerMasks[2];
                
                uint activeTracerCount;
                float animationTime;
                uint enableExplosions;

                float3 _CameraForward;
            
            CBUFFER_END
            
            int _SmokeCount;
            Texture3D _CS2SmokeTex3D;
            SamplerState sampler_CS2SmokeTex3D;

            uint _MaxDDASteps;

            //Change this in SmokeGrenadeRendererFeature
            float _VolumeSize;

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
                    1.0,
                    1.0
                );
                
                float4 worldPos = mul(_InvVP, ndc);
                float3 worldPosition = worldPos.xyz / worldPos.w;

                float3 cameraPos = _CameraPosition;
                float3 rayDir = normalize(worldPosition - cameraPos);
                //float3 cameraForward = -UNITY_MATRIX_V[2].xyz; // 或者传入 _CameraForward
                float cosAngle = dot(_CameraForward, rayDir);
                float viewZ = LinearEyeDepth(rawDepth, _ZBufferParams);
                float maxDist = viewZ / max(cosAngle, 0.001);
                //float rayDotCameraForward = dot(_CameraForward, rayDirection);
                //float sceneSurfaceDistance = viewZ / rayDotCameraForward;
                
                //float maxRayDistance = 1.0 / (linearDepth * cosAngle);

                //return float4(_SmokeCount / 16.0, 0, 0, 1);
                
                uint smokeMask = 0;
                // iterate through smokes
                for (int i = 0; i < _SmokeCount; i++)
                {
                    //SmokeVolume smoke = _SmokeVolumes[i];
                    float3 aabbMin = volumeMinBounds[i].xyz;
                    float3 aabbMax = volumeMaxBounds[i].xyz;

                    int slotIndex = volumeAnimState[i].z;
                    
                    if (slotIndex < 0) continue;
                    float tMin, tMax;
                    if (AABBIntersect(
                        aabbMin,
                        aabbMax,
                        cameraPos,
                        rayDir,
                        tMin,
                        tMax
                    ))
                    {
                        //return float4(1,1,1,1);
                        //return 1;
                        float rayStart = max(0.0, tMin);
                        if (rayStart >= maxDist) 
                            continue;
                        
                        float3 startPos = cameraPos + rayDir * rayStart;

                        float maxTraverseDist = min(tMax, maxDist) - rayStart;

                        float3 pos = volumeCenters[i].xyz;
                        
                        if (TraverseVoxels(
                            _CS2SmokeTex3D,
                            sampler_CS2SmokeTex3D,
                            startPos,
                            rayDir,
                            maxTraverseDist,
                            pos,
                            slotIndex,
                            _VolumeSize,
                            VOLUME_RESOLUTION,
                            DENSITY_ATLAS_WIDTH_INV,
                            VOLUME_RESOLUTION,
                            _MaxDDASteps
                        ))
                        {
                            smokeMask |= (1u << i);
                        }
                    }
                }
                
                if (smokeMask == 0)
                    discard;  // this fragment is not in smoke

                // return float4(1,1,1,1);
                return smokeMask;
            }
            ENDHLSL
        }
    }
}
