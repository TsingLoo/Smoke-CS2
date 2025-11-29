Shader "Unlit/SmokeRaymarching"
{
    Properties
    {
        [Header(Raymarching)]
        
        _MaxSteps ("Max Step", Integer)= 200
        _RaymarchingStepSize("Step Size", float) = 0
     
        [Header(Noise Settings)]
        _DitherStrength("Dither Strength", Float) = 1.0
        _DitherDistance("Dither Distance", Float) = 150.0
        
        
        [Header(Detail Noise Setting)]
        _DetailNoiseStrength ("Detail Noise Strength", Float) = 0.88
        _DetailNoiseUVWScale ("Detail Noise Scale", Float) = 5155.0
        _DetailNoiseSpeed ("Detail Noise Speed", Float) = 0.62
        
        [Range(0.0, 1.0)]
        _BlendFactor("Smoke Data Blend Factor", Float) = 0.1
        
        [Header(Lighting and Color)]
        _Anisotropy ("Anisotropy", Range(-1, 1)) = 1.0
        _AmbientStrength ("Ambient Strength", Float) = 1.0
        _PhaseStrength ("Phase Strength", Float) = 1.0
        _ColorBoost ("Color Boost", Float) = 1.0
        _Saturation ("Saturation", Float) = 1.0
        _DensityMultiplier ("Density Multiplier", Float) = 14.84
        
        //string here could be the default value
        _BlueNoiseTex2D ("Blue Noise 2D Texture", 2D) = "" {}
        _SmokeTex3D ("Smoke Voxel 3D Texture", 3D) = "" {} 
        _HighFreqNoise ("High Freq Noise 3D Texture", 3D) = "" {}
        _ColorLUT3d ("ColorLUT 3D Texture", 3D) = "" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline"}
        
        //ZTest Always
        ZWrite Off
        Cull Off
        ZTest LEqual
        Blend SrcAlpha OneMinusSrcAlpha
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
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

            Texture2D _BlueNoiseTex2D;     SamplerState sampler_BlueNoiseTex2D;
            Texture3D _SmokeTex3D;         SamplerState sampler_SmokeTex3D;
            Texture2D _SmokeMask;          SamplerState sampler_SmokeMask;
            Texture3D _HighFreqNoise;      SamplerState sampler_HighFreqNoise;
            Texture3D _ColorLUT3D;         SamplerState sampler_ColorLUT3D;
            
            // Properties
            CBUFFER_START(UnityPerMaterial)
                float _DitherStrength;
                //float _NoiseScale;
                float _DetailNoiseStrength;
                float _DetailNoiseUVWScale;
                float _DetailNoiseSpeed;
                float _BlendFactor;
                float _Anisotropy;
                float _AmbientStrength;
                float _PhaseStrength;
                float _ColorBoost;
                float _Saturation;
                float _DensityMultiplier;

                float _MaxSteps = 200;
                float _RaymarchingStepSize = 0.2;
                float _DitherDistance;
            CBUFFER_END

            CBUFFER_START(CameraParams)
                float4x4 _InvVP;
                float3 _CameraPosition;    
                float _NearPlane;          
                float3 _CameraForward;      
                float _FarPlane;           
                float3 _CameraRight;
                float _CameraNearPlane;
                float _CameraFarPlane;
            CBUFFER_END
            
            float _VolumeSize = 640.0;
            static const float _VoxelResolution = 32.0;
            static const float _AtlasSliceWidth = 34.0;
            static const float _AtlasTextureWidth = 542.0;

            static const int2 _DitherMask = int2(255, 255);
            
            struct FragmentOutput
            {
                float  OpticalDepth  : SV_Target0; // RFloat
                float2 Moments       : SV_Target1; // RGFloat
                float4 HigherMoments : SV_Target2; // ARGBHalf
                float4 SmokeColor    : SV_Target3; // ARGBHalf
                float2 DepthRange    : SV_Target4; // RGFloat
                float alpha          : SV_Target5;
            };
            
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

            FragmentOutput  frag (v2f input) : SV_Target
            {
                FragmentOutput output;
                output.OpticalDepth = 0.0;
                output.Moments = float2(0, 0);
                output.HigherMoments = float4(0, 0, 0, 0);
                output.SmokeColor = float4(0, 0, 0, 0);
                output.DepthRange = float2(0, 0);
                
                float rawDepth = SampleSceneDepth(input.uv);
                uint rawSmokeMask = (SAMPLE_TEXTURE2D(_SmokeMask, sampler_SmokeMask, input.uv).r);
                //return float4(maskRaw,maskRaw,maskRaw,1);

                if (rawSmokeMask == 0)
                    discard;
                
                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );

                //the array of the smokes this ray hits
                ActiveSmoke activeSmokes[16];
                int activeSmokeCount = 0;
                
                //return float4(maskRaw,maskRaw,maskRaw,1);
                
                float4 worldPos = mul(_InvVP, ndc);
                //the worldPosition of the scene object hit by this ray
                float3 worldPosition = worldPos.xyz / worldPos.w;

                //sceen position of this ray
                int2 screenPos = int2(input.positionCS.xy);
                int2 wrapped = screenPos.xy & _DitherMask;

                //calculate the ditherUV of the pixel
                float2 ditherUV = wrapped/ 256.0;
                //sample blueNoise for this pixel
                float blueNoise = SAMPLE_TEXTURE2D(_BlueNoiseTex2D, sampler_BlueNoiseTex2D, ditherUV).x;
                //make dither time dependent
                float dither = frac(blueNoise + (_Time * 0.618034));
                
                //float3 cameraPos = _CameraPosCS;
                //the direction of this ray
                float3 rayDir = normalize(worldPosition - _CameraPosition);
                //distance between the ray origin to the scene object
                float maxDistBeforeHitTheScene = length(worldPosition - _CameraPosition);
                
                //return float4(maskRaw,0 ,maskRaw,1);
                // if (rawDepth <= 0.0001 || rawDepth >= 0.9999)
                // {
                //     // Invalid Depth
                //     return float4(1, 0, 0, 1);
                // }
                //return float4(rawDepth,rawDepth,rawDepth, 1);

                //loop to see which smokes this ray is hitting
                [loop]
                for (int i = 0; i < _SmokeCount; i++)
                {
                    //return float4(maskRaw,0,maskRaw,1);
                    //check the mask to see if this ray hits the current smoke
                    if ((rawSmokeMask & (1u << i)) == 0)
                        continue;

                    //if the mask tells you this ray hit the current smoke
                    SmokeVolume smoke = _SmokeVolumes[i];
                    if (smoke.volumeIndex < 0)
                        continue;

                    //get the tMin and tMax of the AABB of the current smoke
                    float tMin, tMax;
                    if (!AABBIntersect(
                        smoke.aabbMin,
                        smoke.aabbMax,
                        _CameraPosition,
                        rayDir,
                        tMin,
                        tMax
                    ))
                    {
                        continue;
                    }


                    //ray starts at tMin, but if the origin is inside the smoke, it starts at camera
                    float tRayStart = max(0.0, tMin);

                    if (tRayStart >= maxDistBeforeHitTheScene)
                        continue;

                    //push the current smoke to the array
                    activeSmokes[activeSmokeCount].tMin = tRayStart;
                    activeSmokes[activeSmokeCount].tMax = min(tMax, maxDistBeforeHitTheScene);
                    activeSmokes[activeSmokeCount].index = i;
                    activeSmokeCount++;
                    
                    if (activeSmokeCount >= 16)
                        break;
                }

                //if this ray hits nothing
                if (activeSmokeCount == 0)
                    discard;
                
                //figure out the range of the ray inside valid AABBs
                float globalStartT = 999999.0;
                float globalEndT = 0.0;
                
                for (int k = 0; k < activeSmokeCount; k++)
                {
                    globalStartT = min(globalStartT, activeSmokes[k].tMin);
                    globalEndT = max(globalEndT, activeSmokes[k].tMax);
                }

                //sample the dither to offset the actual start of the raymarching
                float ditherOffset = (_RaymarchingStepSize * dither * _DitherStrength) * 
                     lerp(0.1, 0.8, saturate((globalStartT + _DitherDistance) * 0.05));
                globalStartT += _RaymarchingStepSize + ditherOffset;
                
                //valid rayLength
                float rayLength = globalEndT - globalStartT;

                //calculate how many steps are required to go through this length
                int numSteps = (int)clamp(ceil(rayLength / _RaymarchingStepSize) + 10.0, 1.0, float(_MaxSteps));
                
                float4 accumulatedColor = float4(0, 0, 0, 0);  // SmokeColor
                float opticalDepth = 0.0;                      // OpticalDepth
                float luminance = 0.0;   

                float3 cameraUp = cross(_CameraForward, _CameraRight);
                
                //init ray using the first hit smoke in the array
                float3 rayStart = _CameraPosition + rayDir * globalStartT;
                float3 rayEnd = _CameraPosition + rayDir * min(globalEndT, maxDistBeforeHitTheScene);
                float tFinal = globalStartT + rayLength;
                float3 firstHitPos = rayEnd;
                
                float3 currentWorldPos = rayStart;
                float currentT = globalStartT;

                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction;
                float3 lightColor = mainLight.color;

                float cosTheta = dot(-rayDir, lightDir);
                float phase = PhaseHG(cosTheta, _Anisotropy);

                //ray marhching
                [loop]
                for (float currentStep = 0; currentStep < numSteps; currentStep ++)
                {
                    if (currentT >= globalEndT || currentT >= maxDistBeforeHitTheScene)
                        break;

                    if (accumulatedColor.a > 0.99) break;

                    currentWorldPos = rayStart + rayDir * _RaymarchingStepSize * currentStep; 
                    
                    float3 dominantPos = currentWorldPos;
                    int dominantIndex = -1;

                    //how much behind the volume is blocked in the transmision to the camera 
                    float totalExtinction = 0.0;

                    //how much light is scattered to this ray of observation
                    float3 totalScattering = float3(0, 0, 0);

                    //for each step, check all the smokes hit by this ray
                    [loop]  
                    for (int j = 0; j < activeSmokeCount; j++)
                    {
                        //if the current query is beyond this smoke's AABB, skip
                        if (currentT < activeSmokes[j].tMin || currentT > activeSmokes[j].tMax)
                            continue;

                        //explosion calculation
                        float explosionShadow = 1.0;
                        float explosionOcclusion = 0.0;
                        float3 explosionModifiedPos = currentWorldPos;

                        #if false
                        if (_)
                        {
                            CalculateExplosionShadow(currentPos, _CurrentTime, i, 
                                                    explosionShadow, explosionOcclusion,
                                                    explosionModifiedPos, false);
                        }
                        #endif


                        //get the smokeIdx of this current smoke
                        int smokeIdx = activeSmokes[j].index;
                        SmokeVolume smoke = _SmokeVolumes[smokeIdx];
                        //smoke.tint = float3(1.0f, 1.0f ,1.0f);

                        //UVW is the 3d sampling value
                        float3 baseUVW;
                        float4 smokeData = SampleSmokeDensity(
                            _SmokeTex3D,
                            sampler_SmokeTex3D,
                            currentWorldPos,
                            smoke.position,
                            smoke.volumeIndex,
                            _VolumeSize,
                            _VoxelResolution,
                            _AtlasTextureWidth,
                            _AtlasSliceWidth,
                            baseUVW
                        );

                        //output.SmokeColor = float4(baseUVW.x, baseUVW.y, baseUVW.z,1.0f );

                        //
                        //float blendFactor = smoke.tint.y;

                        //when slice is 15, only the .x and .y have values
                        //float2 blended = lerp(smokeData.xz, smokeData.yw, _BlendFactor);
                        //float baseDensity = blended.x;
                        float baseDensity = smokeData.x;

                        //if there is density at this world posision of the current smoke
                        if (baseDensity > 0.01)
                        {
                            float animTime = _Time * _DetailNoiseSpeed;
                            //distort the sampling position of high frequency noise
                            float distortedVec = ApplyCloudDistortion(baseUVW, animTime);



                            float3 detailUVW = distortedVec * _DetailNoiseUVWScale;

                            //sample the high frequency noise
                            float4 sampledDetailNoise = _HighFreqNoise.SampleLevel(sampler_HighFreqNoise, detailUVW, 0);

                            //calculate the noise data
                            float detailValue = (sampledDetailNoise.r * 0.33 + sampledDetailNoise.g * 0.33 + sampledDetailNoise.b * 0.33) / 1.75;

                            //decrease the volume density by noise
                            float adjustedDensity = baseDensity - (detailValue * _DetailNoiseStrength) * (1.0 - baseDensity);
                            
                            adjustedDensity = saturate(adjustedDensity * _DensityMultiplier * smoke.intensity);

                            //the final density of this ray
                            float finalDensity = clamp((adjustedDensity - 0.01) * 1.0101, 0.0, 1.0);

                            // float noiseValue = SampleLayeredNoise(_HighFreqNoise, sampler_HighFreqNoise, _NoiseScale, _DetailNoiseScale, currentWorldPos, _Time, _NoiseSpeed);
                            // float noiseMod = 1.0 + (noiseValue - 0.5) * _NoiseStrength;
                            // scaledDensity *= noiseMod;

                            if (finalDensity > totalExtinction)
                            {
                                dominantIndex = smokeIdx;
                                dominantPos = currentWorldPos;
                            }
                            
                            totalExtinction += finalDensity;
                            totalScattering += smoke.tint.rgb * finalDensity;
                        }
                    }

                    //if this ray hit at least a smoke
                    if (totalExtinction > 0.01)
                    {
                        // if (dominantIndex >= 0)
                        // {
                        //     SmokeVolume smoke = _SmokeVolumes[dominantIndex];
                        //     float3 localPos = (dominantPos - smoke.position) / _VolumeSize;
                        //     float3 normalizedPos = clamp(localPos * 0.5 + 0.5, 0.0, 1.0);
                        //     
                        //     float3 lutColor = SampleColorLUT(_ColorLUT3D, sampler_ColorLUT3D, _AtlasTextureWidth, _AtlasSliceWidth, _Saturation, _ColorBoost, normalizedPos, totalExtinction, smoke.volumeIndex);
                        //     totalScattering = lerp(totalScattering, lutColor * totalExtinction, 0.5);
                        // }
                        
                        float stepOpticalDepth = totalExtinction * _RaymarchingStepSize;
                        float transmittance = exp(-stepOpticalDepth);
                        float3 inScattering = totalScattering * (1.0 - transmittance) / max(totalExtinction, 0.0001);

                        float lighting = _AmbientStrength + (phase * _PhaseStrength);
                        float3 litScattering = inScattering * lighting * lightColor;
                        litScattering += inScattering * lightColor * (phase * 0.5 * (1.0 - _DetailNoiseStrength));

                        float stepAlpha = 1.0 - transmittance;
                        accumulatedColor.rgb += litScattering * stepAlpha * (1.0 - accumulatedColor.a);
                        accumulatedColor.a += stepAlpha * (1.0 - accumulatedColor.a);

                        opticalDepth += stepOpticalDepth;
                        luminance += length(litScattering) * stepAlpha;
                        
                        if (accumulatedColor.a >= 0.99)
                        {
                            accumulatedColor.a = 1.0;
                            break;
                        }
                    }

                    //currentWorldPos += rayDir * _RaymarchingStepSize;
                    currentT += _RaymarchingStepSize;
                }

                //return float4(opticalDepth,0,0,1);

                if (accumulatedColor.a < 0.00001)
                    discard;
                
                //return float4(opticalDepth,0,0,1);

                #ifdef _FOG
                    float fogFactor = ComputeFogFactor(currentT);
                    accumulatedColor.rgb = MixFog(accumulatedColor.rgb, fogFactor);
                #endif
                output.OpticalDepth = opticalDepth;
                output.SmokeColor = accumulatedColor;

                return output;
            }
            ENDHLSL
        }
    }
}
