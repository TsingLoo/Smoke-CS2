Shader "Unlit/SmokeRaymarching"
{
    Properties
    {
        // ========================================================
        // 基础 Raymarching 设置 (Basic Settings)
        // ========================================================
        [Header(Raymarching Core)]
        _BaseStepSize ("Base Step Size", Float) = 1.0
        _RayMarchStepScale ("Step Scale Multiplier", Range(0.1, 5.0)) = 1.0
        _TemporalJitterAmount ("Temporal Jitter", Range(0.0, 1.0)) = 0.5
        [IntRange] _ResolutionDivisor ("Resolution Divisor", Range(1, 8)) = 1

        // ========================================================
        // 光照与材质 (Lighting & Material)
        // ========================================================
        [Header(Lighting and Material)]
        _DirectLightIntensity ("Direct Light Intensity", Float) = 1.0
        _AmbientLight ("Ambient Light", Range(0.0, 2.0)) = 0.1

        _AbsorptionCoeff ("Absorption Coeff", Range(0.0, 10.0)) = 0.5
        _ScatteringCoeff ("Scattering Coeff", Range(0.0, 10.0)) = 1.0
        _PhaseFunction ("Phase Function (Anisotropy)", Range(-0.99, 0.99)) = 0.5
        _DensityScale ("Global Density Scale", Float) = 1.0

        // ========================================================
        // 云形状与覆盖 (Cloud Shape)
        // ========================================================
        [Header(Cloud Shape)]
        _CloudDensity ("Cloud Density", Range(0.0, 5.0)) = 1.0
        _CloudCoverage ("Cloud Coverage", Range(0.0, 1.0)) = 0.5
        _CloudErosion ("Cloud Erosion", Range(0.0, 1.0)) = 0.3
        _CloudTopHeight ("Cloud Top Height", Float) = 100.0

        // ========================================================
        // 噪声控制 (Noise Settings)
        // ========================================================
        [Header(Noise Controls)]
        _BaseNoiseScale ("Base Noise Scale", Float) = 1.0
        _DetailNoiseScale ("Detail Noise Scale", Float) = 2.0
        _MicroDetailScale ("Micro Detail Scale", Float) = 4.0

        _NoiseWeight ("Noise Weight", Range(0.0, 1.0)) = 0.5
        _MicroDetailWeight ("Micro Detail Weight", Range(0.0, 1.0)) = 0.25
        _DetailStrength ("Detail Strength", Range(0.0, 2.0)) = 1.0

        // ========================================================
        // 动画与环境 (Animation & Env)
        // ========================================================
        [Header(Environment and Animation)]
        _WindOffset ("Wind Offset (XYZ)", Vector) = (0,0,0,0)
        _AnimationSpeed ("Animation Speed", Float) = 1.0

        _FogAmount ("Fog Amount", Range(0.0, 1.0)) = 0.1
        _FogStartDistance ("Fog Start Distance", Float) = 10.0

        // ========================================================
        // 调试 (Debug)
        // ========================================================
        [Header(Debug)]
        [Enum(None,0, Steps,1, Density,2, Normals,3)] _DebugRenderMode ("Debug Render Mode", Int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline"}
        
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

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            
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

            StructuredBuffer<BulletHoleData> _BulletHoleBuffer;
            int _BulletHoleCount;

            Texture2D _BlueNoiseTex2D;     SamplerState sampler_BlueNoiseTex2D;
            Texture3D _SmokeTex3D;         SamplerState sampler_SmokeTex3D;
            Texture2D _SmokeMask;          SamplerState sampler_SmokeMask;
            Texture3D _HighFreqNoise;      SamplerState sampler_HighFreqNoise;
            Texture3D _ColorLUT3D;         SamplerState sampler_ColorLUT3D;

            CBUFFER_START(UnityPerMaterial) // 或者使用 RenderSettingsUniforms
                float _TemporalJitterAmount;
                float _RayMarchStepScale;
                float _DensityScale;
                float _AbsorptionCoeff;
                float _ScatteringCoeff;
                float _PhaseFunction;
                float _AmbientLight;
                float _DirectLightIntensity;
                float _BaseNoiseScale;
                float _DetailNoiseScale;
                float _NoiseWeight;
                float _MicroDetailScale;
                float _MicroDetailWeight;
                float _CloudErosion;
                float _CloudDensity;
                float _CloudCoverage;
                float _CloudTopHeight;
                float _BaseStepSize;
                float _DetailStrength; // 对应之前的 fogFadeDistance 位置
                int   _DebugRenderMode;
                float3 _WindOffset;    // 注意：Properties里是Vector(4D)，这里取float3即可
                float _FogAmount;
                float _FogStartDistance;
                float _AnimationSpeed;
                int   _ResolutionDivisor;
            CBUFFER_END
            
            CBUFFER_START(UnityPerMaterial)
                float _DitherStrength;
                float _Anisotropy;
                float _AmbientStrength;
                float _PhaseStrength;
                float _ColorBoost;
                float _Saturation;
                float _DensityMultiplier;
                float _ExtinctionScale;
                float _LightingBoost;
                float _GradientOffset;
                float _DiffusePower;
                float _SpecularPower;
                float _ContrastPower;
                float _MaxSteps;
                float _RaymarchingStepSize;
                float _DitherTransitionDistance;
                float _HeightLightingPower;

                float _NoiseScale1;
                float _NoiseScale2;
                float _NoiseGamma;
                float _NoiseBias;
                float _NoiseColorA;
                float _NoiseColorB;
                float _NoiseBlendFactor;
                float _NormalStrength1;
                float _NormalStrength2;
                float _WarpStrength;
                float _ScrollSpeed;
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

            float _VolumeSize;
            float _SmokeInterpolationT;
            float4 _BlueNoiseTex2D_TexelSize;
            
            struct FragmentOutput
            {
                float  OpticalDepth  : SV_Target0;
                float2 Moments       : SV_Target1;
                float4 HigherMoments : SV_Target2;
                float4 SmokeColor    : SV_Target3;
                float2 DepthRange    : SV_Target4;
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

            FragmentOutput frag (v2f input) : SV_Target
            {
                FragmentOutput output;
                output.OpticalDepth = 0.0;
                output.Moments = float2(0, 0);
                output.HigherMoments = float4(0, 0, 0, 0);
                output.SmokeColor = float4(0, 0, 0, 0);
                output.DepthRange = float2(0, 0);

                //sample the depth of the scene
                float rawDepth = SampleSceneDepth(input.uv);
                //sample the smokeMaks
                uint rawSmokeMask = (SAMPLE_TEXTURE2D(_SmokeMask, sampler_SmokeMask, input.uv).r);

                //if no smoke is hit by this fragment,discard
                if (rawSmokeMask == 0)
                    discard;

                output.SmokeColor = float4(1.0,1.0,1.0,1.0);
                return output;

                //temp array to record which smokes are hit by this ray
                ActiveSmoke activeSmokes[16];
                int activeSmokeCount = 0;

                //calculate the ndc position of the scene of this fragment
                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );
                
                float4 worldPos = mul(_InvVP, ndc);
                //calculate the worldPosition of the scene of this fragment in world space
                float3 worldPosition = worldPos.xyz / worldPos.w;

                //from camera to the worldPosition
                float3 rayDir = normalize(worldPosition - _CameraPosition);
                float maxDistBeforeHitTheScene = length(worldPosition - _CameraPosition);

                //loop to know which smoke is hit by this fragment
                [loop]
                for (int i = 0; i < _SmokeCount; i++)
                {
                    if ((rawSmokeMask & (1u << i)) == 0)
                        continue;

                    //get the meta data of the smoke
                    SmokeVolume smoke = _SmokeVolumes[i];
                    if (smoke.volumeIndex < 0)
                        continue;

                    //fetch the tMin and tMax info of this ray
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

                    //ensure tRayStart is always (before) the camera 
                    float tRayStart = max(0.0, tMin);

                    //if the start of ray is behind the scene, discard
                    if (tRayStart >= maxDistBeforeHitTheScene)
                        continue;

                    //record the tMin tMax info for this smoke
                    activeSmokes[activeSmokeCount].tMin = tRayStart;
                    activeSmokes[activeSmokeCount].tMax = min(tMax, maxDistBeforeHitTheScene);
                    activeSmokes[activeSmokeCount].index = i;
                    activeSmokeCount++;
                    
                    if (activeSmokeCount >= 16)
                        break;
                }

                //if there is no smoke hit by this ray, discard
                if (activeSmokeCount == 0)
                    discard;

                //we should care about the global tRayStart and tRayEnd
                float globalStartT = 999999.0;
                float globalEndT = 0.0;
                
                for (int k = 0; k < activeSmokeCount; k++)
                {
                    globalStartT = min(globalStartT, activeSmokes[k].tMin);
                    globalEndT = max(globalEndT, activeSmokes[k].tMax);
                }

                //get the pixel coordinate of this fragment
                int2 screenPos = int2(input.positionCS.xy);
                //calculate the dither sampling coordinate
                float2 ditherUV = screenPos * _BlueNoiseTex2D_TexelSize.xy;
                //sample the blue noise
                float blueNoise = SAMPLE_TEXTURE2D(_BlueNoiseTex2D, sampler_BlueNoiseTex2D, ditherUV).r;
                //get the dither to offset ray start
                float dither = frac(blueNoise + (_Time * 0.618034));

                //dither the globalStartT by the distance, the closer the smaller 
                float distanceFactor = saturate(max(0.0, globalStartT) / _DitherTransitionDistance);
                float ditherOffset = (_RaymarchingStepSize * dither * _DitherStrength) * 
                                     lerp(0.1, 0.8, distanceFactor);

                //offset the global start to avoid band effect
                globalStartT += _RaymarchingStepSize + ditherOffset;

                float rayLength = globalEndT - globalStartT;

                int numSteps = (int)clamp(ceil(rayLength / _RaymarchingStepSize) + 10.0, 1.0, float(_MaxSteps));

                //init this ray infomration 
                float4 accumulatedColor = float4(0, 0, 0, 0);
                float opticalDepth = 0.0;
                float luminance = 0.0;
                
                float3 rayStart = _CameraPosition + rayDir * globalStartT;
                float3 rayEnd = _CameraPosition + rayDir * min(globalEndT, maxDistBeforeHitTheScene);
                
                float3 currentWorldPos = rayStart;
                float currentT = globalStartT;

                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction;
                float3 lightColor = mainLight.color;

                //light contribution towards camerae
                float cosTheta = dot(-rayDir, lightDir);
                //the posibilty the contribution will be added to the camera
                float phase = PhaseHG(cosTheta, _Anisotropy);

                //Raymarching
                [loop]
                for (float currentStep = 0; currentStep < numSteps; currentStep ++)
                {
                    if (currentT >= globalEndT || currentT >= maxDistBeforeHitTheScene)
                        break;

                    if (accumulatedColor.a > 0.99) break;

                    currentWorldPos = rayStart + rayDir * _RaymarchingStepSize * currentStep; 
                    
                    float3 dominantPos = currentWorldPos;
                    int dominantIndex = -1;
                    float3 dominantGradient = float3(0, 1, 0);
                    float3 dominantVolumeCenter = float3(0, 0, 0);

                    float totalExtinction = 0.0;
                    float3 totalScattering = float3(0, 0, 0);

                    // for each step, we want take all the possible active smokes into account
                    [loop]  
                    for (int j = 0; j < activeSmokeCount; j++)
                    {
                        if (currentT < activeSmokes[j].tMin || currentT > activeSmokes[j].tMax)
                            continue;

                        int smokeIdx = activeSmokes[j].index;
                        SmokeVolume smoke = _SmokeVolumes[smokeIdx];

                        float3 baseUVW;
                        float3 densityGradient;

                        // float densityOfThisStep = GetSmokeDensityWithGradient(_GradientOffset,
                        //     currentWorldPos, smoke, 
                        //     _SmokeTex3D, sampler_SmokeTex3D, 
                        //     _HighFreqNoise, sampler_HighFreqNoise, 
                        //     _VolumeSize, _Time.y, 
                        //     _DetailNoiseSpeed, _DetailNoiseUVWScale, _DetailNoiseStrength, _DensityMultiplier, _SmokeInterpolationT,
                        //     baseUVW, densityGradient
                        // );

                        float densityOfThisStep = GetSmokeDensityWithGradientCS2(
                            _GradientOffset,
                            currentWorldPos, smoke, 
                            _SmokeTex3D, sampler_SmokeTex3D, 
                            _HighFreqNoise, sampler_HighFreqNoise, 
                            _VolumeSize, _Time.y, 
                            _NoiseScale1, _NoiseScale2,
                            _NoiseGamma, _NoiseBias,
                            _NoiseColorA, _NoiseColorB, _NoiseBlendFactor,
                            _NormalStrength1, _NormalStrength2,
                            _WarpStrength, _ScrollSpeed,
                            _DensityMultiplier, _SmokeInterpolationT,
                            baseUVW, densityGradient
                        );

                        float penetration = GetBulletPenetration(currentWorldPos, _BulletHoleBuffer, _BulletHoleCount);
                        densityOfThisStep *= penetration;

                        densityOfThisStep = clamp((densityOfThisStep - 0.01) * 1.0101, 0.0, 1.0);

                        if (densityOfThisStep > 0.001)
                        {
                            totalExtinction += densityOfThisStep;
                            
                            if (densityOfThisStep > totalExtinction - densityOfThisStep)
                            {
                                dominantIndex = smokeIdx;
                                dominantPos = currentWorldPos;
                                dominantGradient = densityGradient;
                                dominantVolumeCenter = smoke.position;
                            }

                            totalScattering += smoke.tint.rgb * densityOfThisStep;
                        }
                    }

                    //if the density is large enough to block the sight
                    if (totalExtinction > 0.01)
                    {
                        float4 shadowCoord = TransformWorldToShadowCoord(currentWorldPos);
                        float shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
                        
                        //localPosition in volume space
                        float3 normalizedLocalPos = (currentWorldPos - dominantVolumeCenter) / _VolumeSize;

                        //how much the current sampling position is closer the light source, range mapped to [0.0, 1.0]
                        float heightFactor = saturate(dot(normalizedLocalPos, lightDir) + 0.5);

                        //as the heightFactor is [0.0, 1.0], a large _HeightLightingPower will decrease the size of the highlight
                        heightFactor = pow(heightFactor, _HeightLightingPower);

                        //calculate the light contribution to this sampling point
                        float3 macroNormal = normalize(currentWorldPos - dominantVolumeCenter);
                        float3 microNormal = dominantGradient;
                        float3 finalNormal = normalize(lerp(macroNormal, microNormal, 0.1));
                        float NdotL = dot(finalNormal, lightDir);
                        
                        float diffuseTerm = pow(saturate(NdotL * 0.8 + 0.2), _DiffusePower);
                        float specularTerm = pow(saturate(NdotL * 1.4 - 0.5), _SpecularPower);
                        float directionalLighting = diffuseTerm + specularTerm;

                        //output.SmokeColor = float4(shadowAttenuation,shadowAttenuation,shadowAttenuation,1.0);
                        //output.SmokeColor = shadowCoord;
                        //output.SmokeColor.a = 1.0;
                        //return output;
                        
                        float baseLighting = saturate(directionalLighting * 0.5) + _LightingBoost * heightFactor;
                        
                        float enhancedExtinction = lerp(
                            totalExtinction - (1.0 - baseLighting),
                            totalExtinction + baseLighting,
                            totalExtinction
                        );
                        enhancedExtinction = max(enhancedExtinction, totalExtinction);
                        
                        float stepOpticalDepth = enhancedExtinction * _RaymarchingStepSize * _ExtinctionScale;
                        float transmittance = exp(-stepOpticalDepth);
                        float stepAlpha = 1.0 - transmittance;
                        
                        float3 ambient = _AmbientStrength;
                        float3 directional = lightColor * (phase * _PhaseStrength) * directionalLighting;
                        directional = pow(directional, _ContrastPower);
                        //directional *= shadowAttenuation;
                        float3 finalLighting = ambient + directional;
                        
                        float3 inScattering = totalScattering * (1.0 - transmittance) / max(totalExtinction, 0.0001);
                        float3 litScattering = inScattering * finalLighting;
                        
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
                    
                    currentT += _RaymarchingStepSize;
                }
                
                if (accumulatedColor.a < 0.00001)
                    discard;

                #ifdef _FOG
                    float fogFactor = ComputeFogFactor(currentT);
                    accumulatedColor.rgb = MixFog(accumulatedColor.rgb, fogFactor);
                #endif
                output.OpticalDepth = opticalDepth;
                output.SmokeColor = accumulatedColor;
                //output.SmokeColor = float4(_SmokeInterpolationT,_SmokeInterpolationT,_SmokeInterpolationT,1.0);

                return output;
            }
            ENDHLSL
        }
    }
}