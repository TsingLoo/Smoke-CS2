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

            static const float _MaxSteps = 200;
            static const float _RaymarchingStepSize = 0.2;
            
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
            
            float3 _LightDir; 
            float3 _LightColor;

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
                uint maskRaw = (SAMPLE_TEXTURE2D(_SmokeMask, sampler_SmokeMask, input.uv).r);
                //return float4(maskRaw,maskRaw,maskRaw,1);

                if (maskRaw == 0)
                    discard;
                
                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );

                ActiveSmoke activeSmokes[16];
                int activeSmokeCount = 0;
                
                //return float4(maskRaw,maskRaw,maskRaw,1);
                
                float4 worldPos = mul(_InvVP, ndc);
                float3 worldPosition = worldPos.xyz / worldPos.w;

                
                
                float3 cameraPos = _CameraPosCS;
                float3 rayDir = normalize(worldPosition - cameraPos);
                float maxDistBeforeHitTheScene = length(worldPosition - cameraPos);
                //return float4(maskRaw,0 ,maskRaw,1);
                // if (rawDepth <= 0.0001 || rawDepth >= 0.9999)
                // {
                //     // Invalid Depth
                //     return float4(1, 0, 0, 1);
                // }
                //return float4(rawDepth,rawDepth,rawDepth, 1);

                //figure out which smokes this ray is hitting

                

                [loop]
                for (int i = 0; i < _SmokeCount; i++)
                {
                    //return float4(maskRaw,0,maskRaw,1);
                    if ((maskRaw & (1u << i)) == 0)
                        continue;
                    
                    SmokeVolume smoke = _SmokeVolumes[i];
                    if (smoke.volumeIndex < 0)
                        continue;
                    
                    float tMin, tMax;
                    if (!AABBIntersect(
                        smoke.aabbMin,
                        smoke.aabbMax,
                        cameraPos,
                        rayDir,
                        tMin,
                        tMax
                    ))
                    {
                        continue;
                    }
                    
                    float rayStart = max(0.0, tMin);
                    if (rayStart >= maxDistBeforeHitTheScene)
                        continue;
                    
                    activeSmokes[activeSmokeCount].tMin = rayStart;
                    activeSmokes[activeSmokeCount].tMax = min(tMax, maxDistBeforeHitTheScene);
                    activeSmokes[activeSmokeCount].index = i;
                    activeSmokeCount++;
                    
                    if (activeSmokeCount >= 16)
                        break;
                }

                if (activeSmokeCount == 0)
                    discard;

                //return float4(activeSmokeCount/16.0, 0, 0, 1);

                //Raymarching

                //figure out the range of the ray inside valid AABBs
                float globalStartT = 999999.0;
                float globalEndT = 0.0;

                for (int k = 0; k < activeSmokeCount; k++)
                {
                    globalStartT = min(globalStartT, activeSmokes[k].tMin);
                    globalEndT = max(globalEndT, activeSmokes[k].tMax);
                }
                
                //valid rayLength
                float rayLength = globalEndT - globalStartT;

                //calculate how many steps are required to go through this length
                int numSteps = (int)clamp(ceil(rayLength / _RaymarchingStepSize) + 10.0, 1.0, float(_MaxSteps));
                
                float4 accumulatedColor = float4(0, 0, 0, 0);  // SmokeColor
                float opticalDepth = 0.0;  // OpticalDepth
                float lightEnergy = 0.0;   

                //init ray using the first hit smoke in the array
                float3 rayStart = cameraPos + rayDir * globalStartT;
                //float3 rayEnd = cameraPos + rayDir * min(activeSmokes[0].tMax, maxDistBeforeHitTheScene);

                float3 currentWorldPos = rayStart;
                float currentT = globalStartT;
                
                
                for (float currentStep = 0; currentStep < numSteps; currentStep ++)
                {
                    if (currentT >= globalEndT || currentT >= maxDistBeforeHitTheScene)
                        break;

                    float maxDensity = 0.0;
                    float3 dominantColor = float3(0, 0, 0);
                    float dominantIntensity = 1.0;
                    int dominantIndex = -1;
                    float totalExtinction = 0.0;  // 总消光系数
                    float3 totalScattering = float3(0, 0, 0);  // 总散射颜色
                    
                    [loop]
                    for (int j = 0; j < activeSmokeCount; j++)
                    {
                        if (currentT < activeSmokes[j].tMin || currentT > activeSmokes[j].tMax)
                            continue;

                        int smokeIdx = activeSmokes[j].index;
                        SmokeVolume smoke = _SmokeVolumes[smokeIdx];

                        float4 smokeData = SampleSmokeDensity(
                            _SmokeTex3D,
                            sampler_SmokeTex3D,
                            currentWorldPos,
                            smoke.position,
                            smoke.volumeIndex,
                            _VolumeSize,
                            _VoxelResolution,
                            _AtlasTextureWidth,
                            _AtlasSliceWidth
                        );

                        //
                        //float blendFactor = smoke.tint.y;
                        float blendFactor = 0.5f;
                        float2 blended = lerp(smokeData.xz, smokeData.yw, blendFactor);
                        float density = blended.x;

                        if (density > 0.01)
                        {
                            float adjustedDensity = clamp((density - 0.01) * 1.0101, 0.0, 1.0);
                            float scaledDensity = adjustedDensity * smoke.intensity;
                            
                            totalExtinction += scaledDensity;
                            totalScattering += smoke.tint * scaledDensity;
                        }
                    }

                    //return float4(totalExtinction,totalExtinction,totalExtinction,1);
                    //return float4(maxDensity,maxDensity,maxDensity,1);

                    if (totalExtinction  > 0.01)
                    {
                        // calculate alpha
                        // float _20845 = clamp(clamp((_6665 - 0.00999999977648258209228515625) * 1.01010096073150634765625, 0.0, 1.0), 0.0, 1.0) * _4023._m5._m0[_25082].x;
                        float adjustedDensity = clamp((maxDensity - 0.01) * 1.0101, 0.0, 1.0);
                        float densityScale = adjustedDensity * dominantIntensity;
                        
                        // light calculating
                        // float _15561 = dot(mix(_21940, _19632, vec3(_5618._m6)), _5538._m0.xyz);
                        float lightDot = max(0.0, dot(normalize(rayDir), normalize(_LightDir)));
                        float lighting = 0.75 + (lightDot * 0.25);
                        
                        // color ontribution
                        float3 stepColor = dominantColor * densityScale * lighting;
                        
                        // smoothstep alpha
                        // float _17656 = smoothstep(0.0, 0.20000000298023223876953125 / (...), _13439);
                        float alpha = smoothstep(0.0, 0.2, adjustedDensity) * 0.1;
                        
                        // forward blend
                        // _19916 = _16311 + (_22501 * (1.0 - _16311.w));
                        accumulatedColor.rgb += stepColor * alpha * (1.0 - accumulatedColor.a);
                        accumulatedColor.a += alpha * (1.0 - accumulatedColor.a);
                        
                        // optical depth
                        opticalDepth += totalExtinction  * _RaymarchingStepSize;
                        
                        // if (_13637.w > 0.990999996662139892578125)
                        if (accumulatedColor.a >= 0.99)
                        {
                            accumulatedColor.a = 1.0;
                            
                            return accumulatedColor;
                        }
                    }

                    currentWorldPos += rayDir * _RaymarchingStepSize;
                    currentT += _RaymarchingStepSize;
                }

                return float4(opticalDepth,opticalDepth,opticalDepth,1);

                if (accumulatedColor.a < 0.00001)
                    discard;

                return accumulatedColor;
            }
            ENDHLSL
        }
    }
}
