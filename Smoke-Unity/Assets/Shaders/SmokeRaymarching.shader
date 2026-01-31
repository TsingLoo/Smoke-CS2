Shader "Unlit/SmokeRaymarching"
{
    Properties
    {
        [Header(Raymarching Core)]
        _BaseStepSize ("Base Step Size", Float) = 6.0
        _AlphaScale ("Alpha Scale", Float) = 0.85
        
        [Header(Noise)]
        _Noise1Scale ("Noise 1 Scale", Float) = 3.0
        _Noise2Scale ("Noise 2 Scale", Float) = 7.0
        _NoisePower ("Noise Power", Range(0.0, 2.0)) = 1.0
        _NoiseLowFreq ("Noise Low Freq", Float) = 0.0
        _NoiseHighFreq ("Noise High Freq", Float) = 1.05
        _NoiseMixFactor ("Noise Mix Factor", Range(0.0, 1.0)) = 0.0
        _Noise1Influence ("Noise 1 Influence", Range(0.0, 1.0)) = 0.5
        _DetailNoiseInfluence ("Detail Noise Influence", Range(0.0, 1.0)) = 0.35
        _NoiseOffset ("Noise Offset", Float) = 0.0
        
        [Header(Lighting)]
        _PhaseBlend ("Phase Blend", Range(0.0, 1.0)) = 0.5
        _BaseColorIntensity ("Base Color Intensity", Float) = 0.6
        _SunColorIntensity ("Sun Color Intensity", Float) = 0.35
        _RimLightIntensity ("Rim Light Intensity", Float) = 0.25
        _DensityContrast ("Density Contrast", Float) = 0.5
        _NormalPerturbScale ("Normal Perturb Scale", Float) = 0.5
        _NormalDetailScale ("Normal Detail Scale", Float) = -0.3
        
        [Header(Fog)]
        _GodrayIntensity ("Godray Intensity", Float) = 0.06
        _GodrayFalloffDist ("Godray Falloff Dist", Float) = 16.0
        _ColorTint ("Color Tint", Vector) = (1,1,1,0)
        
        [Header(Time)]
        _TimeScale ("Time Scale", Float) = 1.0
        
        [Header(Second Pass)]
        [Toggle] _EnableSecondPass ("Enable Second Pass", Int) = 1
        _DepthDownscaleFactor ("Depth Downscale Factor", Int) = 4

        _BlueNoiseTex2D ("Blue Noise 2D Texture", 2D) = "white" {}
        _HighFreqNoise ("High Freq Noise 3D Texture", 3D) = "white" {}
        _ColorLUT3D ("ColorLUT 3D Texture", 3D) = "white" {}

        _RawCS2SmokeDataTex3D ("Raw CS2 Smoke Tex3D" ,3D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline" = "UniversalPipeline"
        }

        ZWrite Off
        Cull Off
        ZTest LEqual
        Blend Off

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
            SamplerState smokeTex3D_trilinear_clamp_sampler;
            Texture2D _SmokeMask;
            SamplerState sampler_SmokeMask;
            Texture3D _HighFreqNoise;
            SamplerState sampler_HighFreqNoise;
            Texture3D _ColorLUT3D;
            SamplerState sampler_ColorLUT3D;

            Texture3D _RawCS2SmokeDataTex3D;
            SamplerState sampler_RawCS2SmokeDataTex3D;

            CBUFFER_START(RenderParamsBlock)
                float _AlphaScale;
                float _TimeScale;
                float _Noise1Influence;
                float _DetailNoiseInfluence;
                float _NormalPerturbScale;
                float _PhaseBlend;
                float _NoiseOffset;
                float _Noise1Scale;
                float _Noise2Scale;
                float _NoisePower;
                float _NoiseLowFreq;
                float _NoiseHighFreq;
                float _BaseColorIntensity;
                float _SunColorIntensity;
                float _RimLightIntensity;
                float _DensityContrast;
                float _BaseStepSize;
                float _NormalDetailScale;
                int _EnableSecondPass;
                float3 _ColorTint;
                float _GodrayIntensity;
                float _GodrayFalloffDist;
                float _NoiseMixFactor;
                int _DepthDownscaleFactor;
            CBUFFER_END
            
            CBUFFER_START(ScreenDataBlock)
                int2 _NoiseTileSize;
                float _LogDepthNear;
                float _LogDepthFar;
            CBUFFER_END

            CBUFFER_START(CameraParams)
                float4x4 _InvVP;
                float3 _CameraPosition;
                float _NearPlane;
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
                float4 outMoment0 : SV_Target0;
                float4 outMoment1 : SV_Target1;
                float4 outMoment2 : SV_Target2;
                float4 outSmokeColor : SV_Target3;
                float4 outDepthMinMax : SV_Target4;
                float outTransmittance : SV_Target5;
            };

            float4 sampleProcessedNoise(float3 coord, float4 powerVec, float4 lowFreq, float4 highFreq, float4 mixFactor)
            {
                float4 raw = pow(_HighFreqNoise.SampleLevel(sampler_HighFreqNoise, (coord * NOISE_TEXTURE_SCALE).xyz, 0.0), powerVec);
                return lerp(lerp(lowFreq, highFreq, raw), lerp(float4(SECOND_PASS_WEIGHT, SECOND_PASS_WEIGHT, SECOND_PASS_WEIGHT, SECOND_PASS_WEIGHT), float4(-1.5, -1.5, -1.5, -1.5), raw), mixFactor);
            }

            float combineNoiseChannels(float4 processed)
            {
                return (processed.x + (processed.y * NOISE_CHANNEL_WEIGHT)) * NOISE_COMBINE_MULTIPLIER;
            }

            void calculateTracerInfluence(float3 samplePos, inout float tracerGlow, inout float3 tracerDir, inout float cavityStrength)
            {
                for (uint i = 0u; i < min(activeTracerCount, MAX_TRACER_COUNT); i++)
                {
                    float3 lineDir = bulletTracerEnds[i].xyz - bulletTracerStarts[i].xyz;
                    float3 toStart = samplePos - bulletTracerStarts[i].xyz;
                    
                    float t = clamp(dot(toStart, lineDir) / dot(lineDir, lineDir), 0.0, 1.0);
                    float distToLine = clamp((length(toStart - (lineDir * t)) * NOISE_PERTURB_AMPLITUDE) * tracerInfluenceParams[i].x, 0.0, 1.0);
                    
                    float age = bulletTracerStarts[i].w;
                    float fade = smoothstep(0.0, MIN_DENSITY_THRESHOLD, age) * (1.0 - smoothstep(MIN_DENSITY_THRESHOLD, DISTORTION_AMPLITUDE, age));
                    
                    float spotGlow;
                    if (distToLine < 1.0)
                    {
                        float wind = max(cavityStrength, smoothstep(0.0, 1.0, 1.0 - clamp(age + clamp(distToLine + (1.0 - clamp(length(samplePos - bulletTracerEnds[i].xyz) * MIN_DENSITY_THRESHOLD, 0.0, 1.0)), 0.0, 1.0), 0.0, 1.0)));
                        tracerDir = lerp(tracerDir, normalize(bulletTracerStarts[i].xyz - bulletTracerEnds[i].xyz), float3(wind, wind, wind));
                        cavityStrength = wind;
                        spotGlow = (pow(1.0 - distToLine, TRACER_GLOW_POWER) * fade) * 10.0;
                    }
                    else
                    {
                        spotGlow = 0.0;
                    }
                    
                    if (bulletTracerEnds[i].w > 0.0)
                    {
                        float pointGlow = (1.0 - clamp(length(toStart) * MIN_DENSITY_THRESHOLD, 0.0, 1.0)) * fade;
                        tracerGlow = max(tracerGlow, max(pointGlow * pointGlow, spotGlow));
                    }
                }
            }

            void calculateDissipation(inout float3 samplePos, inout float dissipScale, inout float dissipAccum,
                                      float occlusionDist, uint volumeIdx, uint densityPageIdx, bool skipOcclusion)
            {
                for (uint i = 0u; i < min(enableExplosions, MAX_EXPLOSION_COUNT); i++)
                {
                    if ((uint(volumeTracerMasks[i >> uint(2)][i & 3u]) & (1u << densityPageIdx)) == 0u)
                        continue;
                    
                    float dissipAge = animationTime - explosionPositions[i].w;
                    if (dissipAge >= (volumeAnimState[volumeIdx].x - 0.4))
                        continue;
                    
                    float dist = distance(samplePos, explosionPositions[i].xyz);
                    if (dist >= EXPLOSION_MAX_DIST)
                        continue;
                    
                    float pulse = pow(1.0 - smoothstep(0.0, 2.0, dissipAge), EXPLOSION_PULSE_POWER);
                    float surfaceProx;
                    if (!skipOcclusion)
                        surfaceProx = clamp((SURFACE_PROX_THRESHOLD - occlusionDist) * SURFACE_PROX_SCALE, 0.0, 1.0) * (1.0 - smoothstep(0.0, NOISE_COORD_SCALE, dissipAge));
                    else
                        surfaceProx = dissipAccum;
                    
                    samplePos = lerp(samplePos, explosionPositions[i].xyz, float3(((1.0 - smoothstep(100.0, EXPLOSION_MAX_DIST, dist)) * step(dissipAge * TRACER_AGE_DIST_SCALE, dist)) * (1.0 - pulse), ((1.0 - smoothstep(100.0, EXPLOSION_MAX_DIST, dist)) * step(dissipAge * TRACER_AGE_DIST_SCALE, dist)) * (1.0 - pulse), ((1.0 - smoothstep(100.0, EXPLOSION_MAX_DIST, dist)) * step(dissipAge * TRACER_AGE_DIST_SCALE, dist)) * (1.0 - pulse)));
                    dissipScale = min(dissipScale, max(smoothstep(DISSIP_FADE_NEAR, DISSIP_FADE_FAR, dist + (pulse * EXPLOSION_MAX_DIST)) + pow(smoothstep(HALF, 5.0, dissipAge), 1.8), surfaceProx));
                    dissipAccum = surfaceProx;
                }
            }

            
            float computeRayStartJitter(float baseStepSize, float jitterNoise, float time, float tNear)
            {
                float baseStepDistance = baseStepSize * STEP_DISTANCE_MULTIPLIER;
                float animatedNoise = frac(jitterNoise + (time * 0.01 * GOLDEN_RATIO_FRACT));
                float distanceFactor = lerp(JITTER_MIN_BLEND, JITTER_MAX_BLEND, 
                                            saturate((tNear + JITTER_DIST_OFFSET) * JITTER_DIST_SCALE));
                return baseStepDistance * animatedNoise * distanceFactor * JITTER_SCALE;
            }

            
            float4x4 GetCameraToWorldMatrix()
            {
                // return float4x4(
                //         -0.41205,  0.00000,  0.91116,  1476.49414 * RAW_CS2_DISTANCE_TO_UNITY, // X 分量
                //          0.90812,  0.08170,  0.41067,   729.77344 * RAW_CS2_DISTANCE_TO_UNITY, // Y 分量 (CS2 的 Z)
                //         -0.07444,  0.99666, -0.03366,    44.49789 * RAW_CS2_DISTANCE_TO_UNITY, // Z 分量 (CS2 的 Y)
                //          0.00000,  0.00000,  0.00000,     1.00000
                //     );

                return UNITY_MATRIX_I_V;;
            }


            bool sampleVolume(
                float3 currentMarchPos,
                float3 marchEndPos,
                float3 backProjectedPoint,
                float3 rayDirection,
                float3 cameraSideVector,
                uint volumeIdx,
                float densityUOffset,
                uint densityPageIdx,
                float tracerGlow,
                float3 tracerDir,
                float cavityStrength,
                bool hasExplosionLayer,
                bool skipDueToOcclusion,
                float weightBase,
                float weightMultiplier, 
                inout float4 stepColor,
                inout float stepLightEnergy,
                inout float stepFogDensity)
            {
                //currentMarchPos = float3(-282.625, -119.25, -1783.00) * RAW_CS2_DISTANCE_TO_UNITY;
	            //marchEndPos = float3(-621.00, -23.84375, -2000.00) * RAW_CS2_DISTANCE_TO_UNITY;
	            //backProjectedPoint = float3(-835, -39.3125, -1883) * RAW_CS2_DISTANCE_TO_UNITY;
	            //rayDirection = float3(-0.99756, 0.06525, -0.01563);
	            //cameraSideVector = float3(-0.41187, 0.00, 0.91113 );

                // return true;

                //float3 cameraForwardVector = float3(-0.90812, -0.0817, - 0.41067);
                //float3 cameraRightVector = float3(-0.07444, 0.99666, -0.03366);
                float3 cameraForwardVector = UNITY_MATRIX_I_V[2].xyz;
                float3 cameraRightVector = UNITY_MATRIX_I_V[1].xyz;
    
                //float3 cameraPositionVector = float3(-51.2271, -103.96875, -1643.52405);
                
                int volumeIdxInt = int(volumeIdx);
                
                // Apply tracer offset to sample position
                float3 tracerOffsetSamplePos = currentMarchPos + ((normalize(tracerDir) * pow(cavityStrength, PHASE_POWER_2)) * TRACER_OFFSET_SCALE);
                tracerOffsetSamplePos = currentMarchPos;

                //tracerOffsetSamplePos = float3(-282.625, -119.25 , -1783.0) * RAW_CS2_DISTANCE_TO_UNITY;
                //tracerOffsetSamplePos = float3(-282.625 , -1783.0 , -119.25) * RAW_CS2_DISTANCE_TO_UNITY;

                float3 volumeCenter = volumeCenters[volumeIdxInt].xyz;
                //volumeCenter = float3(-381.0, -173.875, -1835.0) * RAW_CS2_DISTANCE_TO_UNITY;
                //volumeCenter = float3(-381.0, -173.875 , -1835.0) * RAW_CS2_DISTANCE_TO_UNITY;
	            //return true;

                float3 halfway = (tracerOffsetSamplePos - volumeCenter) * float3(WORLD_POS_TO_VOXEL_COORD,WORLD_POS_TO_VOXEL_COORD,WORLD_POS_TO_VOXEL_COORD);
                
                float3 volumeLocalPos = clamp((halfway + float3(VOLUME_CENTER_OFFSET,VOLUME_CENTER_OFFSET,VOLUME_CENTER_OFFSET)) * float3(VOLUME_UVW_SCALE,VOLUME_UVW_SCALE,VOLUME_UVW_SCALE), float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));

                // float3 volumeLocalPos = (((tracerOffsetSamplePos - volumeCenters[volumeIdxInt].xyz) * float3(VOXEL_WORLD_SIZE_INV,VOXEL_WORLD_SIZE_INV,VOXEL_WORLD_SIZE_INV))
                //     + float3(VOLUME_CENTER_OFFSET,VOLUME_CENTER_OFFSET,VOLUME_CENTER_OFFSET)) * float3(VOLUME_UVW_SCALE,VOLUME_UVW_SCALE,VOLUME_UVW_SCALE);

                //stepColor = float4(currentMarchPos.x, currentMarchPos.y, currentMarchPos.z, 1.0f);
                //return true;
                
                float3 volumeUVW = volumeLocalPos;

                

                //stepColor = DEBUG_PINK_COLOR;
                //return true;
                
                // if (any(volumeLocalPos) > 1.0 )
                // {
                //     stepColor = DEBUG_PINK_COLOR;
                //     return true;
                // }
                
                //volumeUVW.x = (densityUOffset + (volumeUVW.x * SINGLE_VOLUME_TILE_SIZE)) * DENSITY_ATLAS_WIDTH_INV;

                //stepColor = float4(volumeUVW.x, volumeUVW.y, volumeUVW.z, 1.0f);
                //stepColor = float4(normalize(float3(0.00, 1.0, 0.75195)).x, normalize(float3(0.00, 1.0, 0.75195)).y, normalize(float3(0.00, 1.0, 0.75195)).z, 1.0f);
                //return true;
                
                //float3 volumeLocalPos;

                //GetVolumeLocalUVW(tracerOffsetSamplePos, volumeCenters[volumeIdxInt].xyz, volumeLocalPos);
                
                //float3 volumeLocalPos = clamp((((tracerOffsetSamplePos - volumeCenters[volumeIdxInt].xyz) * float3(VOLUME_LOCAL_SCALE, VOLUME_LOCAL_SCALE, VOLUME_LOCAL_SCALE)) + float3(VOLUME_CENTER_OFFSET, VOLUME_CENTER_OFFSET, VOLUME_CENTER_OFFSET)) * float3(VOXEL_RESOLUTION_INV, VOXEL_RESOLUTION_INV, VOXEL_RESOLUTION_INV), float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));

                //float3 volumeUVW = volumeLocalPos;

                float4 densitySample;
                // Sample density

                //CS2 Data
                //volumeUVW.x = densityUOffset + (volumeLocalPos.x * 32.0 ) * 0.0018450184725224971771240234375;
                //densitySample = _RawCS2SmokeDataTex3D.SampleLevel(sampler_RawCS2SmokeDataTex3D, volumeUVW.xyz, 0.0);

                //stepColor = float4(volumeUVW.x, volumeUVW.y, volumeUVW.z, 1.0f);
                //stepColor = float4(0.05, 0.05, 0.05, 1.0f);
                //stepColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
                //stepColor = float4(1.0f , 0.2f, 0.1f, 1.0f);
                //return true;
                
                volumeUVW.x = (densityUOffset + (volumeLocalPos.x * SINGLE_VOLUME_TILE_SIZE)) * DENSITY_ATLAS_WIDTH_INV;

                
                
                //there is some float error right now. 
                //stepColor = float4(volumeUVW.x,volumeUVW.y, volumeUVW.z , 1.0f);
                //return true;

                //
                //volumeUVW = float3(0.03857, 0.58496, 1 - 0.58105);
                //volumeUVW = float3(0.0221, 0.5313, 15.0/ 32.0);

                //volumeUVW = float3(17.5/542.0, 20.5/ 32.0, 15.5/32.0);


                
                densitySample = _RawCS2SmokeDataTex3D.SampleLevel(sampler_RawCS2SmokeDataTex3D, volumeUVW.xyz, 0.0);
                //int3 texelCoord = int3(17, 20, 15);
                //densitySample = _RawCS2SmokeDataTex3D.Load(int4(texelCoord, 0));
                //stepColor = float4(0.5, 0.2, 0.3, 1.0f);
                //stepColor =  pow(densitySample.rgba, 1.0 / 2.2);;
                //stepColor = LinearToSRGB(densitySample) ;
                //stepColor = LinearToSRGB(0.23621);
                //stepColor =  PositivePow(0.23621, 1.0 / 2.4);
                //stepColor =  densitySample;
                //stepColor = float4(0.5, 0.2, 0.3, 1.0f);
                //return true;

                //stepColor = densitySample;
                //return true;
                 

                //stepColor = float4(1.0, 0.0, 1.0, 1.0);
                //stepColor = densitySample.xyzw;
                //return  true;
                //return true;
                
                //float2 densityChannels = lerp(densitySample.xz, densitySample.yw, float2(volumeAnimState[volumeIdx].y, volumeAnimState[volumeIdx].y));
                float2 densityChannels = lerp(densitySample.xz, densitySample.yw, float2(volumeAnimState[volumeIdx].y, volumeAnimState[volumeIdx].y));
                float sampledDensityMin = densityChannels.x;
                
                // if(sampledDensityMin < 0.005){
		              //   stepColor = float4(1.0f, 0.2f, 0.2f, 1.0f);
                //         return false;
                // }
                
                float sampledDensityMax = densityChannels.y;

                //stepColor = sampledDensityMin;
                //return false;
                
                float distanceToMarchEnd = distance(tracerOffsetSamplePos, marchEndPos);
                
                
                float adjustedDensity = sampledDensityMax;

                //stepColor = float4(sampledDensityMax,sampledDensityMax, sampledDensityMax, 1.0f);
	            //return true;    

                
                if (sampledDensityMin > sampledDensityMax)
                    adjustedDensity = lerp(sampledDensityMax, sampledDensityMin, smoothstep(DENSITY_BLEND_NEAR, DENSITY_BLEND_FAR, distanceToMarchEnd));
                
                float cavityDensity = clamp(lerp(adjustedDensity, -VOLUME_WORLD_SIZE_INV, cavityStrength), 0.0, 1.0);

                //stepColor = float4(cavityDensity,cavityDensity, cavityDensity, 1.0f);
	            //return true;    
                
                if (cavityDensity <= MIN_DENSITY_THRESHOLD )
                    //stepColor = DEBUG_PINK_COLOR;
                    return false;

                //stepColor = float4(cavityStrength,cavityStrength, cavityStrength, 1.0f);
	            //return true;    

                //stepColor = float4(sampledDensityMin,sampledDensityMin, sampledDensityMin, 1.0f);
	            //return true;    

	            //stepColor = float4(sampledDensityMin,sampledDensityMin,sampledDensityMin, 1.0f);
	            //stepColor = vec4(0.5, 0.5,0.5,1.0f);
	            //return true;
                
                //stepColor = float4(sampledDensityMin, sampledDensityMin, sampledDensityMin, 1.0f);
	            //stepColor = vec4(0.5, 0.5,0.5,1.0f);
	            //return true;
                
                // Calculate occlusion and density multiplier

                
                float occlusionDistance = max(0.0, distanceToMarchEnd - min(TRACER_OFFSET_SCALE, abs(backProjectedPoint.z - volumeCenter.z) * 2.0));

                //stepColor = float4(cavityDensity,cavityDensity, cavityDensity, 1.0f);
	            //return true;    
                
                float densityMultiplier = clamp(clamp((cavityDensity - MIN_DENSITY_THRESHOLD) * DENSITY_REMAP_FACTOR, 0.0, 1.0), 0.0, 1.0) * volumeFadeParams[volumeIdx].x;
                float finalScaledDensity = clamp(densityMultiplier + ((1.0 - clamp(distance(_CameraPosition, tracerOffsetSamplePos) * CAMERA_DIST_SCALE, 0.0, 1.0)) * densityMultiplier), 0.0, 1.0);

                //stepColor = float4(finalScaledDensity,finalScaledDensity, finalScaledDensity, 1.0f);
	            //return true;    
                
                // Dissipation / explosion effects
                float3 shadowTestPos = tracerOffsetSamplePos;
                float shadowMultiplier = 1.0;
                float shadowAmount = 0.0;
                float effectiveDensity = finalScaledDensity;
                
                if (hasExplosionLayer)
                {
                    float dissipScale = 1.0;
                    float dissipAccum = 0.0;
                    calculateDissipation(shadowTestPos, dissipScale, dissipAccum, occlusionDistance, volumeIdx, densityPageIdx, skipDueToOcclusion);
                    shadowMultiplier = dissipScale;
                    shadowAmount = dissipAccum;
                    effectiveDensity = lerp(finalScaledDensity * 0.02, finalScaledDensity, dissipScale);
                }
                
                // ========== NOISE CALCULATION (FULL DETAIL) ==========
                // _TimeScale
                float animTime = _Time * _TimeScale;
                //float animTime = 1753.92346  * 1.5;
                //animTime = 2630;
                
                float3 volumeCenteredPos = volumeLocalPos - float3(HALF, HALF, HALF);

                //stepColor = float4(volumeCenteredPos.x ,volumeCenteredPos.y ,volumeCenteredPos.z , 1.0f);
	            //stepColor = float4(0.5, 0.5,0.5,1.0f);
                //return true;
                
                float3 noiseCoord = volumeCenteredPos * NOISE_COORD_SCALE;
                //stepColor = float4(noiseCoord.x, noiseCoord.y, noiseCoord.z, 1.0f);
                //return true;
                
                float noiseY = noiseCoord.y;

                //stepColor = float4(noiseY ,noiseY ,noiseY , 1.0f);
                //stepColor = float4(volumeLocalPos.x ,volumeLocalPos.y ,volumeLocalPos.z , 1.0f);
	            //stepColor = vec4(0.5, 0.5,0.5,1.0f);
	            //return true;
                
                // Rotation
                float rotAngle1 = animTime * ROTATION_TIME_MULT;
                //stepColor = float4(float3(rotAngle1,rotAngle1,rotAngle1), 1.0f);
	            //return true;  
                
                float rotOffset = (animTime * ROTATION_OFFSET_BASE) + ((((DISTORTION_AMPLITUDE + ((sin(noiseY * 5.0) + HALF) * 0.15)) * sin(rotAngle1 + HALF)) * sin((animTime * ROTATION_MOD_FREQ) + HALF)) * DISTORTION_AMPLITUDE);

                //float tempValue  =  sin(rotAngle1 + HALF);
                
                //stepColor = float4(rotOffset, noiseY, rotAngle1, tempValue);
                //return true;
                
                float sinRot = sin(rotOffset);
                float cosRot = cos(rotOffset);



                float2x2 rotMatrix = float2x2(cosRot, -sinRot, sinRot, cosRot);
                float2 rotatedXZ = mul(rotMatrix, noiseCoord.xz);
                //stepColor = float4(noiseCoord.x ,noiseCoord.z ,sinRot ,cosRot);
                //return true;

                
                float rotatedX = rotatedXZ.x;
                float3 noisePosTemp = noiseCoord;
                noisePosTemp.x = rotatedX;
                //noisePosTemp.z = rotatedXZ.y;
                float rotatedZ = rotatedXZ.y;

                //stepColor = float4(rotatedZ ,rotatedZ ,rotatedZ , 1.0f);
                //stepColor = float4(rotatedX ,rotatedZ ,rotatedX , 1.0f);
                //return true;

                
                //stepColor = float4(float3(rotatedXZ.xy, 1.0), 1.0f);
                //return true;    

                //stepColor = float4(noisePosTemp.x ,noisePosTemp.y ,noisePosTemp.z , 1.0f);
	            //stepColor = vec4(0.5, 0.5,0.5,1.0f);
	            //return true;
                
                // Wave perturbation
                
                float waveTime = animTime + (sin(rotAngle1) * 0.02);
                float2 waveOffset = noisePosTemp.xy + (float2(sin(waveTime + (noiseY * WAVE_FREQ_MULT)), cos(waveTime + (rotatedX * WAVE_FREQ_MULT))) * NOISE_PERTURB_AMPLITUDE);
                //stepColor = float4(noisePosTemp.x ,noisePosTemp.y ,noisePosTemp.z , 1.0f);
	            //return true;
                
                float perturbedX = waveOffset.x;
                //stepColor = float4(perturbedX ,perturbedX ,perturbedX , 1.0f);
                //return true;
                float perturbedY = waveOffset.y;
                //stepColor = float4(perturbedY ,perturbedY ,perturbedY , 1.0f);
                //return true;
                float3 noisePosPerturbed = float3(perturbedX, perturbedY, rotatedZ);
                float finalNoiseY = perturbedY + ((sin((perturbedX * PHASE_POWER_2) + (animTime * WAVE_ANIM_FREQ_1)) + sin((rotatedZ * 2.84) + (animTime * WAVE_ANIM_FREQ_2))) * NOISE_PERTURB_AMPLITUDE);
                noisePosPerturbed.y = finalNoiseY;

                //stepColor = float4(noisePosPerturbed.x ,noisePosPerturbed.z, noisePosPerturbed.y , 1.0f);
                //stepColor = float4(perturbedY ,perturbedY ,perturbedY , 1.0f);
                //return true;
	            //stepColor = vec4(0.5, 0.5,0.5,1.0f);
	            //return true;
                
                // Base noise sampling
                float3 baseNoiseCoord = noisePosPerturbed * _Noise1Scale;

                //stepColor = float4(baseNoiseCoord.x, baseNoiseCoord.z, baseNoiseCoord.y, 1.0f);
                //return true;

                //stepColor = float4(noisePosPerturbed.x ,noisePosPerturbed.y ,noisePosPerturbed.z , 1.0f);
                //stepColor = float4(baseNoiseCoord.x ,baseNoiseCoord.y ,baseNoiseCoord.z , 1.0f);
	            //stepColor = vec4(0.5, 0.5,0.5,1.0f);
	            //return true;
                
                float3 timeOffset3D = float3(2.0, 4.5, 2.0) * (animTime * TIME_OFFSET_SCALE);

                //timeOffset3D = float3(0.0, 0.0, 0.0);
                float3 camRightOffset = cameraRightVector * DISTORTION_AMPLITUDE;
                float3 camUpOffset = cameraSideVector * DISTORTION_AMPLITUDE;
                
                
                float4 noisePowerVec = float4(_NoisePower, _NoisePower, _NoisePower, _NoisePower);
                float4 lowFreqParams = float4(_NoiseLowFreq, _NoiseLowFreq, _NoiseLowFreq, _NoiseLowFreq);
                float4 highFreqParams = float4(_NoiseHighFreq, _NoiseHighFreq, _NoiseHighFreq, _NoiseHighFreq);
                float4 noiseBlendParam = float4(_NoiseMixFactor, _NoiseMixFactor, _NoiseMixFactor, _NoiseMixFactor);

                //baseNoiseCoord = float3(0.5f, 0.0f, 0.6f);
                
                float4 baseNoiseProcessed = sampleProcessedNoise(abs(baseNoiseCoord) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
                
                //stepColor = float4(baseNoiseProcessed.x, baseNoiseProcessed.y, baseNoiseProcessed.z , 1.0f);;
                //return true;
                
                float baseNoiseCombined = combineNoiseChannels(baseNoiseProcessed);

                //stepColor = float4(baseNoiseCombined, baseNoiseCombined, baseNoiseCombined, 1.0f);
                //return true;

                // - (526, 1183.00, 526.00 )
                float4 processedNoiseX = sampleProcessedNoise(abs(baseNoiseCoord + camRightOffset) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);

                //stepColor = float4(processedNoiseX.x,processedNoiseX.y,processedNoiseX.z,processedNoiseX.w);
                //stepColor = float4( baseNoiseCoord.xzy, 1.0f);
	            //return true;
                
                float4 processedNoiseY = sampleProcessedNoise(abs(baseNoiseCoord + camUpOffset) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);

                //stepColor = float4(processedNoiseY.x,processedNoiseY.y,processedNoiseY.z, processedNoiseY.w);
	            //return true;
                
                
                //stepColor = processedNoiseY;
                //return true;
                
                float normalGradStep = NORMAL_GRAD_STEP_BASE / _Noise1Scale;

                //stepColor = float4(combineNoiseChannels(processedNoiseX),combineNoiseChannels(processedNoiseX),combineNoiseChannels(processedNoiseX), 1.0f);
	            //return true;
                
                float3 noiseNormal = normalize(float3(
                    baseNoiseCombined - combineNoiseChannels(processedNoiseY),
                    normalGradStep,
                    baseNoiseCombined - combineNoiseChannels(processedNoiseX)
                ));

                //stepColor = float4(noiseNormal, 1.0f);
	            //return true;



                
                //stepColor = float4(noiseNormal.x, noiseNormal.y, noiseNormal.z, 1.0f);
                //stepColor = float4(normalGradStep, normalGradStep, normalGradStep, 1.0f);
                //return true;

                
                
                //stepColor = float4(noiseNormal.x ,noiseNormal.y ,noiseNormal.z , 1.0f);
                //stepColor = float4(baseNoiseCoord.x ,baseNoiseCoord.y ,baseNoiseCoord.z , 1.0f);
	            //stepColor = vec4(0.5, 0.5,0.5,1.0f);
	            //return true;
                
                // View transform and detail noise coordinate
                float4x4 cameraToWorldMatrix = GetCameraToWorldMatrix();
                // = float4(volumeCenteredPos.x ,volumeCenteredPos.y ,volumeCenteredPos.z , 1.0f);
                //return true;
                
                float centeredPosY = volumeCenteredPos.y;


                //noiseNormal = normalize(float3(0.1, 0.8, 0.2));
                //noiseNormal is the same, how about viewTransform ?
                float3 detailNoiseCoord = noiseCoord
                + mul(cameraToWorldMatrix, float4((noiseNormal + float3(0.0, 1.0, 0.0)).xyz, 0.0)).xyz * pow(baseNoiseCombined, TIME_OFFSET_SCALE) * _NormalDetailScale * DISTORTION_AMPLITUDE
                + float3(2.0, 4.5, 2.0) * ((baseNoiseCombined - 1.0) * DISTORTION_AMPLITUDE * _NormalDetailScale * centeredPosY);

                float3 temp = mul(cameraToWorldMatrix, float4((noiseNormal + float3(0.0, 1.0, 0.0)).xyz, 0.0)).xyz;

                //0.49927, 0.48169, 1.76465
                //stepColor = float4(temp.x, temp.y, temp.z, 1.0f);
                //return temp;
                
                //with the override of 
                detailNoiseCoord.x = detailNoiseCoord.x + (sin(finalNoiseY + (animTime * DETAIL_TIME_MULT)) * NOISE_PERTURB_AMPLITUDE);

                //stepColor = float4(detailNoiseCoord.x ,detailNoiseCoord.y ,detailNoiseCoord.z , 1.0f);
                //stepColor = float4(temp.x ,temp.y ,temp.z , 1.0f);
                //return true;
                
                // Detail noise sampling
                float3 detailScaledCoord = detailNoiseCoord * _Noise2Scale;

                //stepColor = float4(detailNoiseCoord.x / 32.0f, detailNoiseCoord.y/ 32.0f, detailNoiseCoord.z/ 32.0f, 1.0f);
                //return true;

                //float3 testCoord = float3(0.0, 0.2, 0.1);
                //float4 result = sampleProcessedNoise(testCoord, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
                //result.w = 1.0f;
                //stepColor = result;
                //return true;
                
                float4 detailNoiseProcessed = sampleProcessedNoise(detailScaledCoord, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
                float detailNoiseCombined = combineNoiseChannels(detailNoiseProcessed);

                //all value same
                float4 detailProcessedX = sampleProcessedNoise(detailScaledCoord + camRightOffset, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
                //all value same
                float4 detailProcessedY = sampleProcessedNoise(detailScaledCoord + camUpOffset, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
                
                //stepColor = float4(detailProcessedY.x ,detailProcessedY.y ,detailProcessedY.z , detailProcessedY.w);
                //return true;
                
                // Depth fade and combined noise
                float depthFade = _DetailNoiseInfluence * (dot(rayDirection, cameraForwardVector) * clamp(distance(shadowTestPos, _CameraPosition) * DEPTH_FADE_DIST_SCALE, 0.0, 1.0));

                float mainNoise = lerp(NOISE_CHANNEL_WEIGHT, clamp(baseNoiseCombined, 0.0, 1.0), _Noise1Influence);
                //float sideNoise = lerp(NOISE_CHANNEL_WEIGHT, clamp(detailNoiseCombined, 0.0, 1.0), depthFade * SECOND_PASS_WEIGHT * RAW_CS2_DISTANCE_TO_UNITY_INV * 0.9);
                float sideNoise = lerp(NOISE_CHANNEL_WEIGHT, clamp(detailNoiseCombined, 0.0, 1.0), depthFade * SECOND_PASS_WEIGHT);
                //sideNoise = clamp(detailNoiseCombined, 0.0, 1.0);
                
                float combinedNoise = mainNoise + sideNoise + _NoiseOffset;

                //0.79297, 0.31738, 0.93799, 0.96289
    	        //stepColor = float4(float3(detailNoiseCombined, depthFade, sideNoise), combinedNoise);
                //return true;
                
                // Height fade
                float normalizedDensity;
                if (volumeFadeParams[volumeIdx].w < 1.0)
                {
                    float heightParam = clamp(volumeFadeParams[volumeIdx].w, EPSILON, MAX_CLAMP_VALUE);
                    float fadeStart = smoothstep(0.0, NORMAL_GRAD_STEP_BASE, heightParam);
                    float fadeEnd = smoothstep(DISTORTION_AMPLITUDE, 1.0, heightParam);
                    if (fadeStart == fadeEnd)
                    {
                        normalizedDensity = effectiveDensity * heightParam;
                    }
                    else
                    {
                        float3 heightTestPos = volumeCenteredPos;
                        heightTestPos.y = centeredPosY * HEIGHT_TEST_Z_SCALE;
                        normalizedDensity = effectiveDensity * clamp(smoothstep(fadeStart, fadeEnd, clamp(length(heightTestPos), 0.0, 1.0)), 0.0, 1.0);
                    }
                }
                else
                {
                    normalizedDensity = effectiveDensity;
                }

                //0.49634
                //stepColor = float4(float3(heightFade, heightFade, heightFade), heightFade);
                //return true;


                //stepColor = float4(float3(detailNoiseCombined, depthFade, sideNoise), combinedNoise);
                //return true;
                
                //stepColor = float4(heightFade, heightFade, heightFade, 1.0f);
                //return true;

                // stepColor = float4(
                //     heightFade,
                //     heightFade,
                //     heightFade,
                //     1.0f);
                // return true;
                
                // Step density
                float stepDensity = lerp(
                    normalizedDensity - (1.0 - combinedNoise),
                    normalizedDensity + combinedNoise,
                    normalizedDensity) *
                        clamp(volumeFadeParams[volumeIdx].x * volumeFadeParams[volumeIdx].w * DENSITY_FADE_MULT, 0.0, 1.0);

                // 0.95605, 0.95605, 0.96289, 8.0
                // stepColor = float4(
                //     stepDensity,
                //     lerp(
                //         heightFade - (1.0 - combinedNoise),
                //         heightFade + combinedNoise,
                //         heightFade),
                //     combinedNoise,
                //     volumeFadeParams[volumeIdx].x * volumeFadeParams[volumeIdx].w * DENSITY_FADE_MULT
                //     );
                //return true;
    
                
                //stepColor = float4(stepDensity, stepDensity, stepDensity, 1.0f);
                //return true;

                //stepColor = float4(combinedNoise, combinedNoise, combinedNoise, 1.0f);
                ///return true;
                
                
                if (stepDensity < EPSILON)
                    return false;
                

                //stepColor = float4(stepDensity, stepDensity, stepDensity, 1.0f);
                //return true;
                
                // ========== NORMAL CALCULATION (FULL DETAIL) ==========
                float3 baseNormalDir = normalize(volumeCenteredPos) * lerp(1.0, 0.0, clamp(shadowAmount, 0.0, 1.0));

                //0.79346, 0.44067, 0.41943
                //stepColor = float4(baseNormalDir.x, baseNormalDir.y, baseNormalDir.z, 1.0f);
                //return true;
                
                // Detail noise normal
                float3 detailNoiseNormal = normalize(float3(
                    detailNoiseCombined - combineNoiseChannels(detailProcessedY),
                    normalGradStep,                                              
                    detailNoiseCombined - combineNoiseChannels(detailProcessedX)
                ));

                //0.45483, 0.79639, 0.39844, 1.00
                //stepColor = float4(detailNoiseNormal.x, detailNoiseNormal.y, detailNoiseNormal.z ,1.0f);
                //return true;

                //0.79346, 0.44067, 0.41943, 1.0
                //stepColor = float4(baseNormalDir.x, baseNormalDir.y, baseNormalDir.z, 1.0f);
                //return true;

                
                float3 baseNormalWS = mul(float4(baseNormalDir.xyz, 0.0), cameraToWorldMatrix).xyz;
                

                //0.04193, 0.45386, 0.88965
                //stepColor = float4(baseNormalWS.x, baseNormalWS.y, baseNormalWS.z, 1.0f);
                //return true;
                

                float detailLerpStep = clamp(baseNoiseCombined - HALF, 0.0, 1.0);
                float detailWeight = lerp(HALF, 1.0, detailLerpStep);

                float2 combinedNoiseXZ = (noiseNormal.xz * _Noise1Influence) + 
                    (detailNoiseNormal.xz * detailWeight * (depthFade * PHASE_POWER_1));

                float distToCenter = distance(shadowTestPos, volumeCenter.xyz);

                //0.38013
                float distFade = clamp((DISSIP_FADE_NEAR - distToCenter) * NORMAL_DIST_SCALE, 0.0, 1.0);
    
                //stepColor = float4(distFade, distFade, distFade, 1.0f);
                //return true;
                
                float perturbIntensity = _NormalPerturbScale * lerp(1.0, 2.0, distFade);

                float3 totalPerturbation = float3(combinedNoiseXZ.x, 0.0, combinedNoiseXZ.y) * perturbIntensity;

                //0.14856, 0.00, 0.30444, 1.0
                //stepColor = float4(totalPerturbation.x, totalPerturbation.y, totalPerturbation.z, 1.0f);
                //return true;
                
                float3 combinedNormalXYZ = baseNormalWS + totalPerturbation;

                float4 finalNormalVec4 = mul(cameraToWorldMatrix, float4(combinedNormalXYZ.x, combinedNormalXYZ.y, combinedNormalXYZ.z, 0.0));

                float3 viewSpaceNormal = finalNormalVec4.xyz;
                                
                // float4 normalTransform = mul(cameraToWorldMatrix, float4(((mul(cameraToWorldMatrix, float4(baseNormalDir.xyz, 0.0))).xyz +
                //     ((float3((
                //         noiseNormal.xz * _Noise1Influence) +
                //         ((detailNoiseNormal * lerp(HALF, 1.0, clamp(baseNoiseCombined - HALF, 0.0, 1.0))).xz * (depthFade * PHASE_POWER_1)),
                //         0.0) * _NormalPerturbScale) * lerp(1.0, 2.0, clamp((DISSIP_FADE_NEAR - distance(shadowTestPos, volumeCenters[volumeIdxInt].xyz)) * NORMAL_DIST_SCALE, 0.0, 1.0)))).xyz, 0.0));
                // //float3 viewSpaceNormal = normalTransform.xyz;

                //1.00977, 0.70068, 0.39795
                //stepColor = float4(viewSpaceNormal.x, viewSpaceNormal.y, viewSpaceNormal.z, 1.0f);
                //return true;

                // stepColor = float4(viewSpaceNormal.x, viewSpaceNormal.y, viewSpaceNormal.z ,1.0f);
                // return true;
                
                // ========== COLOR LOOKUP ==========
                float3 scatterUVW = clamp(clamp(lerp(volumeCenteredPos * dot(baseNormalDir, viewSpaceNormal), normalize(viewSpaceNormal + float3(0.0, HALF, 0.0)) * length(volumeCenteredPos), float3(DISTORTION_AMPLITUDE, DISTORTION_AMPLITUDE, DISTORTION_AMPLITUDE)) + float3(HALF, HALF, HALF), float3(0.03, 0.03, 0.03), float3(0.97, 0.97, 0.97)), float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
                scatterUVW.x = (densityUOffset + (scatterUVW.x * SINGLE_VOLUME_TILE_SIZE)) * DENSITY_ATLAS_WIDTH_INV;
                float4 scatterColor = _ColorLUT3D.SampleLevel(sampler_ColorLUT3D, scatterUVW.xyz, 0.0);
                scatterColor = float4(0.0, 0.0, 0.0, 1.0);
                
                // ========== LIGHTING ==========
                Light mainLight = GetMainLight();
                float3 mainLightDir = mainLight.direction;
                float3 mainLightColor = mainLight.color;

                //float4 mainLightDirectionVector = float4(-0.37157, 0.86603, 0.33457, 0.04);
                //float4 mainLightIrradiance = float4(3.00, 2.21373, 1.35236, 0.00);
                
                
                float sunDot = dot(lerp(baseNormalDir, viewSpaceNormal, float3(_PhaseBlend, _PhaseBlend, _PhaseBlend)), mainLightDir.xyz);
                
                //stepColor = float4(baseNormalDir.x, baseNormalDir.y, baseNormalDir.z, sunDot);

                //stepColor = float4(baseNormalDir.x, baseNormalDir.y, baseNormalDir.z, sunDot);
                //return true;

                float phaseFunction = pow(clamp((sunDot * PHASE_SCALE_1) + PHASE_OFFSET_1, 0.0, 1.0), PHASE_POWER_1) + pow(clamp((sunDot * PHASE_SCALE_2) - PHASE_OFFSET_2, 0.0, 1.0), PHASE_POWER_2);
                float sunScattering = (phaseFunction > 0.0) ? (phaseFunction * scatterColor.w) : phaseFunction;
                
                //stepColor = float4(sunDot, phaseFunction, sunScattering, 1.0f);
                //return true;
            
                
                // ========== COLOR PROCESSING (RGB <-> HSV) ==========
                float3 hsv = RgbToHsv(scatterColor.xyz);
                hsv.y = clamp(hsv.y * SATURATION_BOOST, 0.0, 1.0);
                float3 finalRGB = HsvToRgb(hsv);

                //stepColor = float4(finalRGB.x, finalRGB.z, finalRGB, 1.0f);
                //return true;
                
                // ========== LIT COLOR ==========
                // 1. 颜色预处理：防止除零并限制最大亮度
                float3 safeRGB = finalRGB + float3(COLOR_EPSILON, COLOR_EPSILON, COLOR_EPSILON);
                float3 normalizedColor = normalize(safeRGB);
                float colorLen = min(length(finalRGB), MAX_COLOR_LENGTH);
                float3 baseRGB = normalizedColor * colorLen;

                // 2. 密度权重计算：处理二次采样的权重影响
                float stepDensityWeight = clamp(1.0 - min(SECOND_PASS_WEIGHT, stepDensity), 0.0, 1.0);

                // 3. 高度与对比度衰减：基于高度调整云层密度感
                float heightFadeFactor = normalizedDensity * HEIGHT_FADE_DENSITY_MULT;
                float contrastAdj = (heightFadeFactor - stepDensity) * _DensityContrast;
                float heightContrastFade = clamp(1.0 - contrastAdj, 0.0, 1.0);

                // 4. 噪声与散射合成：将噪声纹理与太阳散射逻辑结合
                float scatteringFactor = 0.75 + (sunScattering * SECOND_PASS_WEIGHT);
                float3 textureScatteringTerm = combinedNoise * scatteringFactor;
                
                //stepColor = float4(textureScatteringTerm.x, textureScatteringTerm.y, stepDensity, stepDensityWeight);
                //return true; 
                
                // 5. 法线曲率遮蔽：利用视角空间法线 Z 分量增加云朵的体积感/圆润感
                // finalNormalVec4.z 越大（越朝向镜头），亮度越高
                float curvatureShading = 1.0 + (finalNormalVec4.y * HALF);

                // 6. 基础项合成 (Base Term)
                float3 baseResult = baseRGB * stepDensityWeight * heightContrastFade * textureScatteringTerm * curvatureShading;
                baseResult *= _BaseColorIntensity;

                // 7. 直接太阳散射项 (Direct Sun Scattering Term)
                // 加入了腔体遮蔽 (cavityStrength)，让云朵缝隙处变暗
                float scatteringStrength = (HALF * sunScattering) * (1.0 - cavityStrength);
                float3 sunDirectTerm = (mainLightColor * scatteringStrength) * _SunColorIntensity;

                //0.15149, 0.11182, 0.0683, 0.14429
                //stepColor = float4(sunDirectTerm.x, sunDirectTerm.y, sunDirectTerm.z,  scatteringStrength);
                //return true;


                
                // 8. 最终颜色输出
                float3 litColor = baseResult + sunDirectTerm;
                
                //0.15149， 0.11182， 0.0683, 1.0
                //stepColor = float4(litColor.x, litColor.y ,litColor.z, 1.0f );
                //return true;

                
                // ========== TINTING AND DESATURATION ==========
                float3 lumaWeights = float3(LUMA_R, LUMA_G, LUMA_B);
                //float3 tintColorVector = float4 (0.70588, 0.50588, 0.19608, 0.00 );

                float3 volumeTintedColor = litColor * volumeTintColor[volumeIdxInt].xyz;
                float3 desaturatedColor = (lerp(litColor, volumeTintedColor * (dot(litColor.xyz, lumaWeights) / dot((volumeTintedColor + float3(COLOR_EPSILON, COLOR_EPSILON, COLOR_EPSILON)).xyz, lumaWeights)), float3(HALF * (1.0 - volumeFadeParams[volumeIdx].z), HALF * (1.0 - volumeFadeParams[volumeIdx].z), HALF * (1.0 - volumeFadeParams[volumeIdx].z))) * lerp(float3(1.0, 1.0, 1.0), normalize(_ColorTint + float3(MIN_DENSITY_THRESHOLD, MIN_DENSITY_THRESHOLD, MIN_DENSITY_THRESHOLD)) * COLOR_TINT_NORM, float3(clamp(HALF + (stepDensity * HSV_HUE_SECTORS), 0.0, 1.0), clamp(HALF + (stepDensity * HSV_HUE_SECTORS), 0.0, 1.0), clamp(HALF + (stepDensity * HSV_HUE_SECTORS), 0.0, 1.0)))).xyz;
                float3 shadowedColor = lerp(desaturatedColor, desaturatedColor * shadowMultiplier, float3(SHADOW_BLEND_FACTOR, SHADOW_BLEND_FACTOR, SHADOW_BLEND_FACTOR)).xyz;

                //0.17188, 0.10669, 0.04617
                //stepColor = float4(shadowedColor.x, shadowedColor.y ,shadowedColor.z, 1.0f );
                //return true;
                
                // ========== FOG AND ALPHA ==========
                float fogAmount = smoothstep(0.0, DISTORTION_AMPLITUDE, stepDensity + FOG_STEP_THRESHOLD) * (((clamp((_GodrayFalloffDist * RAW_CS2_DISTANCE_TO_UNITY - occlusionDistance) / (_GodrayFalloffDist * RAW_CS2_DISTANCE_TO_UNITY), 0.0, 1.0) * normalizedDensity) * FOG_DENSITY_MULT) * _GodrayIntensity);
                float stepAlpha = smoothstep(0.0, DISTORTION_AMPLITUDE / (_AlphaScale * lerp(HALF, 2.0, stepColor.w)), stepDensity);

                //0.00, 1.00, 8.59375, 1.00
                //stepColor = float4(fogAmount, stepAlpha, occlusionDistance, 1.0f);
                //return true;
                
                float3 tracerGlowColor = float3(TRACER_GLOW_R, TRACER_GLOW_G, TRACER_GLOW_B);
                float4 stepContribution = float4(((shadowedColor + ((shadowedColor * tracerGlowColor) * tracerGlow)) * lerp(1.0, SHADOW_AMOUNT_SCALE, clamp(shadowAmount * TRACER_OFFSET_SCALE, 0.0, 1.0))) * stepAlpha, stepAlpha);
                
                //0.17188， 0.10669， 0.04617
                //stepColor = stepContribution;
                //return true;
                
                // ========== ACCUMULATION ==========
                float sampleWeight = weightBase * RAW_CS2_DISTANCE_TO_UNITY_INV * weightMultiplier ;

                //2.25
                //stepColor = float4(sampleWeight, sampleWeight, sampleWeight, sampleWeight);
                //return true;
                
                while (sampleWeight >= 1.0)
                {
                    stepFogDensity += fogAmount;
                    stepColor += stepContribution * (1.0 - stepColor.w);
                    stepLightEnergy += sunScattering;
                    sampleWeight -= 1.0;
                }
                stepLightEnergy += sunScattering * sampleWeight;
                stepFogDensity += fogAmount * sampleWeight;

                //return true;
                
                //0.91455, 0.51563, 0.4519, 1.0
                stepColor += stepContribution * ((1.0 - stepColor.w) * sampleWeight);
	            //return true;
                //0.69238
                //stepColor = stepLightEnergy;

                //0
                //stepColor = stepFogDensity;
                
                return (stepAlpha + fogAmount) > 0.0;
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
                // sample the smokeMask
                uint rawSmokeMask = (SAMPLE_TEXTURE2D(_SmokeMask, sampler_SmokeMask, input.uv).r);

                //output.outSmokeColor = float4(sceneAABBMin.x, sceneAABBMin.y, sceneAABBMin.z, 1.0f);
                //return output;


                //output.outSmokeColor = rawSmokeMask;
                //return output;

                // if no smoke is hit by this fragment, discard
                if (rawSmokeMask == 0)
                    discard;

                //output.outSmokeColor = DEBUG_PINK_COLOR;
                //return output;
                
                float rawDepth = SampleSceneDepth(input.uv);
                
                // sample the depth of the scene

                // calculate the ndc position of the scene of this fragment
                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );
                    
                

                float4 worldPos = mul(_InvVP,ndc);
                // calculate the worldPosition of the scene of this fragment in world space
                float3 worldPosition = worldPos.xyz / worldPos.w;

                // from camera to the worldPosition
                float3 rayDirection = normalize(worldPosition - _CameraPosition);
                float3 invRayDirection = float3(1.0, 1.0, 1.0) / rayDirection;

                // output.outSmokeColor = float4(invRayDirection.x, invRayDirection.y, invRayDirection.z, 1.0);
                // return output;
                
                float rayEnterDistance, rayExitDistance;

                bool isHitScene = AABBIntersect(
                    sceneAABBMin,
                    sceneAABBMax,
                    _CameraPosition,
                    rayDirection,
                    rayEnterDistance,
                    rayExitDistance
                );
                
                //if the ray is not hitting any smoke
                if (!isHitScene)
                {
                    //output.outSmokeColor = float4(1.0f, 0.1f, 1.0f, 1.0f);
                    //return output;
                    discard;
                }

                // else
                // {
                //     //if the ray hits a smoke 
                //     output.outSmokeColor = float4(1.0f, 1.f, 0.2f, 1.0f);
                //     return output;
                // }
                 
                
                float baseStepDistance = _BaseStepSize * RAW_CS2_DISTANCE_TO_UNITY * STEP_DISTANCE_MULTIPLIER;
                int2 fragCoord = int2(input.positionCS.xy);

                int2 noiseTextureSize = int2(_BlueNoiseTex2D_TexelSize.zw);
                int2 noiseMask = noiseTextureSize - 1;
                int2 noiseCoord = (fragCoord / 1) & noiseMask;
                float blueNoiseSample = _BlueNoiseTex2D.Load(int3(noiseCoord, 0)).r;
                float rayStartJitter = computeRayStartJitter(_BaseStepSize * RAW_CS2_DISTANCE_TO_UNITY, blueNoiseSample, _Time.y, rayEnterDistance);
                
                
                float rayMarchStart = max(rayEnterDistance, RAY_NEAR_CLIP_OFFSET) + rayStartJitter * 6.0;
                //float linearSceneDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float3 cameraForwardVector = UNITY_MATRIX_I_V[1].xyz;
                float3 cameraRightVector = UNITY_MATRIX_I_V[2].xyz;
                
                float rayDotCameraForward = dot(cameraForwardVector, rayDirection);

                float viewZ = LinearEyeDepth(rawDepth, _ZBufferParams);

                float safeCosTheta = max(rayDotCameraForward, 0.0001);
    
                float sceneSurfaceDistance = viewZ / safeCosTheta;
                
                float3 negativeRayDir = (-rayDirection).xyz;
                float3 backProjectedPoint = _CameraPosition.xyz + rayDirection * sceneSurfaceDistance;
                

                bool hasExplosionLayer = enableExplosions > 0u;

                // if (hasExplosionLayer)
                // {
                //     skipDueToOcclusion = ((1.0 / (((clamp((texelFetch(secondaryDepthTexture, ifloat3(ifloat2(gl_FragCoord.xy * float(renderParams.depthDownscaleFactor)), 0).xy, 0).x - cameraData.depthNear) / depthRange, 0.0, 1.0) * cameraData.projectionParams.z) + cameraData.projectionParams.w) * rayDotForward)) - sceneDepthAlongRay) > OCCLUSION_CHECK_DIST;
                // }
                
                bool skipDueToOcclusion = false;
                
                float rayMarchEnd = sceneSurfaceDistance - SCENE_DEPTH_OFFSET;
                
                
                if (rayMarchStart > rayMarchEnd)
                {
                    //output.outSmokeColor = DEBUG_PINK_COLOR;
                    //return output;
                    discard;
                }

                float3 marchStartWorldPos = _CameraPosition + (rayDirection * rayMarchStart);
                float3 marchEndWorldPos = _CameraPosition + (rayDirection * min(rayExitDistance, rayMarchEnd));

                uint activeVolumeMask = (uint)_SmokeMask.Load(int3(fragCoord, 0)).x;

                if (activeVolumeMask == 0u)
                {
                    output.outSmokeColor = DEBUG_PINK_COLOR;
                    return output;
                    discard;
                }

                VolumeBoxData activeVolumeBoxes[1];
                uint activeVolumeCount = 0u;
                uint volumeIndex = 0u;
                uint currentVolumeBit = activeVolumeMask;
                
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
                // if (activeVolumeCount > 0)
                // {
                //     float smokeStart = volumeBoxList[0].tMin;
                //     rayMarchStart = max(rayMarchStart, smokeStart);
                // }

                float totalMarchDistance = length(marchEndWorldPos - marchStartWorldPos);
                int maxStepCount = int(clamp(ceil(totalMarchDistance / baseStepDistance) + STEP_COUNT_PADDING, 1.0, MAX_MARCH_STEPS));

                //output.outSmokeColor = maxStepCount / 20.0;
                //return output;

                uint validVolumeCount = min(activeVolumeCount, MAX_ACTIVE_VOLUMES);

                float3 cameraSideVector = cross(cameraForwardVector, cameraRightVector);
                float totalRayDistance = rayMarchStart + totalMarchDistance;

                float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0);
                float3 accumulatedTracerDirection = float3(0.0, 0.0, MIN_DENSITY_THRESHOLD);
                float3 currentMarchPos = marchStartWorldPos;
                float3 currentVolumePos = marchEndWorldPos;
                float3 lastValidSamplePos = marchEndWorldPos;

                bool foundOpaqueFlag = false;
                float accumulatedLightEnergy = 0.0;
                float accumulatedFogDensity = 0.0;
                float accumulatedTracerGlow = 0.0;
                float tracerCavityStrength = 0.0;
                uint tracerAnimationCounter = 0u;
                float currentRayDistance = rayMarchStart;
                bool hasValidSample = false;

                float3 loopLastHitPos = lastValidSamplePos;
                float3 loopFirstHitPos = currentVolumePos;
                float loopSunlightOut = accumulatedLightEnergy;
                float loopGodrayOut = accumulatedFogDensity;
                float4 loopColorOut = accumulatedColor;
                float loopRayTOut = currentRayDistance;
                bool loopHadPrevSample = hasValidSample;

                for (int stepIndex = 0; stepIndex < maxStepCount; stepIndex++)
                {
                    bool shouldUpdateTracerAnim = false;
                    if (activeTracerCount > 0u)
                    {
                        shouldUpdateTracerAnim = ((stepIndex & TRACER_CACHE_INTERVAL) == 0) || (stepIndex < TRACER_WARMUP_STEPS);
                    }

                    if (shouldUpdateTracerAnim)
                    {
                        accumulatedTracerGlow = 0.0;
                        tracerCavityStrength = 0.0;
                        tracerAnimationCounter = 0u;
                        accumulatedTracerDirection = float3(0.0, 0.0, MIN_DENSITY_THRESHOLD);
                    }

                    float3 samplePosition = currentVolumePos;
                    bool hadPreviousSample = hasValidSample;
                    float4 stepColor = accumulatedColor;
                    float3 stepTracerDir = accumulatedTracerDirection;
                    float stepLightEnergy = accumulatedLightEnergy;
                    float stepFogDensity = accumulatedFogDensity;
                    float stepTracerGlow = accumulatedTracerGlow;
                    float stepCavityStrength = tracerCavityStrength;
                    uint stepTracerBits = tracerAnimationCounter;

                    bool innerLoopBreak = false;

                    // output.outSmokeColor = float4(sceneDepthAlongRay,sceneDepthAlongRay,sceneDepthAlongRay,1.0);
                    // return output;
                
                    
                    for (uint volumeCheckIndex = 0u; volumeCheckIndex < validVolumeCount; volumeCheckIndex++)
                    {
                        if (currentRayDistance < volumeBoxList[volumeCheckIndex].tMin)
                            continue;
                        if (currentRayDistance > volumeBoxList[volumeCheckIndex].tMax)
                            continue;

                        if (activeTracerCount > 0u && (stepTracerBits & 3u) == 0u)
                        {
                            calculateTracerInfluence(currentMarchPos, stepTracerGlow, stepTracerDir, stepCavityStrength);
                            stepTracerBits |= 1u;
                        }
                        
                        uint currentVolumeIdx = uint(volumeBoxList[volumeCheckIndex].index);
                        uint densityPageIdx = uint(volumeAnimState[currentVolumeIdx].z);
                        float densityUOffset = DENSITY_PAGE_STRIDE * float(densityPageIdx);
                        //densityUOffset = 34.0 * float(densityPageIdx);
                        bool hasValidSampleResult = sampleVolume(
                            currentMarchPos, marchEndWorldPos, backProjectedPoint, rayDirection, cameraSideVector,
                            currentVolumeIdx, densityUOffset, densityPageIdx,
                            stepTracerGlow, stepTracerDir, stepCavityStrength,
                            hasExplosionLayer, skipDueToOcclusion,
                            _BaseStepSize * RAW_CS2_DISTANCE_TO_UNITY, FIRST_PASS_WEIGHT,  // <-- weight parameters
                            stepColor, stepLightEnergy, stepFogDensity);

                        //output.outSmokeColor = float4(0.00, 1.0, 0.75195, 1.0);
                        //output.outSmokeColor = stepColor;
                        //return output;
                        
               //          if(volumeCheckIndex > 1000){
				           //  output.outSmokeColor = stepColor;
               //              output.outSmokeColor = float4(1.0,1.0,0.5,1.0);
				           //  return output;
			            // }
                        
                        bool shouldRecordFirstHit = hasValidSampleResult && !hadPreviousSample;
                        if (shouldRecordFirstHit)
                            samplePosition = currentMarchPos;
                        
                        // Update last valid sample position whenever we have a valid sample
                        if (hasValidSampleResult)
                            lastValidSamplePos = currentMarchPos;
                        
                        if (stepColor.w > OPAQUE_THRESHOLD)
                        {
                            stepColor.w = 1.0;
                            loopLastHitPos = currentMarchPos;
                            loopFirstHitPos = samplePosition;
                            loopSunlightOut = stepLightEnergy;
                            loopGodrayOut = stepFogDensity;
                            loopColorOut = stepColor;
                            innerLoopBreak = true;
                            foundOpaqueFlag = true;
                            break;
                        }
                        
                        if (shouldRecordFirstHit)
                            hadPreviousSample = true;
                    }

                    if (!innerLoopBreak)
                    {
                        loopLastHitPos = lastValidSamplePos;
                        loopFirstHitPos = samplePosition;
                        loopSunlightOut = stepLightEnergy;
                        loopGodrayOut = stepFogDensity;
                        loopColorOut = stepColor;
                        loopHadPrevSample = hadPreviousSample;
                    }

                    if (innerLoopBreak)
                    {
                        loopRayTOut = currentRayDistance;
                        break;
                    }
                    
                    float3 nextMarchPos = currentMarchPos + (rayDirection * baseStepDistance);
                    float nextRayDistance = currentRayDistance + baseStepDistance;
                    
                    if (nextRayDistance >= totalRayDistance)
                    {
                        loopRayTOut = nextRayDistance;
                        break;
                    }
                    
                    accumulatedLightEnergy = stepLightEnergy;
                    accumulatedFogDensity = stepFogDensity;
                    accumulatedColor = stepColor;
                    accumulatedTracerGlow = stepTracerGlow;
                    accumulatedTracerDirection = stepTracerDir;
                    tracerCavityStrength = stepCavityStrength;
                    tracerAnimationCounter = stepTracerBits;
                    currentMarchPos = nextMarchPos;
                    currentRayDistance = nextRayDistance;
                    hasValidSample = hadPreviousSample;
                    currentVolumePos = samplePosition;
                }

                //output.outSmokeColor = loopColorOut;
                //output.outSmokeColor = float4(0.5, 0.5, 0.2 , 1.0f );
                //return output;
                
                float3 finalLastHitPos = loopLastHitPos;
                float3 finalFirstHitPos = loopFirstHitPos;
                float finalSunlightAccum = loopSunlightOut;
                float finalGodrayAccum = loopGodrayOut;
                float4 finalAccumColor = loopColorOut;
                
                Light mainLight = GetMainLight();
                float3 mainLightDir = mainLight.direction;
                float3 mainLightColor = mainLight.color;
                
                float sunRimDot = pow(clamp(dot(normalize(rayDirection), mainLightDir.xyz), 0.0, 1.0), RIM_LIGHT_POWER) * RIM_LIGHT_SCALE;
                float foggedDensity = clamp(finalGodrayAccum - (finalAccumColor.w * DISTORTION_AMPLITUDE), 0.0, 1.0);
                float4 preRimColor = (_GodrayIntensity == 0.0) ? finalAccumColor : float4(finalAccumColor.xyz * lerp(1.0, 0.0, foggedDensity), finalAccumColor.w + foggedDensity);
                float3 rimEnhancedColor = preRimColor.xyz * (float3(1.0, 1.0, 1.0) + ((pow(mainLightColor.xyz, float3(2.0, 2.0, 2.0)) * (((sunRimDot + (pow(sunRimDot, RIM_HIGHLIGHT_POWER) * RIM_HIGHLIGHT_SCALE)) * lerp(1.0, 0.0, pow(finalAccumColor.w, HALF))) * finalAccumColor.w)) * (finalSunlightAccum * _RimLightIntensity)));
                float4 finalOutputColor = preRimColor;
                finalOutputColor.x = rimEnhancedColor.x;
                finalOutputColor.y = rimEnhancedColor.y;
                finalOutputColor.z = rimEnhancedColor.z;
                float finalAlpha = preRimColor.w;
                
                
                if (finalAlpha < EPSILON)
                {
//                    output.outSmokeColor = float4(0.2f, 0.9f, 1.0f, 1.0f);
//                    return output;
                    discard;
                }
                
                
                // Depth output
                float logDepthRange = _LogDepthFar - _LogDepthNear;
                float logDepthNear = (((log(dot(cameraForwardVector.xyz, finalFirstHitPos.xyz - _CameraPosition.xyz)) - _LogDepthNear) / logDepthRange) * 2.0) - 1.0;
                float logDepthFar = (((log(dot(cameraForwardVector.xyz, finalLastHitPos.xyz - _CameraPosition.xyz)) - _LogDepthNear) / logDepthRange) * 2.0) - 1.0;
                
                // Moment buffer calculation
                float4 moment0Accum = float4(0.0, 0.0, 0.0, 0.0);
                float4 moment1Accum = float4(0.0, 0.0, 0.0, 0.0);
                float4 moment2Accum = float4(0.0, 0.0, 0.0, 0.0);
                
                [unroll]
                for (int momentLoopCounter = 0; momentLoopCounter < MOMENT_LOOP_COUNT; momentLoopCounter++)
                {
                    int momentLoopIdx = momentLoopCounter + 1;
                    float momentParam = SECOND_PASS_WEIGHT * float(momentLoopIdx);
                    float depthInterpolated = lerp(logDepthNear, logDepthFar, momentParam);
                    float momentWeight = -log(1.0 - clamp(finalAlpha * momentParam, EPSILON, MAX_CLAMP_VALUE));
                    float depthSquared = depthInterpolated * depthInterpolated;
                    float depthQuartic = depthSquared * depthSquared;
                    moment0Accum += float4(momentWeight, 0.0, 0.0, 0.0);
                    moment1Accum += float4(float2(depthInterpolated, depthSquared) * momentWeight, 0.0, 0.0);
                    moment2Accum += float4(depthSquared * depthInterpolated, depthQuartic, depthQuartic * depthInterpolated, depthQuartic * depthSquared) * momentWeight;
                }
                
                output.outSmokeColor = loopColorOut;
                //output.outSmokeColor = float4(1.0, 1.0, 0.5, 1.0);
                
                return output;
            }
            ENDHLSL
        }
    }
}
