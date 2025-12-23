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
        _TemporalJitterAmount ("Temporal Jitter", Range(0.0, 5.0)) = 0.5
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


        _BlueNoiseTex2D ("Blue Noise 2D Texture", 2D) = "" {}
        _HighFreqNoise ("High Freq Noise 3D Texture", 3D) = "" {}
        _ColorLUT3D ("ColorLUT 3D Texture", 3D) = "" {}

    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline"
        }

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

            Texture2D _BlueNoiseTex2D;
            SamplerState sampler_BlueNoiseTex2D;
            Texture3D _SmokeTex3D;
            SamplerState sampler_SmokeTex3D;
            Texture2D _SmokeMask;
            SamplerState sampler_SmokeMask;
            Texture3D _HighFreqNoise;
            SamplerState sampler_HighFreqNoise;
            Texture3D _ColorLUT3D;
            SamplerState sampler_ColorLUT3D;

            CBUFFER_START(UnityPerMaterial)
                // 或者使用 RenderSettingsUniforms
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
                float _DetailStrength;
                int _DebugRenderMode;
                float3 _WindOffset;
                float _FogAmount;
                float _FogStartDistance;
                float _AnimationSpeed;
                int _ResolutionDivisor;
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
                float3 _CameraUp;
                float3 _CameraRight;
                float _CameraNearPlane;
                float _CameraFarPlane;
            CBUFFER_END

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

            CBUFFER_END

            float _VolumeSize;
            float _SmokeInterpolationT;
            float4 _BlueNoiseTex2D_TexelSize;

            struct FragmentOutput
            {
                float OpticalDepth : SV_Target0;
                float2 Moments : SV_Target1;
                float4 HigherMoments : SV_Target2;
                float4 SmokeColor : SV_Target3;
                float2 DepthRange : SV_Target4;
                float alpha : SV_Target5;
            };

            float computeRayStartJitter(float baseStepSize, float jitterNoise, float time, float tNear)
            {
                float jitterValue = frac(jitterNoise + (time * 0.618034));
                float distanceFactor = lerp(0.1, 0.8, 
                                           clamp((tNear + VOXEL_WORLD_SIZE * 20), 0.0, 1.0));
                return (baseStepSize * jitterValue * _TemporalJitterAmount) * distanceFactor;
            }
            
            float4 SampleAndProcessNoise(float3 coord, float3 offsetBase)
            {
                // ------------------------------------------
                // 1. 坐标变换 & 采样
                // ------------------------------------------
                float3 noiseUVW = (abs(coord) - offsetBase) * 0.07;

                // 采样 (使用 SampleLevel 确保在流控制中正确)
                float4 rawSample = _HighFreqNoise.SampleLevel(sampler_HighFreqNoise, noiseUVW, 0);

                // 应用 Pow
                float4 noiseSample = pow(rawSample, _NoiseWeight);

                // ------------------------------------------
                // 2. 复杂的混合逻辑 (Cloud Shaping)
                // ------------------------------------------
                float4 lowFreqParams = _CloudDensity;
                float4 highFreqParams = _CloudCoverage;
                float4 noiseBlend = _AnimationSpeed;

                // 第一层 Lerp: 在密度和覆盖度之间混合
                float4 layer1 = lerp(lowFreqParams, highFreqParams, noiseSample);

                // 第二层 Lerp: 在固定常数之间混合 (0.25 到 -1.5)
                float4 layer2 = lerp(float4(0.25, 0.25, 0.25, 0.25), float4(-1.5, -1.5, -1.5, -1.5), noiseSample);

                // 最终混合
                return lerp(layer1, layer2, noiseBlend);
            }

            v2f vert(appdata input)
            {
                v2f output;
                float2 uv = float2((input.vertexID << 1) & 2, input.vertexID & 2);
                output.positionCS = float4(uv * 2.0 - 1.0, 0.0, 1.0);
                output.uv = uv;

                #if UNITY_UV_STARTS_AT_TOP
                output.uv.y = 1.0 - output.uv.y;
                #endif

                return output;
            }

            FragmentOutput frag(v2f input) : SV_Target
            {
                FragmentOutput output;
                output.OpticalDepth = 0.0;
                output.Moments = float2(0, 0);
                output.HigherMoments = float4(0, 0, 0, 0);
                output.SmokeColor = float4(0, 0, 0, 0.0);
                output.DepthRange = float2(0, 0);
                
                // sample the smokeMask
                uint rawSmokeMask = (SAMPLE_TEXTURE2D(_SmokeMask, sampler_SmokeMask, input.uv).r);

                // if no smoke is hit by this fragment, discard
                if (rawSmokeMask == 0)
                    discard;

                float rawDepth = SampleSceneDepth(input.uv);
                
                // sample the depth of the scene

                // calculate the ndc position of the scene of this fragment
                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );
                

                float4 worldPos = mul(_InvVP, ndc);
                // calculate the worldPosition of the scene of this fragment in world space
                float3 worldPosition = worldPos.xyz / worldPos.w;

                // from camera to the worldPosition
                float3 rayDirection = normalize(worldPosition - _CameraPosition);

                float tNear, tFar;

                bool isHitScene = AABBIntersect(
                    sceneAABBMin,
                    sceneAABBMax,
                    _CameraPosition,
                    rayDirection,
                    tNear,
                    tFar
                );

                if (!isHitScene)
                {
                    discard;
                }

                                output.SmokeColor = float4(rawDepth,rawDepth,rawDepth,1.0f);
                return output;
                

                float baseStepDistance = _BaseStepSize * 1.5;
                int2 screenPixelCoord = int2(input.positionCS.xy);

                int2 noiseTextureSize = int2(_BlueNoiseTex2D_TexelSize.zw);
                int2 noiseMask = noiseTextureSize - 1;
                int2 noiseCoord = (screenPixelCoord / 1) & noiseMask;
                float blueNoiseSample = _BlueNoiseTex2D.Load(int3(noiseCoord, 0)).r;

                float rayStartJitter = computeRayStartJitter(_BaseStepSize, blueNoiseSample, _Time.y, tNear);

                float rayStartDistance = max(tNear, 0.5) + rayStartJitter;
                
                float linearSceneDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float rayDotCameraForward = dot(_CameraForward, rayDirection);
                float sceneDepthAlongRay = linearSceneDepth / rayDotCameraForward;

                float3 negativeRayDir = (-rayDirection).xyz;
                float3 backProjectedPoint = _CameraPosition.xyz +
                (negativeRayDir * (1.0 / (linearSceneDepth *
                    dot(_CameraForward.xyz, negativeRayDir))));

                bool hasExplosionLayer = enableExplosions > 0u;
                bool skipDueToOcclusion = false;

                float rayMarchEnd = sceneDepthAlongRay;

                if (rayStartDistance > rayMarchEnd)
                {
                    discard;
                }

                float3 marchStartWorldPos = _CameraPosition + (rayDirection * rayStartDistance);
                float3 marchEndWorldPos = _CameraPosition + (rayDirection * min(tFar, rayMarchEnd));

                uint activeVolumeMask = (uint)_SmokeMask.Load(int3(screenPixelCoord, 0)).x;

                if (activeVolumeMask == 0u)
                {
                    discard;
                }

                VolumeBoxData activeVolumeBoxes[1];

                uint activeVolumeCount = 0u;
                uint currentVolumeBit = activeVolumeMask;
                uint volumeIndex = 0u;

                while (currentVolumeBit != 0u && activeVolumeCount < MAX_SMOKE_COUNT)
                {
                    if ((currentVolumeBit & 1u) != 0u)
                    {
                        float3 minBounds = volumeMinBounds[volumeIndex].xyz;
                        float3 maxBounds = volumeMaxBounds[volumeIndex].xyz;

                        float tMin, tMax;

                        if (AABBIntersect(
                            minBounds,
                            maxBounds,
                            _CameraPosition,
                            rayDirection,
                            tMin,
                            tMax
                        ))
                        {
                            float tRayStart = max(0.0, tMin);
                            {
                                activeVolumeBoxes[activeVolumeCount].tMin = tRayStart;
                                activeVolumeBoxes[activeVolumeCount].tMax = tMax;
                                activeVolumeBoxes[activeVolumeCount].index = int(volumeIndex);
                                activeVolumeCount++;
                            }
                        }
                    }
                    currentVolumeBit >>= 1;
                    volumeIndex++;
                }

                VolumeBoxData volumeBoxList[1] = activeVolumeBoxes;

                // start marching at the tMin
                if (activeVolumeCount > 0)
                {
                    float smokeStart = volumeBoxList[0].tMin;
                    rayStartDistance = max(rayStartDistance, smokeStart);
                }

                float totalMarchDistance = length(marchEndWorldPos - marchStartWorldPos);
                int maxStepCount = int(clamp(ceil(totalMarchDistance / baseStepDistance) + 10.0, 1.0, 500.0));

                uint validVolumeCount = min(activeVolumeCount, 1u);

                float3 cameraSideVector = cross(_CameraForward, _CameraUp);
                float totalRayDistance = rayStartDistance + totalMarchDistance;

                float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0);
                float3 accumulatedTracerDirection = float3(0.0, 0.0, 0.01);
                float3 currentMarchPos = marchStartWorldPos;
                float3 currentVolumePos = marchEndWorldPos;
                float3 lastValidSamplePos = marchEndWorldPos;

                float accumulatedLightEnergy = 0.0;
                float accumulatedFogDensity = 0.0;
                float accumulatedTracerGlow = 0.0;
                uint tracerAnimationCounter = 0u;
                float currentRayDistance = rayStartDistance;

                bool foundOpaqueVolume = false;
                bool hasValidSample = false;
                bool hadPreviousSample = false; // 修复: 添加独立的布尔变量
                int stepIndex = 0;

                for (; stepIndex < maxStepCount; stepIndex++)
                {
                    bool shouldUpdateTracerAnim = false;
                    if (activeTracerCount > 0u)
                    {
                        shouldUpdateTracerAnim = ((stepIndex & 15) == 0) || (stepIndex < 16);
                    }

                    float tracerGlowIntensity = shouldUpdateTracerAnim ? 0.0 : accumulatedTracerGlow;
                    float tracerCavityStrength = shouldUpdateTracerAnim ? 0.0 : accumulatedTracerDirection.z;
                    uint tracerAnimBits = shouldUpdateTracerAnim ? 0u : tracerAnimationCounter;

                    float3 samplePosition = lastValidSamplePos;
                    float4 stepColor = accumulatedColor;
                    float3 stepTracerDir = shouldUpdateTracerAnim ? float3(0.0, 0.0, 0.01) : accumulatedTracerDirection;

                    uint volumeCheckIndex = 0u;
                    float stepLightEnergy = accumulatedLightEnergy;
                    float stepFogDensity = accumulatedFogDensity;
                    float stepTracerGlow = tracerGlowIntensity;
                    float stepCavityStrength = tracerCavityStrength;
                    uint stepTracerBits = tracerAnimBits;

                    bool innerLoopBreak = false;
                    for (; volumeCheckIndex < validVolumeCount; volumeCheckIndex++)
                    {
                        // 检查当前位置是否在体积包围盒内
                        if (currentRayDistance < volumeBoxList[volumeCheckIndex].tMin)
                        {
                            break; // 在包围盒前面
                        }
                        if (currentRayDistance > volumeBoxList[volumeCheckIndex].tMax)
                        {
                            break; // 在包围盒后面
                        }

                        float3 tracerDirection = stepTracerDir;
                        uint updatedTracerBits = stepTracerBits;
                        float updatedCavityStrength = stepCavityStrength;
                        float updatedTracerGlow = stepTracerGlow;

                        uint currentVolumeIdx = uint(volumeBoxList[volumeCheckIndex].index);

                        float3 tracerOffsetSamplePos = currentMarchPos + ((normalize(tracerDirection) * pow(
                            updatedCavityStrength, 3.0)) * VOXEL_WORLD_SIZE);
                        int volumeIntIdx = int(currentVolumeIdx);
                        float3 volumeLocalPos;
                        float3 volumeUVW = GetVolumeUVW(tracerOffsetSamplePos, volumeCenters[volumeIntIdx], volumeLocalPos);
                        float sampledDensityMin, sampledDensityMax;

                        uint densityPageIndex = uint(volumeAnimState[currentVolumeIdx].z);
                        float densityUOffset = VOXEL_RESOLUTION * densityPageIndex;

                        float4 densityLookup = SampleSmokeTexture(volumeUVW, _SmokeTex3D, sampler_SmokeTex3D,
                                                                volumeIntIdx, volumeAnimState[currentVolumeIdx].y,
                                                                sampledDensityMin, sampledDensityMax);

                        float distanceToMarchEnd = distance(tracerOffsetSamplePos, marchEndWorldPos);

                        float adjustedDensity;
                        if (sampledDensityMin > sampledDensityMax)
                        {
                            adjustedDensity = lerp(sampledDensityMax, sampledDensityMin, smoothstep(VOXEL_WORLD_SIZE / 2, VOXEL_WORLD_SIZE * 2, distanceToMarchEnd));
                        }
                        else
                        {
                            adjustedDensity = sampledDensityMax;
                        }

                        float cavityDensity = clamp(lerp(adjustedDensity, -0.05, updatedCavityStrength), 0.0, 1.0);

                        if (cavityDensity > 0.01)
                        {
                            float occlusionDistance = max(0.0, distanceToMarchEnd - min( VOXEL_RESOLUTION, abs(backProjectedPoint.z - volumeCenters[volumeIntIdx].z) * 2.0));
                            float densityMultiplier = clamp((cavityDensity - 0.01) * 1.0101, 0.0, 1.0);
                            float scaledDensity = densityMultiplier * volumeFadeParams[currentVolumeIdx].x;
                            float cameraDist = distance(_CameraPosition, tracerOffsetSamplePos);
                            float cameraDistFactor = 1.0 - clamp(cameraDist * 0.1, 0.0, 1.0);
                            float finalScaledDensity = clamp(scaledDensity + (cameraDistFactor * scaledDensity), 0.0,1.0);

                            float3 shadowTestPos = tracerOffsetSamplePos;
                            float shadowAmount = 0.0;
                            float shadowMultiplier = 1.0;

                            // 爆炸层处理 (暂时跳过)
                            if (hasExplosionLayer)
                            {
                                // TODO: 爆炸层逻辑
                            }

                            float effectiveDensity = hasExplosionLayer ? lerp(finalScaledDensity * 0.02, finalScaledDensity, shadowMultiplier) : finalScaledDensity;

                            float animTime = _Time.y * _AnimationSpeed;
                            float3 volumeCenteredPos = volumeLocalPos - float3(0.5, 0.5, 0.5);
                            float3 noiseCoord = volumeCenteredPos * 7.0;
                            float noiseZ = noiseCoord.z;

                            float rotAngle1 = animTime * 0.5;
                            float rotOffset = animTime * 0.04 +
                            (((0.2 + ((sin(noiseZ * 5.0) + 0.5) * 0.15)) *
                                    sin(rotAngle1 + 0.5)) *
                                sin((animTime * 0.187) + 0.5)) * 0.2;

                            float sinRot, cosRot;
                            sincos(rotOffset, sinRot, cosRot);

                            float2x2 rotMat = float2x2(cosRot, -sinRot, sinRot, cosRot);

                            float2 rotatedXY = mul(rotMat, noiseCoord.xy);

                            noiseCoord.x = rotatedXY.x;
                            float noiseY = rotatedXY.y;

                            float waveTime = animTime + (sin(rotAngle1) * 0.02);
                            float2 waveOffset = float2(sin(waveTime + (noiseZ * 2.7)),
                                                          cos(waveTime + (rotatedXY.x * 2.7))) * 0.05;
                            noiseCoord.xz = noiseCoord.xz + waveOffset;

                            float verticalWave = sin((noiseCoord.x * 3.0) + (animTime * 0.35)) +
                                sin((noiseY * 2.84) + (animTime * 0.235));
                            noiseCoord.z = noiseCoord.z + (verticalWave * 0.05);

                            float3 baseNoiseCoord = noiseCoord * _BaseNoiseScale;
                            float3 offsetBase = float3(2.0, 2.0, 4.5) * (animTime * 0.1);

                            float3 camUpOffset = _CameraUp * 0.2;
                            float3 camSideOffset = cameraSideVector * 0.2;

                            float4 noisePower = float4(_NoiseWeight, _NoiseWeight, _NoiseWeight, _NoiseWeight);
                            float3 noiseUVW = (abs(baseNoiseCoord) - offsetBase) * 0.07;
                            float4 rawNoiseSample = _HighFreqNoise.SampleLevel(sampler_HighFreqNoise, noiseUVW, 0);
                            float4 baseNoiseSample = pow(rawNoiseSample, _NoiseWeight);

                            float4 lowFreqParams = float4(_CloudDensity, _CloudDensity, _CloudDensity, _CloudDensity);
                            float4 highFreqParams = float4(_CloudCoverage, _CloudCoverage, _CloudCoverage,
                                                             _CloudCoverage);
                            float4 noiseBlend = float4(_AnimationSpeed, _AnimationSpeed, _AnimationSpeed,
                                     _AnimationSpeed);

                            float4 baseNoiseProcessed = SampleAndProcessNoise(baseNoiseCoord, offsetBase);

                            float baseNoiseCombined = (baseNoiseProcessed.x +
                                (baseNoiseProcessed.y * 0.95)) * 4.6;

                            float4 normalProcessedX = SampleAndProcessNoise(baseNoiseCoord + camUpOffset, offsetBase);
                            float4 normalProcessedY = SampleAndProcessNoise(baseNoiseCoord + camSideOffset, offsetBase);
                            float normalGradStep = 0.8 / _BaseNoiseScale;

                            float3 noiseNormal = normalize(float3(
                                baseNoiseCombined - ((normalProcessedY.x +
                                    (normalProcessedY.y * 0.95)) * 4.6),
                                baseNoiseCombined - ((normalProcessedX.x +
                                    (normalProcessedX.y * 0.95)) * 4.6),
                                normalGradStep));

                            float4x4 viewTransform = _ViewMatrix;

                            float3 distortionDir = noiseNormal + float3(0.0, 0.0, 1.0);
                            float3 viewSpaceDistortion = mul(viewTransform, float4(distortionDir, 0.0)).xyz;
                            float3 offsetLayer1 = viewSpaceDistortion * pow(max(0.001, baseNoiseCombined), 0.1) *
                                _DetailStrength * 0.2;

                            float3 detailNoiseCoord = noiseCoord + offsetLayer1;
                            float3 offsetLayer2 = float3(2.0, 2.0, 4.5) * ((baseNoiseCombined - 1.0) * 0.2) *
                                _DetailStrength * volumeCenteredPos.z;

                            detailNoiseCoord += offsetLayer2;

                            detailNoiseCoord.x += sin(noiseCoord.z + (animTime * 0.25)) * 0.05;
                            float3 detailScaledCoord = detailNoiseCoord * _DetailNoiseScale;
                            float4 detailProcessed = SampleAndProcessNoise(detailScaledCoord, 0.0);
                            float detailNoiseCombined = (detailProcessed.x + (detailProcessed.y * 0.95)) * 4.6;

                            float4 detailNormalProcX = SampleAndProcessNoise(detailScaledCoord, camUpOffset);
                            float4 detailNormalProcY = SampleAndProcessNoise(detailScaledCoord, camSideOffset);

                            float depthFade = _ScatteringCoeff *
                            (dot(rayDirection, _CameraForward) *
                                clamp(distance(shadowTestPos, _CameraPosition) * 0.005,
                                                                      0.0, 1.0));

                            float combinedNoise = (lerp(0.95, clamp(baseNoiseCombined, 0.0, 1.0),
                                    _AbsorptionCoeff) +
                                    lerp(0.95, clamp(detailNoiseCombined, 0.0, 1.0),
                                                              depthFade * 0.25)) +
                                _AmbientLight;

                            float heightFade = 1.0;
                            if (volumeFadeParams[currentVolumeIdx].w < 1.0)
                            {
                                float heightParam = clamp(volumeFadeParams[currentVolumeIdx].w, 0.0001, 0.99989998);
                                float fadeStart = smoothstep(0.0, 0.8, heightParam);
                                float fadeEnd = smoothstep(0.2, 1.0, heightParam);

                                if (fadeStart != fadeEnd)
                                {
                                    float3 heightTestPos = volumeCenteredPos;
                                    heightTestPos.z = heightTestPos.z * 1.2;
                                    float heightDist = clamp(length(heightTestPos), 0.0, 1.0);
                                    heightFade = effectiveDensity * clamp(
                                        smoothstep(fadeStart, fadeEnd, heightDist), 0.0, 1.0);
                                }
                                else
                                {
                                    heightFade = effectiveDensity * heightParam;
                                }
                            }
                            else
                            {
                                heightFade = effectiveDensity;
                            }

                            float stepDensity = lerp(heightFade - (1.0 - combinedNoise),
                             heightFade + combinedNoise,
                             heightFade) *
                                clamp((volumeFadeParams[currentVolumeIdx].x * volumeFadeParams[currentVolumeIdx].w) * 8.0, 0.0, 1.0);

                            // 如果密度太低，跳过
                            if (stepDensity < 0.0001)
                            {
                                continue;
                            }

                            float3 baseNormalDir = normalize(volumeCenteredPos) * lerp(
                                1.0, 0.0, clamp(shadowAmount, 0.0, 1.0));
                            float3 viewSpaceBaseNormal = mul(float4(baseNormalDir, 0.0), viewTransform).xyz;
                            float detailValY = (detailNormalProcY.x + detailNormalProcY.y * 0.95) * 4.6;
                            float detailValX = (detailNormalProcX.x + detailNormalProcX.y * 0.95) * 4.6;

                            float3 detailGradientRaw = float3(
                                detailNoiseCombined - detailValY,
                                detailNoiseCombined - detailValX,
                                normalGradStep
                            );

                            float detailMixWeight = lerp(0.5, 1.0, saturate(baseNoiseCombined - 0.5));

                            float3 detailPerturb = normalize(detailGradientRaw).xyz;

                            float2 detailPerturbXY = detailPerturb.xy * detailMixWeight * (depthFade * 1.5);

                            float2 combinedNoisePerturb = (noiseNormal.xy * _AbsorptionCoeff) + detailPerturbXY;

                            float distToCenter = distance(shadowTestPos, volumeCenters[volumeIntIdx].xyz);
                            float distScale = lerp(1.0, 2.0, saturate((200.0 - distToCenter) * 0.005));

                            float3 finalPerturbationVector = float3(combinedNoisePerturb, 0.0) * _PhaseFunction *
                                distScale;

                            float3 combinedViewNormal = viewSpaceBaseNormal + finalPerturbationVector;

                            float4 normalTransform = mul(float4(combinedViewNormal, 0.0), viewTransform);

                            float3 finalNormal = normalTransform.xyz;

                            float normalDotProduct = dot(baseNormalDir, finalNormal);

                            // 混合的第一个值：体积中心位置缩放
                            float3 scaledVolumePosA = volumeCenteredPos * normalDotProduct;

                            // 混合的第二个值：偏移并归一化的法线
                            float3 offsetNormal = finalNormal + float3(0.0, 0.0, 0.5);
                            float3 normalizedOffset = normalize(offsetNormal);
                            float volumeDistance = length(volumeCenteredPos);
                            float3 scaledVolumePosB = normalizedOffset * volumeDistance;

                            // 在两个值之间插值（权重0.2）
                            float3 mixedPosition = lerp(scaledVolumePosA, scaledVolumePosB, 0.2);

                            // 添加0.5的偏移
                            float3 offsetPosition = mixedPosition + float3(0.5, 0.5, 0.5);

                            // 第一次限制：0.03 到 0.97
                            float3 clampedOnce = clamp(offsetPosition, float3(0.03, 0.03, 0.03),
                                                               float3(0.97, 0.97, 0.97));

                            // 第二次限制：0.0 到 1.0（确保在有效UV范围内）
                            float3 scatterUVW = clamp(clampedOnce, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));

                            scatterUVW.z = (densityUOffset + (scatterUVW.z * VOXEL_RESOLUTION)) * ATLAS_DEPTH_INV;

                            // 修复: 启用 ColorLUT 采样
                            float4 scatterColor = _ColorLUT3D.SampleLevel(sampler_ColorLUT3D, scatterUVW, 0.0);

                            Light mainLight = GetMainLight();
                            float3 sunDirection = mainLight.direction;

                            float3 phaseNormal = lerp(baseNormalDir, finalNormal, _PhaseFunction);

                            float sunDot = dot(phaseNormal, sunDirection);

                            float phaseForward = pow(saturate((sunDot * 0.8) + 0.2), 1.5);
                            float phaseBack = pow(saturate((sunDot * 1.4) - 0.5), 3.0);

                            float totalPhase = phaseForward + phaseBack;

                            float sunScattering = (totalPhase > 0.0) ? (totalPhase * scatterColor.w) : totalPhase;

                            float3 finalRGB = EnhanceColorSaturation(scatterColor);

                            float3 litColor = (((((((normalize(finalRGB + float3(0.001, 0.001, 0.001)) *
                                                            min(length(finalRGB), 4.0)) *
                                                        clamp(1.0 - min(0.25, stepDensity), 0.0, 1.0)) *
                                                    clamp(1.0 - (((heightFade * 2.4) - stepDensity) *
                                                        _CloudTopHeight), 0.0, 1.0)) *
                                                combinedNoise) *
                                            (0.75 + (sunScattering * 0.25))) *
                                        (1.0 + (normalTransform.z * 0.5))) *
                                    _CloudDensity) +
                                ((mainLight.color.xyz *
                                        ((0.5 * sunScattering) * (1.0 - updatedCavityStrength))) *
                                    _CloudCoverage);

                            float3 volumeTintedColor = litColor * volumeTintColor[currentVolumeIdx].xyz;

                            float luminance = dot(litColor, float3(0.2126, 0.7152, 0.0722));
                            float tintedLuminance = dot(volumeTintedColor + float3(0.001, 0.001, 0.001),
                                float3(0.2126, 0.7152, 0.0722));
                            float saturationBlend = 0.5 * (1.0 - volumeFadeParams[currentVolumeIdx].z);

                            float3 desaturatedColor = lerp(litColor,
                                      volumeTintedColor * (luminance / tintedLuminance),
                                      float3(saturationBlend, saturationBlend, saturationBlend));
                            float3 windTintedColor = lerp(desaturatedColor,
                                                            desaturatedColor *
                                                            normalize(_WindOffset + float3(0.01, 0.01, 0.01)) * 1.732,
                                                            float3(clamp(0.5 + (stepDensity * 6.0), 0.0, 1.0),
                                              clamp(0.5 + (stepDensity * 6.0), 0.0, 1.0),
                                              clamp(0.5 + (stepDensity * 6.0), 0.0, 1.0)));

                            float3 shadowedColor = lerp(windTintedColor,
                                windTintedColor * shadowMultiplier,
                                float3(0.6, 0.6, 0.6));

                            float fogAmount = smoothstep(0.0, 0.2, stepDensity + 0.3) *
                            (((clamp((_FogStartDistance - occlusionDistance) /
                                          _FogStartDistance, 0.0, 1.0) * heightFade) * 6.0) *
                                _FogAmount);

                            float stepAlpha = smoothstep(0.0, 0.2 / (_RayMarchStepScale * lerp(0.5, 2.0, stepColor.w)), stepDensity);

                            float3 litColorWithTracerGlow = (shadowedColor +
                                    ((shadowedColor * float3(8.0, 4.0, 0.0)) *
                                        shadowAmount)) *
                                lerp(1.0, 0.85, clamp(shadowAmount * 20.0, 0.0, 1.0));

                            float4 stepContribution = float4(litColorWithTracerGlow * stepAlpha, stepAlpha);

                            float sampleWeight = _BaseStepSize * 0.375;

                            while (sampleWeight >= 1.0)
                            {
                                stepFogDensity += fogAmount;
                                stepColor += stepContribution * (1.0 - stepColor.w);
                                stepLightEnergy += sunScattering;
                                sampleWeight -= 1.0;
                            }

                            stepLightEnergy += sunScattering * sampleWeight;
                            stepFogDensity += fogAmount * sampleWeight;
                            stepColor += stepContribution * ((1.0 - stepColor.w) * sampleWeight);

                            hasValidSample = (stepAlpha + fogAmount) > 0.0;
                        }

                        // 修复: 使用独立的布尔变量跟踪之前是否有有效采样
                        if (hasValidSample && !hadPreviousSample)
                        {
                            samplePosition = currentMarchPos;
                            hadPreviousSample = true;
                        }

                        if (stepColor.w > 0.991)
                        {
                            stepColor.w = 1.0;
                            foundOpaqueVolume = true;
                            innerLoopBreak = true;
                            break;
                        }
                    }
                    if (foundOpaqueVolume)
                    {
                        break;
                    }

                    float3 nextMarchPos = currentMarchPos + (rayDirection * baseStepDistance);
                    float nextRayDistance = currentRayDistance + baseStepDistance;

                    if (nextRayDistance >= totalRayDistance)
                    {
                        break;
                    }

                    accumulatedLightEnergy = stepLightEnergy;
                    accumulatedFogDensity = stepFogDensity;
                    accumulatedColor = stepColor;
                    accumulatedTracerGlow = stepTracerGlow;
                    accumulatedTracerDirection = stepTracerDir;
                    accumulatedTracerDirection.z = stepCavityStrength;
                    tracerAnimationCounter = stepTracerBits;
                    currentMarchPos = nextMarchPos;
                    currentRayDistance = nextRayDistance;
                    currentVolumePos = currentVolumePos;
                    lastValidSamplePos = samplePosition;
                }

                Light mainLight = GetMainLight();
                float3 sunDirection = mainLight.direction;
                float3 sunColor = mainLight.color;

                float sunDot = dot(normalize(rayDirection), sunDirection);

                float sunGlow = pow(saturate(sunDot), 4.0) * 0.25;

                float foggedDensity = saturate(accumulatedFogDensity - (accumulatedColor.w * 0.2));

                float4 foggedColor;

                if (_FogAmount == 0.0)
                {
                    foggedColor = accumulatedColor;
                }
                else
                {
                    // RGB: 随雾密度衰减 (变暗/被遮挡) -> color * (1.0 - density)
                    // Alpha: 随雾密度增加 (变厚) -> alpha + density

                    float3 foggedRGB = accumulatedColor.xyz * lerp(1.0, 0.0, foggedDensity);
                    float foggedAlpha = accumulatedColor.w + foggedDensity;

                    foggedColor = float4(foggedRGB, foggedAlpha);
                }

                float3 sunColorSquared = pow(sunColor, 2.0);
                float glowTerm = sunGlow + (pow(sunGlow, 50.0) * 8.0);
                float occlusionTerm = 1.0 - sqrt(saturate(accumulatedColor.w));
                float3 sunBloom = sunColorSquared * (glowTerm * occlusionTerm * accumulatedColor.w) * (
                    accumulatedLightEnergy * _DirectLightIntensity);
                float3 finalColor = foggedColor.xyz * (1.0 + sunBloom);
                float4 outputColor = foggedColor;
                outputColor.xyz = finalColor;
                float finalAlpha = foggedColor.w;

                if (finalAlpha < 0.00001)
                {
                    discard;
                }

                output.SmokeColor = outputColor;
                return output;
            }
            ENDHLSL
        }
    }
}
