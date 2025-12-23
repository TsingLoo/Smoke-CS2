#version 460
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_samplerless_texture_functions : require
layout(early_fragment_tests) in;

struct VolumeBoxData
{
    vec4 _m0;
};

struct Matrix4x4
{
    vec4 _m0[4];
};

struct VolumeArray16
{
    vec4 _m0[16];
};

struct PointArray5
{
    vec4 _m0[5];
};

struct MaskArray2
{
    vec4 _m0[2];
};

vec4 unusedVec4;

layout(set = 1, binding = 1, std140) uniform CameraDataBlock
{
    layout(offset = 128) Matrix4x4 _m0;
    layout(offset = 256) vec4 _m1;
    layout(offset = 304) vec3 _m2;
    layout(offset = 316) float _m3;
    layout(offset = 320) vec3 _m4;
    layout(offset = 332) float _m5;
    layout(offset = 336) vec3 _m6;
    layout(offset = 492) float _m7;
} cameraData;

layout(set = 1, binding = 5, scalar) uniform VolumeDataBlock
{
    layout(offset = 0) VolumeArray16 _m0;
    layout(offset = 256) VolumeArray16 _m1;
    layout(offset = 512) VolumeArray16 _m2;
    layout(offset = 768) VolumeArray16 _m3;
    layout(offset = 1024) VolumeArray16 _m4;
    layout(offset = 1280) VolumeArray16 _m5;
    layout(offset = 1536) vec4 _m6;
    layout(offset = 1552) vec4 _m7;
    layout(offset = 1568) VolumeArray16 _m8;
    layout(offset = 1824) VolumeArray16 _m9;
    layout(offset = 2080) VolumeArray16 _m10;
    layout(offset = 2336) PointArray5 _m11;
    layout(offset = 2416) MaskArray2 _m12;
    layout(offset = 2468) uint _m13;
    layout(offset = 2472) float _m14;
    layout(offset = 2476) uint _m15;
} volumeData;

layout(set = 1, binding = 0, std140) uniform RenderParamsBlock
{
    layout(offset = 8) float _m0;
    layout(offset = 12) float _m1;
    layout(offset = 16) float _m2;
    layout(offset = 20) float _m3;
    layout(offset = 24) float _m4;
    layout(offset = 28) float _m5;
    layout(offset = 32) float _m6;
    layout(offset = 36) float _m7;
    layout(offset = 44) float _m8;
    layout(offset = 48) float _m9;
    layout(offset = 52) float _m10;
    layout(offset = 56) float _m11;
    layout(offset = 60) float _m12;
    layout(offset = 64) float _m13;
    layout(offset = 68) float _m14;
    layout(offset = 72) float _m15;
    layout(offset = 76) float _m16;
    layout(offset = 80) float _m17;
    layout(offset = 84) float _m18;
    layout(offset = 92) int _m19;
    layout(offset = 96) vec3 _m20;
    layout(offset = 108) float _m21;
    layout(offset = 112) float _m22;
    layout(offset = 128) float _m23;
    layout(offset = 132) int _m24;
} renderParams;

layout(set = 1, binding = 4, std140) uniform ScreenDataBlock
{
    layout(offset = 176) ivec2 _m0;
    layout(offset = 604) float _m1;
    layout(offset = 608) float _m2;
} screenData;

layout(set = 3, binding = 0, std140) uniform LightingDataBlock
{
    layout(offset = 304) vec4 _m0;
    layout(offset = 320) vec4 _m1;
} lightingData;

layout(set = 1, binding = 30) uniform texture2D blueNoiseTexture;
layout(set = 1, binding = 56) uniform texture2D sceneDepthTexture;
layout(set = 1, binding = 58) uniform texture2D secondaryDepthTexture;
layout(set = 1, binding = 57) uniform texture2D volumeMaskTexture;
layout(set = 1, binding = 53) uniform texture3D volumeDensityTexture;
layout(set = 1, binding = 17) uniform sampler volumeSampler;
layout(set = 1, binding = 55) uniform texture3D highFreqNoiseTexture;
layout(set = 1, binding = 16) uniform sampler noiseSampler;
layout(set = 1, binding = 54) uniform texture3D colorLUTTexture;

layout(location = 0) in vec3 inWorldViewDir;
layout(location = 0) out vec4 outMoment0;
layout(location = 1) out vec4 outMoment1;
layout(location = 2) out vec4 outMoment2;
layout(location = 3) out vec4 outSmokeColor;
layout(location = 4) out vec4 outDepthMinMax;
layout(location = 5) out float outTransmittance;

void main()
{
    vec3 rayDirection = normalize(inWorldViewDir);
    vec3 invRayDirection = vec3(1.0) / rayDirection;
    vec3 tToSceneMin = invRayDirection * (sceneAABBMin.xyz - cameraPosition);
    vec3 tToSceneMax = invRayDirection * (sceneAABBMax.xyz - cameraPosition);
    vec3 tMinPerAxis = min(tToSceneMax, tToSceneMin);
    vec3 tMaxPerAxis = max(tToSceneMax, tToSceneMin);
    vec2 tMinComponents = max(tMinPerAxis.xx, tMinPerAxis.yz);
    float rayEnterDistance = max(tMinComponents.x, tMinComponents.y);
    vec2 tMaxComponents = min(tMaxPerAxis.xx, tMaxPerAxis.yz);
    float rayExitDistance = min(tMaxComponents.x, tMaxComponents.y);
    if (!(!(rayEnterDistance > rayExitDistance)))
    {
        discard;
    }
    float baseStepDistance = baseStepSize * 1.5;
    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    float rayMarchStart = max(rayEnterDistance, 4.0) + (((baseStepDistance * fract(texelFetch(blueNoiseTexture, ivec3(fragCoord & noiseTileSize, 0).xy, 0).x + (globalTime * 0.61803400516510009765625))) * jitterScale) * mix(0.100000001490116119384765625, 0.800000011920928955078125, clamp((rayEnterDistance + 150.0) * 0.0500000007450580596923828125, 0.0, 1.0)));
    ivec2 screenCoord = ivec3(fragCoord, 0).xy;
    float depthRange = depthFar - depthNear;
    float linearSceneDepth = (clamp((texelFetch(sceneDepthTexture, screenCoord, 0).x - depthNear) / depthRange, 0.0, 1.0) * projectionParams.z) + projectionParams.w;
    float rayDotForward = dot(cameraForward.xyz, rayDirection);
    float sceneDepthAlongRay = 1.0 / (linearSceneDepth * rayDotForward);
    vec3 negRayDirection = (-rayDirection).xyz;
    vec3 backProjectedPoint = cameraPosition.xyz + (negRayDirection * (1.0 / (linearSceneDepth * dot(cameraForward.xyz, negRayDirection))));
    bool hasExplosionLayer = explosionCount > 0u;
    bool skipDueToOcclusion;
    if (hasExplosionLayer)
    {
        skipDueToOcclusion = ((1.0 / (((clamp((texelFetch(secondaryDepthTexture, ivec3(ivec2(gl_FragCoord.xy * float(depthDownscaleFactor)), 0).xy, 0).x - depthNear) / depthRange, 0.0, 1.0) * projectionParams.z) + projectionParams.w) * rayDotForward)) - sceneDepthAlongRay) > 10.0;
    }
    else
    {
        skipDueToOcclusion = false;
    }
    float rayMarchEnd = sceneDepthAlongRay - 2.0;
    if (rayMarchStart > rayMarchEnd)
    {
        discard;
    }
    vec3 marchStartPos = cameraPosition + (rayDirection * rayMarchStart);
    vec3 marchEndPos = cameraPosition + (rayDirection * min(rayExitDistance, rayMarchEnd));
    uint activeVolumeMask = uint(texelFetch(volumeMaskTexture, screenCoord, 0).x);
    uint bitmaskShifted;
    uint volumeIdxNext;
    VolumeBoxData activeVolumeBoxes[1];
    uint volumeCountTemp;
    uint activeVolumeCount;
    uint volumeIndex = 0u;
    uint arrayIndex = 0u;
    uint currentVolumeBit = activeVolumeMask;
    for (;;)
    {
        if (!(currentVolumeBit != 0u))
        {
            activeVolumeCount = arrayIndex;
            break;
        }
        if ((currentVolumeBit & 1u) != 0u)
        {
            vec3 tToVolumeMin = invRayDirection * (volumeMinBounds._m0[volumeIndex].xyz - cameraPosition);
            vec3 tToVolumeMax = invRayDirection * (volumeMaxBounds._m0[volumeIndex].xyz - cameraPosition);
            vec3 volTMinPerAxis = min(tToVolumeMax, tToVolumeMin);
            vec3 volTMaxPerAxis = max(tToVolumeMax, tToVolumeMin);
            vec2 volTMinComp = max(volTMinPerAxis.xx, volTMinPerAxis.yz);
            vec2 volTMaxComp = min(volTMaxPerAxis.xx, volTMaxPerAxis.yz);
            activeVolumeBoxes[arrayIndex]._m0.x = max(volTMinComp.x, volTMinComp.y);
            activeVolumeBoxes[arrayIndex]._m0.y = min(volTMaxComp.x, volTMaxComp.y);
            activeVolumeBoxes[arrayIndex]._m0.z = float(volumeIndex);
            volumeCountTemp = arrayIndex + 1u;
        }
        else
        {
            volumeCountTemp = arrayIndex;
        }
        if (volumeCountTemp >= 1u)
        {
            activeVolumeCount = volumeCountTemp;
            break;
        }
        bitmaskShifted = currentVolumeBit >> uint(1);
        volumeIdxNext = volumeIndex + 1u;
        volumeIndex = volumeIdxNext;
        arrayIndex = volumeCountTemp;
        currentVolumeBit = bitmaskShifted;
        continue;
    }
    float finalGodrayAccum;
    vec3 finalLastHitPos;
    vec4 finalAccumColor;
    vec3 finalFirstHitPos;
    float finalSunlightAccum;
    do
    {
        VolumeBoxData volumeBoxList[1] = activeVolumeBoxes;
        float totalMarchDistance = length(marchEndPos - marchStartPos);
        int maxStepCount = int(clamp(ceil(totalMarchDistance / baseStepDistance) + 10.0, 1.0, 500.0));
        uint validVolumeCount = min(activeVolumeCount, 1u);
        vec3 cameraSideVector = cross(cameraForward, cameraRight);
        float totalRayDistance = rayMarchStart + totalMarchDistance;
        vec3 currentVolumePos;
        vec4 accumulatedColor;
        vec3 accumulatedTracerDirection;
        vec3 currentMarchPos;
        vec3 lastValidSamplePos;
        accumulatedColor = vec4(0.0);
        accumulatedTracerDirection = vec3(0.0, 0.0, 0.00999999977648258209228515625);
        currentMarchPos = marchStartPos;
        lastValidSamplePos = marchEndPos;
        currentVolumePos = marchEndPos;
        float nextRayDistance;
        vec3 nextMarchPos;
        int nextStepIndex;
        vec3 loopLastHitTemp;
        vec3 loopLastHitPos;
        bool hadPreviousSample;
        vec3 loopFirstHitTemp;
        vec3 loopFirstHitPos;
        bool innerLoopBreak;
        bool foundOpaqueVolume;
        float loopSunlight;
        float loopGodray;
        vec4 loopColor;
        float loopTracerGlow;
        vec3 loopTracerDir;
        float loopCavityStr;
        bool loopHadPrevSample;
        float loopSunlightOut;
        uint loopTracerBits;
        float loopGodrayOut;
        vec4 loopColorOut;
        float loopTracerGlowOut;
        vec3 loopTracerDirOut;
        float loopCavityStrOut;
        uint loopTracerBitsOut;
        float loopRayTOut;
        bool foundOpaqueFlag = false;
        float accumulatedLightEnergy = 0.0;
        float accumulatedFogDensity = 0.0;
        float accumulatedTracerGlow = 0.0;
        float tracerCavityStrength = 0.0;
        uint tracerAnimationCounter = 0u;
        float currentRayDistance = rayMarchStart;
        bool hasValidSample = false;
        int stepIndex = 0;
        for (;;)
        {
            if (!(stepIndex < maxStepCount))
            {
                loopLastHitPos = lastValidSamplePos;
                loopFirstHitPos = currentVolumePos;
                loopHadPrevSample = hasValidSample;
                loopSunlightOut = accumulatedLightEnergy;
                loopGodrayOut = accumulatedFogDensity;
                loopColorOut = accumulatedColor;
                loopTracerGlowOut = accumulatedTracerGlow;
                loopTracerDirOut = accumulatedTracerDirection;
                loopCavityStrOut = tracerCavityStrength;
                loopTracerBitsOut = tracerAnimationCounter;
                loopRayTOut = currentRayDistance;
                foundOpaqueVolume = foundOpaqueFlag;
                break;
            }
            bool shouldUpdateTracerAnim;
            if (activeTracerCount > 0u)
            {
                bool cacheRefreshCheck;
                if ((stepIndex & 15) == 0)
                {
                    cacheRefreshCheck = true;
                }
                else
                {
                    cacheRefreshCheck = stepIndex < 16;
                }
                shouldUpdateTracerAnim = cacheRefreshCheck;
            }
            else
            {
                shouldUpdateTracerAnim = false;
            }
            float tracerGlowIntensity = shouldUpdateTracerAnim ? 0.0 : accumulatedTracerGlow;
            float tracerCavityStrength = shouldUpdateTracerAnim ? 0.0 : tracerCavityStrength;
            uint tracerAnimBits = shouldUpdateTracerAnim ? 0u : tracerAnimationCounter;
            vec3 samplePosition;
            vec4 stepColor;
            vec3 stepTracerDir;
            samplePosition = currentVolumePos;
            hadPreviousSample = hasValidSample;
            stepColor = accumulatedColor;
            stepTracerDir = mix(accumulatedTracerDirection, vec3(0.0, 0.0, 0.00999999977648258209228515625), bvec3(shouldUpdateTracerAnim));
            uint volumeCheckIdxNext;
            vec3 samplePosUpdate;
            float cavityStrUpdate;
            bool hadPrevSampleUpdate;
            float sunlightUpdate;
            float godrayUpdate;
            vec4 colorUpdate;
            float tracerGlowUpdate;
            vec3 tracerDirUpdate;
            uint tracerBitsUpdate;
            uint volumeCheckIndex = 0u;
            float stepLightEnergy = accumulatedLightEnergy;
            float stepFogDensity = accumulatedFogDensity;
            float stepTracerGlow = tracerGlowIntensity;
            float stepCavityStrength = tracerCavityStrength;
            uint stepTracerBits = tracerAnimBits;
            for (;;)
            {
                bool volumeLoopBreak = false;
                do
                {
                    if (!(volumeCheckIndex < validVolumeCount))
                    {
                        loopLastHitTemp = lastValidSamplePos;
                        loopFirstHitTemp = samplePosition;
                        loopSunlight = stepLightEnergy;
                        loopGodray = stepFogDensity;
                        loopColor = stepColor;
                        loopTracerGlow = stepTracerGlow;
                        loopTracerDir = stepTracerDir;
                        loopCavityStr = stepCavityStrength;
                        loopTracerBits = stepTracerBits;
                        innerLoopBreak = foundOpaqueFlag;
                        volumeLoopBreak = true;
                        break;
                    }
                    if (currentRayDistance < volumeBoxList[volumeCheckIndex]._m0.x)
                    {
                        samplePosUpdate = samplePosition;
                        hadPrevSampleUpdate = hadPreviousSample;
                        sunlightUpdate = stepLightEnergy;
                        godrayUpdate = stepFogDensity;
                        colorUpdate = stepColor;
                        tracerGlowUpdate = stepTracerGlow;
                        tracerDirUpdate = stepTracerDir;
                        cavityStrUpdate = stepCavityStrength;
                        tracerBitsUpdate = stepTracerBits;
                        break;
                    }
                    if (currentRayDistance > volumeBoxList[volumeCheckIndex]._m0.y)
                    {
                        samplePosUpdate = samplePosition;
                        hadPrevSampleUpdate = hadPreviousSample;
                        sunlightUpdate = stepLightEnergy;
                        godrayUpdate = stepFogDensity;
                        colorUpdate = stepColor;
                        tracerGlowUpdate = stepTracerGlow;
                        tracerDirUpdate = stepTracerDir;
                        cavityStrUpdate = stepCavityStrength;
                        tracerBitsUpdate = stepTracerBits;
                        break;
                    }
                    vec3 tracerDirection;
                    uint updatedTracerBits;
                    float updatedCavityStrength;
                    float updatedTracerGlow;
                    do
                    {
                        bool skipTracerCalc;
                        if (activeTracerCount == 0u)
                        {
                            skipTracerCalc = true;
                        }
                        else
                        {
                            skipTracerCalc = (stepTracerBits & 3u) != 0u;
                        }
                        if (skipTracerCalc)
                        {
                            updatedTracerBits = stepTracerBits;
                            updatedTracerGlow = stepTracerGlow;
                            updatedCavityStrength = stepCavityStrength;
                            tracerDirection = stepTracerDir;
                            break;
                        }
                        float tracerGlowLoop;
                        vec3 tracerDirLoop;
                        float cavityStrLoop;
                        tracerGlowLoop = stepTracerGlow;
                        tracerDirLoop = stepTracerDir;
                        cavityStrLoop = stepCavityStrength;
                        uint tracerIdxNext;
                        vec3 tracerDirResult;
                        float cavityStrResult;
                        float tracerGlowResult;
                        uint tracerLoopIdx = 0u;
                        for (;;)
                        {
                            if (!(tracerLoopIdx < min(activeTracerCount, 16u)))
                            {
                                break;
                            }
                            vec3 tracerLineDir = bulletTracerEnds._m0[tracerLoopIdx].xyz - bulletTracerStarts._m0[tracerLoopIdx].xyz;
                            vec3 posToTracerStart = currentMarchPos - bulletTracerStarts._m0[tracerLoopIdx].xyz;
                            float distToTracerLine = clamp((length(posToTracerStart - (tracerLineDir * clamp(dot(posToTracerStart, tracerLineDir) / dot(tracerLineDir, tracerLineDir), 0.0, 1.0))) * 0.0500000007450580596923828125) * tracerInfluenceParams._m0[tracerLoopIdx].x, 0.0, 1.0);
                            float tracerFadeInOut = smoothstep(0.0, 0.00999999977648258209228515625, bulletTracerStarts._m0[tracerLoopIdx].w) * (1.0 - smoothstep(0.00999999977648258209228515625, 0.20000000298023223876953125, bulletTracerStarts._m0[tracerLoopIdx].w));
                            float spotTracerGlow;
                            if (distToTracerLine < 1.0)
                            {
                                float tracerWindInfluence = max(cavityStrLoop, smoothstep(0.0, 1.0, 1.0 - clamp(bulletTracerStarts._m0[tracerLoopIdx].w + clamp(distToTracerLine + (1.0 - clamp(length(currentMarchPos - bulletTracerEnds._m0[tracerLoopIdx].xyz) * 0.00999999977648258209228515625, 0.0, 1.0)), 0.0, 1.0), 0.0, 1.0)));
                                tracerDirResult = mix(tracerDirLoop, normalize(bulletTracerStarts._m0[tracerLoopIdx].xyz - bulletTracerEnds._m0[tracerLoopIdx].xyz), vec3(tracerWindInfluence));
                                cavityStrResult = tracerWindInfluence;
                                spotTracerGlow = (pow(1.0 - distToTracerLine, 64.0) * tracerFadeInOut) * 10.0;
                            }
                            else
                            {
                                tracerDirResult = tracerDirLoop;
                                cavityStrResult = cavityStrLoop;
                                spotTracerGlow = 0.0;
                            }
                            if (bulletTracerEnds._m0[tracerLoopIdx].w > 0.0)
                            {
                                float pointTracerGlow = (1.0 - clamp(length(posToTracerStart) * 0.00999999977648258209228515625, 0.0, 1.0)) * tracerFadeInOut;
                                tracerGlowResult = max(tracerGlowLoop, max(pointTracerGlow * pointTracerGlow, spotTracerGlow));
                            }
                            else
                            {
                                tracerGlowResult = tracerGlowLoop;
                            }
                            tracerIdxNext = tracerLoopIdx + 1u;
                            tracerGlowLoop = tracerGlowResult;
                            tracerDirLoop = tracerDirResult;
                            cavityStrLoop = cavityStrResult;
                            tracerLoopIdx = tracerIdxNext;
                            continue;
                        }
                        updatedTracerBits = stepTracerBits | 1u;
                        updatedTracerGlow = tracerGlowLoop;
                        updatedCavityStrength = cavityStrLoop;
                        tracerDirection = tracerDirLoop;
                        break;
                    } while(false);
                    uint currentVolumeIdx = uint(volumeBoxList[volumeCheckIndex]._m0.z);
                    bool hasValidSample;
                    float sampleSunlight;
                    vec4 sampleColor;
                    float sampleGodray;
                    do
                    {
                        vec3 tracerOffsetSamplePos = currentMarchPos + ((normalize(tracerDirection) * pow(updatedCavityStrength, 3.0)) * 20.0);
                        int volumeIdxInt = int(currentVolumeIdx);
                        vec3 volumeLocalPos = clamp((((tracerOffsetSamplePos - volumeCenters._m0[volumeIdxInt].xyz) * vec3(0.0500000007450580596923828125)) + vec3(16.0)) * vec3(0.03125), vec3(0.0), vec3(1.0));
                        vec3 volumeUVW = clamp(volumeLocalPos, vec3(0.0), vec3(1.0));
                        uint densityPageIdx = uint(volumeAnimState._m0[currentVolumeIdx].z);
                        float densityUOffset = 34.0 * float(densityPageIdx);
                        volumeUVW.x = (densityUOffset + (volumeUVW.x * 32.0)) * 0.0018450184725224971771240234375;
                        vec4 densitySample = textureLod(sampler3D(volumeDensityTexture, volumeSampler), volumeUVW.xyz, 0.0);
                        vec2 densityChannels = mix(densitySample.xz, densitySample.yw, vec2(volumeAnimState._m0[currentVolumeIdx].y));
                        float sampledDensityMin = densityChannels.x;
                        float sampledDensityMax = densityChannels.y;
                        vec4 densityVec4Temp;
                        densityVec4Temp.w = sampledDensityMax;
                        float distanceToMarchEnd = distance(tracerOffsetSamplePos, marchEndPos);
                        vec4 adjustedDensity;
                        if (sampledDensityMin > sampledDensityMax)
                        {
                            vec4 densityBlendTemp;
                            densityBlendTemp.w = mix(sampledDensityMax, sampledDensityMin, smoothstep(10.0, 40.0, distanceToMarchEnd));
                            adjustedDensity = densityBlendTemp;
                        }
                        else
                        {
                            adjustedDensity = densityVec4Temp.xyzw;
                        }
                        float cavityDensity = clamp(mix(adjustedDensity.w, -0.0500000007450580596923828125, updatedCavityStrength), 0.0, 1.0);
                        if (cavityDensity > 0.00999999977648258209228515625)
                        {
                            float occlusionDistance = max(0.0, distanceToMarchEnd - min(20.0, abs(backProjectedPoint.z - volumeCenters._m0[volumeIdxInt].z) * 2.0));
                            float densityMultiplier = clamp(clamp((cavityDensity - 0.00999999977648258209228515625) * 1.01010096073150634765625, 0.0, 1.0), 0.0, 1.0) * volumeFadeParams._m0[currentVolumeIdx].x;
                            float finalScaledDensity = clamp(densityMultiplier + ((1.0 - clamp(distance(cameraPosition, tracerOffsetSamplePos) * 0.100000001490116119384765625, 0.0, 1.0)) * densityMultiplier), 0.0, 1.0);
                            vec3 shadowTestPos;
                            float shadowMultiplier;
                            float effectiveDensity;
                            float shadowAmount;
                            if (hasExplosionLayer)
                            {
                                vec3 dissipLoopPos;
                                float dissipAccum;
                                float dissipScale;
                                dissipLoopPos = tracerOffsetSamplePos;
                                dissipAccum = 0.0;
                                dissipScale = 1.0;
                                uint dissipIdxNext;
                                vec3 dissipPosResult;
                                float dissipScaleResult;
                                float dissipAccumResult;
                                uint dissipLoopIdx = 0u;
                                for (;;)
                                {
                                    bool dissipLoopBreak = false;
                                    do
                                    {
                                        if (!(dissipLoopIdx < min(explosionCount, 5u)))
                                        {
                                            dissipLoopBreak = true;
                                            break;
                                        }
                                        if ((uint(volumeTracerMasks._m0[dissipLoopIdx >> uint(2)][dissipLoopIdx & 3u]) & (1u << densityPageIdx)) == 0u)
                                        {
                                            dissipPosResult = dissipLoopPos;
                                            dissipScaleResult = dissipScale;
                                            dissipAccumResult = dissipAccum;
                                            break;
                                        }
                                        float dissipationAge = animationTime - explosionPositions._m0[dissipLoopIdx].w;
                                        vec3 dissipPosInterim;
                                        float dissipScaleInterim;
                                        float dissipEffectInterim;
                                        if (dissipationAge < (volumeAnimState._m0[currentVolumeIdx].x - 0.4000000059604644775390625))
                                        {
                                            float distToDissipPoint = distance(dissipLoopPos, explosionPositions._m0[dissipLoopIdx].xyz);
                                            vec3 dissipPosInner;
                                            float dissipScaleInner;
                                            float dissipEffectInner;
                                            if (distToDissipPoint < 250.0)
                                            {
                                                float dissipationPulse = pow(1.0 - smoothstep(0.0, 2.0, dissipationAge), 128.0);
                                                float surfaceProximity;
                                                if (!skipDueToOcclusion)
                                                {
                                                    surfaceProximity = clamp((48.0 - occlusionDistance) * 0.02083333395421504974365234375, 0.0, 1.0) * (1.0 - smoothstep(0.0, 7.0, dissipationAge));
                                                }
                                                else
                                                {
                                                    surfaceProximity = dissipAccum;
                                                }
                                                dissipPosInner = mix(dissipLoopPos, explosionPositions._m0[dissipLoopIdx].xyz, vec3(((1.0 - smoothstep(100.0, 250.0, distToDissipPoint)) * step(dissipationAge * 1250.0, distToDissipPoint)) * (1.0 - dissipationPulse)));
                                                dissipScaleInner = min(dissipScale, max(smoothstep(200.0, 240.0, distToDissipPoint + (dissipationPulse * 250.0)) + pow(smoothstep(0.5, 5.0, dissipationAge), 1.7999999523162841796875), surfaceProximity));
                                                dissipEffectInner = surfaceProximity;
                                            }
                                            else
                                            {
                                                dissipPosInner = dissipLoopPos;
                                                dissipScaleInner = dissipScale;
                                                dissipEffectInner = dissipAccum;
                                            }
                                            dissipPosInterim = dissipPosInner;
                                            dissipScaleInterim = dissipScaleInner;
                                            dissipEffectInterim = dissipEffectInner;
                                        }
                                        else
                                        {
                                            dissipPosInterim = dissipLoopPos;
                                            dissipScaleInterim = dissipScale;
                                            dissipEffectInterim = dissipAccum;
                                        }
                                        dissipPosResult = dissipPosInterim;
                                        dissipScaleResult = dissipScaleInterim;
                                        dissipAccumResult = dissipEffectInterim;
                                        break;
                                    } while(false);
                                    if (dissipLoopBreak)
                                    {
                                        break;
                                    }
                                    dissipIdxNext = dissipLoopIdx + 1u;
                                    dissipLoopPos = dissipPosResult;
                                    dissipAccum = dissipAccumResult;
                                    dissipScale = dissipScaleResult;
                                    dissipLoopIdx = dissipIdxNext;
                                    continue;
                                }
                                shadowMultiplier = dissipScale;
                                shadowAmount = dissipAccum;
                                effectiveDensity = mix(finalScaledDensity * 0.0199999995529651641845703125, finalScaledDensity, dissipScale);
                                shadowTestPos = dissipLoopPos;
                            }
                            else
                            {
                                shadowMultiplier = 1.0;
                                shadowAmount = 0.0;
                                effectiveDensity = finalScaledDensity;
                                shadowTestPos = tracerOffsetSamplePos;
                            }
                            float animTime = globalTime * timeScale;
                            vec3 volumeCenteredPos = volumeLocalPos - vec3(0.5);
                            vec3 noiseCoord = volumeCenteredPos * 7.0;
                            float noiseZ = noiseCoord.z;
                            float rotAngle1 = animTime * 0.5;
                            float rotOffset = (animTime * 0.039999999105930328369140625) + ((((0.20000000298023223876953125 + ((sin(noiseZ * 5.0) + 0.5) * 0.1500000059604644775390625)) * sin(rotAngle1 + 0.5)) * sin((animTime * 0.1870000064373016357421875) + 0.5)) * 0.20000000298023223876953125);
                            float sinRot = sin(rotOffset);
                            float cosRot = cos(rotOffset);
                            vec2 rotatedXY = noiseCoord.xy * mat2(vec2(cosRot, -sinRot), vec2(sinRot, cosRot));
                            float rotatedX = rotatedXY.x;
                            vec3 noisePosTemp = noiseCoord;
                            noisePosTemp.x = rotatedX;
                            float rotatedY = rotatedXY.y;
                            float waveTime = animTime + (sin(rotAngle1) * 0.0199999995529651641845703125);
                            vec2 waveOffset = noisePosTemp.xz + (vec2(sin(waveTime + (noiseZ * 2.7000000476837158203125)), cos(waveTime + (rotatedX * 2.7000000476837158203125))) * 0.0500000007450580596923828125);
                            float perturbedX = waveOffset.x;
                            float perturbedZ = waveOffset.y;
                            vec3 noisePosPerturbed = vec3(perturbedX, rotatedY, perturbedZ);
                            float finalNoiseZ = perturbedZ + ((sin((perturbedX * 3.0) + (animTime * 0.3499999940395355224609375)) + sin((rotatedY * 2.8399999141693115234375) + (animTime * 0.23499999940395355224609375))) * 0.0500000007450580596923828125);
                            noisePosPerturbed.z = finalNoiseZ;
                            vec3 baseNoiseCoord = noisePosPerturbed * noise1Scale;
                            vec3 timeOffset3D = vec3(2.0, 2.0, 4.5) * (animTime * 0.100000001490116119384765625);
                            vec3 camRightOffset = cameraRight * 0.20000000298023223876953125;
                            vec3 camUpOffset = cameraSideVector * 0.20000000298023223876953125;
                            vec4 noisePowerVec = vec4(noisePower);
                            vec4 rawNoiseSample = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((abs(baseNoiseCoord) - timeOffset3D) * 0.070000000298023223876953125).xyz, 0.0), noisePowerVec);
                            vec4 lowFreqParams = vec4(noiseColorA);
                            vec4 highFreqParams = vec4(noiseColorB);
                            vec4 noiseBlendParam = vec4(noiseMixFactor);
                            vec4 baseNoiseProcessed = mix(mix(lowFreqParams, highFreqParams, rawNoiseSample), mix(vec4(0.25), vec4(-1.5), rawNoiseSample), noiseBlendParam);
                            float baseNoiseCombined = (baseNoiseProcessed.x + (baseNoiseProcessed.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 noiseSampleX = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((abs(baseNoiseCoord + camRightOffset) - timeOffset3D) * 0.070000000298023223876953125).xyz, 0.0), noisePowerVec);
                            vec4 processedNoiseX = mix(mix(lowFreqParams, highFreqParams, noiseSampleX), mix(vec4(0.25), vec4(-1.5), noiseSampleX), noiseBlendParam);
                            vec4 noiseSampleY = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((abs(baseNoiseCoord + camUpOffset) - timeOffset3D) * 0.070000000298023223876953125).xyz, 0.0), noisePowerVec);
                            vec4 processedNoiseY = mix(mix(lowFreqParams, highFreqParams, noiseSampleY), mix(vec4(0.25), vec4(-1.5), noiseSampleY), noiseBlendParam);
                            float normalGradStep = 0.800000011920928955078125 / noise1Scale;
                            vec3 noiseNormal = normalize(vec3(baseNoiseCombined - ((processedNoiseY.x + (processedNoiseY.y * 0.949999988079071044921875)) * 4.599999904632568359375), baseNoiseCombined - ((processedNoiseX.x + (processedNoiseX.y * 0.949999988079071044921875)) * 4.599999904632568359375), normalGradStep));
                            mat4 viewTransform = mat4(vec4(invViewProjMatrix._m0[0].x, invViewProjMatrix._m0[1].x, invViewProjMatrix._m0[2].x, invViewProjMatrix._m0[3].x), vec4(invViewProjMatrix._m0[0].y, invViewProjMatrix._m0[1].y, invViewProjMatrix._m0[2].y, invViewProjMatrix._m0[3].y), vec4(invViewProjMatrix._m0[0].z, invViewProjMatrix._m0[1].z, invViewProjMatrix._m0[2].z, invViewProjMatrix._m0[3].z), vec4(invViewProjMatrix._m0[0].w, invViewProjMatrix._m0[1].w, invViewProjMatrix._m0[2].w, invViewProjMatrix._m0[3].w));
                            float centeredPosZ = volumeCenteredPos.z;
                            vec3 detailNoiseCoord = (noiseCoord + ((((viewTransform * vec4((noiseNormal + vec3(0.0, 0.0, 1.0)).xyz, 0.0)).xyz * pow(baseNoiseCombined, 0.100000001490116119384765625)) * normalDetailScale) * 0.20000000298023223876953125)) + (vec3(2.0, 2.0, 4.5) * ((((baseNoiseCombined - 1.0) * 0.20000000298023223876953125) * normalDetailScale) * centeredPosZ));
                            detailNoiseCoord.x = detailNoiseCoord.x + (sin(finalNoiseZ + (animTime * 0.25)) * 0.0500000007450580596923828125);
                            vec3 detailScaledCoord = detailNoiseCoord * noise2Scale;
                            vec4 detailNoiseSample = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), (detailScaledCoord * 0.070000000298023223876953125).xyz, 0.0), noisePowerVec);
                            vec4 detailNoiseProcessed = mix(mix(lowFreqParams, highFreqParams, detailNoiseSample), mix(vec4(0.25), vec4(-1.5), detailNoiseSample), noiseBlendParam);
                            float detailNoiseCombined = (detailNoiseProcessed.x + (detailNoiseProcessed.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 detailSampleX = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((detailScaledCoord + camRightOffset) * 0.070000000298023223876953125).xyz, 0.0), noisePowerVec);
                            vec4 detailProcessedX = mix(mix(lowFreqParams, highFreqParams, detailSampleX), mix(vec4(0.25), vec4(-1.5), detailSampleX), noiseBlendParam);
                            vec4 detailSampleY = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((detailScaledCoord + camUpOffset) * 0.070000000298023223876953125).xyz, 0.0), noisePowerVec);
                            vec4 detailProcessedY = mix(mix(lowFreqParams, highFreqParams, detailSampleY), mix(vec4(0.25), vec4(-1.5), detailSampleY), noiseBlendParam);
                            float depthFade = detailNoiseInfluence * (dot(rayDirection, cameraForward) * clamp(distance(shadowTestPos, cameraPosition) * 0.004999999888241291046142578125, 0.0, 1.0));
                            float combinedNoise = (mix(0.949999988079071044921875, clamp(baseNoiseCombined, 0.0, 1.0), noise1Influence) + mix(0.949999988079071044921875, clamp(detailNoiseCombined, 0.0, 1.0), depthFade * 0.25)) + noiseOffset;
                            float heightFade;
                            if (volumeFadeParams._m0[currentVolumeIdx].w < 1.0)
                            {
                                float heightParam = clamp(volumeFadeParams._m0[currentVolumeIdx].w, 9.9999997473787516355514526367188e-05, 0.99989998340606689453125);
                                float fadeStart = smoothstep(0.0, 0.800000011920928955078125, heightParam);
                                float fadeEnd = smoothstep(0.20000000298023223876953125, 1.0, heightParam);
                                float heightFadeResult;
                                if (fadeStart == fadeEnd)
                                {
                                    heightFadeResult = effectiveDensity * heightParam;
                                }
                                else
                                {
                                    vec3 heightTestPos = volumeCenteredPos;
                                    heightTestPos.z = centeredPosZ * 1.2000000476837158203125;
                                    heightFadeResult = effectiveDensity * clamp(smoothstep(fadeStart, fadeEnd, clamp(length(heightTestPos), 0.0, 1.0)), 0.0, 1.0);
                                }
                                heightFade = heightFadeResult;
                            }
                            else
                            {
                                heightFade = effectiveDensity;
                            }
                            float stepDensity = mix(heightFade - (1.0 - combinedNoise), heightFade + combinedNoise, heightFade) * clamp((volumeFadeParams._m0[currentVolumeIdx].x * volumeFadeParams._m0[currentVolumeIdx].w) * 8.0, 0.0, 1.0);
                            if (stepDensity < 9.9999997473787516355514526367188e-05)
                            {
                                sampleSunlight = stepLightEnergy;
                                sampleGodray = stepFogDensity;
                                sampleColor = stepColor;
                                hasValidSample = false;
                                break;
                            }
                            vec3 baseNormalDir = normalize(volumeCenteredPos) * mix(1.0, 0.0, clamp(shadowAmount, 0.0, 1.0));
                            vec4 normalTransform = viewTransform * vec4(((vec4(baseNormalDir.xyz, 0.0).xyzw * viewTransform).xyz + ((vec3((noiseNormal.xy * noise1Influence) + ((normalize(vec3(detailNoiseCombined - ((detailProcessedY.x + (detailProcessedY.y * 0.949999988079071044921875)) * 4.599999904632568359375), detailNoiseCombined - ((detailProcessedX.x + (detailProcessedX.y * 0.949999988079071044921875)) * 4.599999904632568359375), normalGradStep)) * mix(0.5, 1.0, clamp(baseNoiseCombined - 0.5, 0.0, 1.0))).xy * (depthFade * 1.5)), 0.0) * normalPerturbScale) * mix(1.0, 2.0, clamp((200.0 - distance(shadowTestPos, volumeCenters._m0[volumeIdxInt].xyz)) * 0.004999999888241291046142578125, 0.0, 1.0)))).xyz, 0.0);
                            vec3 viewSpaceNormal = normalTransform.xyz;
                            vec3 scatterUVW = clamp(clamp(mix(volumeCenteredPos * dot(baseNormalDir, viewSpaceNormal), normalize(viewSpaceNormal + vec3(0.0, 0.0, 0.5)) * length(volumeCenteredPos), vec3(0.20000000298023223876953125)) + vec3(0.5), vec3(0.02999999932944774627685546875), vec3(0.9700000286102294921875)), vec3(0.0), vec3(1.0));
                            scatterUVW.x = (densityUOffset + (scatterUVW.x * 32.0)) * 0.0018450184725224971771240234375;
                            vec4 scatterColor = textureLod(sampler3D(colorLUTTexture, volumeSampler), scatterUVW.xyz, 0.0);
                            float sunDot = dot(mix(baseNormalDir, viewSpaceNormal, vec3(phaseBlend)), mainLightDirection.xyz);
                            float phaseFunction = pow(clamp((sunDot * 0.800000011920928955078125) + 0.20000000298023223876953125, 0.0, 1.0), 1.5) + pow(clamp((sunDot * 1.39999997615814208984375) - 0.5, 0.0, 1.0), 3.0);
                            float sunScattering;
                            if (phaseFunction > 0.0)
                            {
                                sunScattering = phaseFunction * scatterColor.w;
                            }
                            else
                            {
                                sunScattering = phaseFunction;
                            }
                            float scatterR = scatterColor.x;
                            float scatterG = scatterColor.y;
                            float scatterB = scatterColor.z;
                            float maxRGB = max(scatterR, max(scatterG, scatterB));
                            float colorRange = maxRGB - min(scatterR, min(scatterG, scatterB));
                            vec3 hsvTemp = vec3(0.0);
                            hsvTemp.z = maxRGB;
                            vec3 hsvColor;
                            if (colorRange != 0.0)
                            {
                                float saturation = colorRange / maxRGB;
                                vec3 chromaDelta = (hsvTemp.zzz - scatterColor.xyz) / vec3(colorRange);
                                vec3 hueComponents = chromaDelta.xyz - chromaDelta.zxy;
                                vec2 hueOffset = hueComponents.xy + vec2(2.0, 4.0);
                                vec3 hsvResult;
                                if (scatterR >= maxRGB)
                                {
                                    hsvResult = vec3(hueComponents.z, saturation, maxRGB);
                                }
                                else
                                {
                                    vec3 hsvBranch1;
                                    if (scatterG >= maxRGB)
                                    {
                                        hsvBranch1 = vec3(hueOffset.x, saturation, maxRGB);
                                    }
                                    else
                                    {
                                        hsvBranch1 = vec3(hueOffset.y, saturation, maxRGB);
                                    }
                                    hsvResult = hsvBranch1;
                                }
                                vec3 hsvFinal = hsvResult;
                                hsvFinal.x = fract(hsvResult.x * 0.16666667163372039794921875);
                                hsvColor = hsvFinal;
                            }
                            else
                            {
                                hsvColor = hsvTemp;
                            }
                            float adjustedSat = clamp(hsvColor.y * 1.10000002384185791015625, 0.0, 1.0);
                            vec3 finalRGB;
                            if (adjustedSat != 0.0)
                            {
                                float hueAngle6 = hsvColor.x * 6.0;
                                float hueFloor = floor(hueAngle6);
                                float rgbDesaturated = hsvColor.z * (1.0 - adjustedSat);
                                float hueFraction = hueAngle6 - hueFloor;
                                float rgbInterp1 = hsvColor.z * (1.0 - (adjustedSat * hueFraction));
                                float rgbInterp2 = hsvColor.z * (1.0 - (adjustedSat * (1.0 - hueFraction)));
                                vec3 rgbFromHsv;
                                if (hueFloor == 0.0)
                                {
                                    rgbFromHsv = vec3(hsvColor.z, rgbInterp2, rgbDesaturated);
                                }
                                else
                                {
                                    vec3 rgbBranch1;
                                    if (hueFloor == 1.0)
                                    {
                                        rgbBranch1 = vec3(rgbInterp1, hsvColor.z, rgbDesaturated);
                                    }
                                    else
                                    {
                                        vec3 rgbBranch2;
                                        if (hueFloor == 2.0)
                                        {
                                            rgbBranch2 = vec3(rgbDesaturated, hsvColor.z, rgbInterp2);
                                        }
                                        else
                                        {
                                            vec3 rgbBranch3;
                                            if (hueFloor == 3.0)
                                            {
                                                rgbBranch3 = vec3(rgbDesaturated, rgbInterp1, hsvColor.z);
                                            }
                                            else
                                            {
                                                vec3 rgbBranch4;
                                                if (hueFloor == 4.0)
                                                {
                                                    rgbBranch4 = vec3(rgbInterp2, rgbDesaturated, hsvColor.z);
                                                }
                                                else
                                                {
                                                    rgbBranch4 = vec3(hsvColor.z, rgbDesaturated, rgbInterp1);
                                                }
                                                rgbBranch3 = rgbBranch4;
                                            }
                                            rgbBranch2 = rgbBranch3;
                                        }
                                        rgbBranch1 = rgbBranch2;
                                    }
                                    rgbFromHsv = rgbBranch1;
                                }
                                finalRGB = rgbFromHsv;
                            }
                            else
                            {
                                finalRGB = hsvColor.zzz;
                            }
                            vec3 litColor = (((((((normalize(finalRGB + vec3(0.001000000047497451305389404296875)) * min(length(finalRGB), 4.0)) * clamp(1.0 - min(0.25, stepDensity), 0.0, 1.0)) * clamp(1.0 - (((heightFade * 2.400000095367431640625) - stepDensity) * densityContrast), 0.0, 1.0)) * combinedNoise) * (0.75 + (sunScattering * 0.25))) * (1.0 + (normalTransform.z * 0.5))) * baseColorIntensity) + ((mainLightColor.xyz * ((0.5 * sunScattering) * (1.0 - updatedCavityStrength))) * sunColorIntensity);
                            vec3 volumeTintedColor = litColor * volumeTintColor._m0[currentVolumeIdx].xyz;
                            vec3 desaturatedColor = (mix(litColor, volumeTintedColor * (dot(litColor.xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125)) / dot((volumeTintedColor + vec3(0.001000000047497451305389404296875)).xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125))), vec3(0.5 * (1.0 - volumeFadeParams._m0[currentVolumeIdx].z))) * mix(vec3(1.0), normalize(colorTint + vec3(0.00999999977648258209228515625)) * 1.73199999332427978515625, vec3(clamp(0.5 + (stepDensity * 6.0), 0.0, 1.0)))).xyz;
                            vec3 shadowedColor = mix(desaturatedColor, desaturatedColor * shadowMultiplier, vec3(0.60000002384185791015625)).xyz;
                            float fogAmount = smoothstep(0.0, 0.20000000298023223876953125, stepDensity + 0.300000011920928955078125) * (((clamp((godrayFalloffDist - occlusionDistance) / godrayFalloffDist, 0.0, 1.0) * heightFade) * 6.0) * godrayIntensity);
                            float stepAlpha = smoothstep(0.0, 0.20000000298023223876953125 / (alphaScale * mix(0.5, 2.0, stepColor.w)), stepDensity);
                            vec4 stepContribution = vec4(((shadowedColor + ((shadowedColor * vec3(8.0, 4.0, 0.0)) * updatedTracerGlow)) * mix(1.0, 0.85000002384185791015625, clamp(shadowAmount * 20.0, 0.0, 1.0))) * stepAlpha, stepAlpha);
                            float sunAccumLoop;
                            vec4 colorAccumLoop;
                            float sampleWeight;
                            float fogAccumLoop;
                            sunAccumLoop = stepLightEnergy;
                            colorAccumLoop = stepColor;
                            fogAccumLoop = stepFogDensity;
                            sampleWeight = baseStepSize * 0.375;
                            float sunUpdated;
                            vec4 colorUpdated;
                            float fogUpdated;
                            float weightDecrement;
                            for (;;)
                            {
                                if (!(sampleWeight >= 1.0))
                                {
                                    break;
                                }
                                fogUpdated = fogAccumLoop + fogAmount;
                                colorUpdated = colorAccumLoop + (stepContribution * (1.0 - colorAccumLoop.w));
                                sunUpdated = sunAccumLoop + sunScattering;
                                weightDecrement = sampleWeight - 1.0;
                                sunAccumLoop = sunUpdated;
                                colorAccumLoop = colorUpdated;
                                fogAccumLoop = fogUpdated;
                                sampleWeight = weightDecrement;
                                continue;
                            }
                            sampleSunlight = sunAccumLoop + (sunScattering * sampleWeight);
                            sampleGodray = fogAccumLoop + (fogAmount * sampleWeight);
                            sampleColor = colorAccumLoop + (stepContribution * ((1.0 - colorAccumLoop.w) * sampleWeight));
                            hasValidSample = (stepAlpha + fogAmount) > 0.0;
                            break;
                        }
                        sampleSunlight = stepLightEnergy;
                        sampleGodray = stepFogDensity;
                        sampleColor = stepColor;
                        hasValidSample = false;
                        break;
                    } while(false);
                    volumeBoxList[volumeCheckIndex] = volumeBoxList[volumeCheckIndex];
                    bool shouldRecordHit;
                    if (hasValidSample)
                    {
                        shouldRecordHit = !hadPreviousSample;
                    }
                    else
                    {
                        shouldRecordHit = false;
                    }
                    vec3 firstHitUpdate = mix(samplePosition, currentMarchPos, bvec3(shouldRecordHit));
                    if (sampleColor.w > 0.990999996662139892578125)
                    {
                        vec4 colorClamped = sampleColor;
                        colorClamped.w = 1.0;
                        loopLastHitTemp = currentMarchPos;
                        loopFirstHitTemp = firstHitUpdate;
                        loopSunlight = sampleSunlight;
                        loopGodray = sampleGodray;
                        loopColor = colorClamped;
                        loopTracerGlow = updatedTracerGlow;
                        loopTracerDir = tracerDirection;
                        loopCavityStr = updatedCavityStrength;
                        loopTracerBits = updatedTracerBits;
                        innerLoopBreak = true;
                        volumeLoopBreak = true;
                        break;
                    }
                    samplePosUpdate = firstHitUpdate;
                    hadPrevSampleUpdate = shouldRecordHit ? true : hadPreviousSample;
                    sunlightUpdate = sampleSunlight;
                    godrayUpdate = sampleGodray;
                    colorUpdate = sampleColor;
                    tracerGlowUpdate = updatedTracerGlow;
                    tracerDirUpdate = tracerDirection;
                    cavityStrUpdate = updatedCavityStrength;
                    tracerBitsUpdate = updatedTracerBits;
                    break;
                } while(false);
                if (volumeLoopBreak)
                {
                    break;
                }
                volumeCheckIdxNext = volumeCheckIndex + 1u;
                samplePosition = samplePosUpdate;
                hadPreviousSample = hadPrevSampleUpdate;
                stepLightEnergy = sunlightUpdate;
                stepFogDensity = godrayUpdate;
                stepColor = colorUpdate;
                stepTracerGlow = tracerGlowUpdate;
                stepTracerDir = tracerDirUpdate;
                stepCavityStrength = cavityStrUpdate;
                stepTracerBits = tracerBitsUpdate;
                volumeCheckIndex = volumeCheckIdxNext;
                continue;
            }
            if (innerLoopBreak)
            {
                loopLastHitPos = loopLastHitTemp;
                loopFirstHitPos = loopFirstHitTemp;
                loopHadPrevSample = hadPreviousSample;
                loopSunlightOut = loopSunlight;
                loopGodrayOut = loopGodray;
                loopColorOut = loopColor;
                loopTracerGlowOut = loopTracerGlow;
                loopTracerDirOut = loopTracerDir;
                loopCavityStrOut = loopCavityStr;
                loopTracerBitsOut = loopTracerBits;
                loopRayTOut = currentRayDistance;
                foundOpaqueVolume = innerLoopBreak;
                break;
            }
            nextMarchPos = currentMarchPos + (rayDirection * baseStepDistance);
            nextRayDistance = currentRayDistance + baseStepDistance;
            if (nextRayDistance >= totalRayDistance)
            {
                loopLastHitPos = loopLastHitTemp;
                loopFirstHitPos = loopFirstHitTemp;
                loopHadPrevSample = hadPreviousSample;
                loopSunlightOut = loopSunlight;
                loopGodrayOut = loopGodray;
                loopColorOut = loopColor;
                loopTracerGlowOut = loopTracerGlow;
                loopTracerDirOut = loopTracerDir;
                loopCavityStrOut = loopCavityStr;
                loopTracerBitsOut = loopTracerBits;
                loopRayTOut = nextRayDistance;
                foundOpaqueVolume = innerLoopBreak;
                break;
            }
            nextStepIndex = stepIndex + 1;
            foundOpaqueFlag = innerLoopBreak;
            accumulatedLightEnergy = loopSunlight;
            accumulatedFogDensity = loopGodray;
            accumulatedColor = loopColor;
            accumulatedTracerGlow = loopTracerGlow;
            accumulatedTracerDirection = loopTracerDir;
            tracerCavityStrength = loopCavityStr;
            tracerAnimationCounter = loopTracerBits;
            currentMarchPos = nextMarchPos;
            currentRayDistance = nextRayDistance;
            hasValidSample = hadPreviousSample;
            stepIndex = nextStepIndex;
            lastValidSamplePos = loopLastHitTemp;
            currentVolumePos = loopFirstHitTemp;
            continue;
        }
        if (foundOpaqueVolume)
        {
            finalLastHitPos = loopLastHitPos;
            finalFirstHitPos = loopFirstHitPos;
            finalSunlightAccum = loopSunlightOut;
            finalGodrayAccum = loopGodrayOut;
            finalAccumColor = loopColorOut;
            break;
        }
        vec3 sp2LastHit;
        vec3 sp2FirstHit;
        vec4 sp2Color;
        float sp2Sunlight;
        float sp2Godray;
        if (enableSecondPass != 0)
        {
            float sp2StartT = loopRayTOut - baseStepDistance;
            vec3 sp2StartPos = marchStartPos + (rayDirection * totalMarchDistance);
            float sp2RayLength = totalRayDistance - sp2StartT;
            vec3 sp2CurrentPos;
            vec4 sp2ColorAccum;
            vec3 sp2TracerDir;
            sp2ColorAccum = loopColorOut;
            sp2TracerDir = loopTracerDirOut;
            sp2CurrentPos = loopFirstHitPos;
            uint sp2VolumeIdxNext;
            bool sp2HadPrevSample;
            vec3 sp2LastHitTemp;
            uint sp2TracerBits;
            float sp2Sunlight;
            vec3 sp2FirstHitResult;
            bool sp2EarlyExit;
            float sp2Godray;
            vec4 sp2ColorResult;
            float sp2TracerGlow;
            vec3 sp2TracerDirResult;
            float sp2CavityStr;
            float sp2SunlightOut;
            float sp2GodrayOut;
            vec4 sp2ColorOut;
            vec3 sp2PosOut;
            bool sp2HadSampleState = loopHadPrevSample;
            float sp2SunAccum = loopSunlightOut;
            float sp2FogAccum = loopGodrayOut;
            float sp2CachedGlow = loopTracerGlowOut;
            float sp2CachedCavity = loopCavityStrOut;
            uint sp2CachedBits = loopTracerBitsOut;
            uint sp2VolumeIdx = 0u;
            for (;;)
            {
                bool sp2LoopBreak = false;
                do
                {
                    if (!(sp2VolumeIdx < validVolumeCount))
                    {
                        sp2LastHitTemp = loopLastHitPos;
                        sp2FirstHitResult = sp2CurrentPos;
                        sp2SunlightOut = sp2SunAccum;
                        sp2GodrayOut = sp2FogAccum;
                        sp2ColorOut = sp2ColorAccum;
                        sp2EarlyExit = foundOpaqueVolume;
                        sp2LoopBreak = true;
                        break;
                    }
                    if (sp2StartT < volumeBoxList[sp2VolumeIdx]._m0.x)
                    {
                        sp2HadPrevSample = sp2HadSampleState;
                        sp2Sunlight = sp2SunAccum;
                        sp2Godray = sp2FogAccum;
                        sp2ColorResult = sp2ColorAccum;
                        sp2TracerGlow = sp2CachedGlow;
                        sp2TracerDirResult = sp2TracerDir;
                        sp2CavityStr = sp2CachedCavity;
                        sp2TracerBits = sp2CachedBits;
                        sp2PosOut = sp2CurrentPos;
                        break;
                    }
                    if (sp2StartT > volumeBoxList[sp2VolumeIdx]._m0.y)
                    {
                        sp2HadPrevSample = sp2HadSampleState;
                        sp2Sunlight = sp2SunAccum;
                        sp2Godray = sp2FogAccum;
                        sp2ColorResult = sp2ColorAccum;
                        sp2TracerGlow = sp2CachedGlow;
                        sp2TracerDirResult = sp2TracerDir;
                        sp2CavityStr = sp2CachedCavity;
                        sp2TracerBits = sp2CachedBits;
                        sp2PosOut = sp2CurrentPos;
                        break;
                    }
                    vec3 sp2TracerDir;
                    uint sp2TracerCache;
                    float sp2CavityStr;
                    float sp2TracerGlow;
                    do
                    {
                        bool sp2SkipTracer;
                        if (activeTracerCount == 0u)
                        {
                            sp2SkipTracer = true;
                        }
                        else
                        {
                            sp2SkipTracer = (sp2CachedBits & 3u) != 0u;
                        }
                        if (sp2SkipTracer)
                        {
                            sp2TracerCache = sp2CachedBits;
                            sp2TracerGlow = sp2CachedGlow;
                            sp2CavityStr = sp2CachedCavity;
                            sp2TracerDir = sp2TracerDir;
                            break;
                        }
                        float sp2GlowLoop;
                        vec3 sp2DirLoop;
                        float sp2CavityLoop;
                        sp2GlowLoop = sp2CachedGlow;
                        sp2DirLoop = sp2TracerDir;
                        sp2CavityLoop = sp2CachedCavity;
                        uint sp2TracerIdxNext;
                        vec3 sp2DirResult;
                        float sp2CavityResult;
                        float sp2GlowResult;
                        uint sp2TracerLoopIdx = 0u;
                        for (;;)
                        {
                            if (!(sp2TracerLoopIdx < min(activeTracerCount, 16u)))
                            {
                                break;
                            }
                            vec3 sp2TracerLineDir = bulletTracerEnds._m0[sp2TracerLoopIdx].xyz - bulletTracerStarts._m0[sp2TracerLoopIdx].xyz;
                            vec3 sp2PosToTracer = sp2StartPos - bulletTracerStarts._m0[sp2TracerLoopIdx].xyz;
                            float sp2DistToLine = clamp((length(sp2PosToTracer - (sp2TracerLineDir * clamp(dot(sp2PosToTracer, sp2TracerLineDir) / dot(sp2TracerLineDir, sp2TracerLineDir), 0.0, 1.0))) * 0.0500000007450580596923828125) * tracerInfluenceParams._m0[sp2TracerLoopIdx].x, 0.0, 1.0);
                            float sp2TracerFade = smoothstep(0.0, 0.00999999977648258209228515625, bulletTracerStarts._m0[sp2TracerLoopIdx].w) * (1.0 - smoothstep(0.00999999977648258209228515625, 0.20000000298023223876953125, bulletTracerStarts._m0[sp2TracerLoopIdx].w));
                            float sp2SpotGlow;
                            if (sp2DistToLine < 1.0)
                            {
                                float sp2WindInfluence = max(sp2CavityLoop, smoothstep(0.0, 1.0, 1.0 - clamp(bulletTracerStarts._m0[sp2TracerLoopIdx].w + clamp(sp2DistToLine + (1.0 - clamp(length(sp2StartPos - bulletTracerEnds._m0[sp2TracerLoopIdx].xyz) * 0.00999999977648258209228515625, 0.0, 1.0)), 0.0, 1.0), 0.0, 1.0)));
                                sp2DirResult = mix(sp2DirLoop, normalize(bulletTracerStarts._m0[sp2TracerLoopIdx].xyz - bulletTracerEnds._m0[sp2TracerLoopIdx].xyz), vec3(sp2WindInfluence));
                                sp2CavityResult = sp2WindInfluence;
                                sp2SpotGlow = (pow(1.0 - sp2DistToLine, 64.0) * sp2TracerFade) * 10.0;
                            }
                            else
                            {
                                sp2DirResult = sp2DirLoop;
                                sp2CavityResult = sp2CavityLoop;
                                sp2SpotGlow = 0.0;
                            }
                            if (bulletTracerEnds._m0[sp2TracerLoopIdx].w > 0.0)
                            {
                                float sp2PointGlow = (1.0 - clamp(length(sp2PosToTracer) * 0.00999999977648258209228515625, 0.0, 1.0)) * sp2TracerFade;
                                sp2GlowResult = max(sp2GlowLoop, max(sp2PointGlow * sp2PointGlow, sp2SpotGlow));
                            }
                            else
                            {
                                sp2GlowResult = sp2GlowLoop;
                            }
                            sp2TracerIdxNext = sp2TracerLoopIdx + 1u;
                            sp2GlowLoop = sp2GlowResult;
                            sp2DirLoop = sp2DirResult;
                            sp2CavityLoop = sp2CavityResult;
                            sp2TracerLoopIdx = sp2TracerIdxNext;
                            continue;
                        }
                        sp2TracerCache = sp2CachedBits | 1u;
                        sp2TracerGlow = sp2GlowLoop;
                        sp2CavityStr = sp2CavityLoop;
                        sp2TracerDir = sp2DirLoop;
                        break;
                    } while(false);
                    uint sp2VolumeId = uint(volumeBoxList[sp2VolumeIdx]._m0.z);
                    bool sp2HasDensity;
                    float sp2SampleSun;
                    vec4 sp2SampleColor;
                    float sp2SampleGodray;
                    do
                    {
                        vec3 sp2OffsetPos = sp2StartPos + ((normalize(sp2TracerDir) * pow(sp2CavityStr, 3.0)) * 20.0);
                        int sp2VolumeIdxInt = int(sp2VolumeId);
                        vec3 sp2LocalPos = clamp((((sp2OffsetPos - volumeCenters._m0[sp2VolumeIdxInt].xyz) * vec3(0.0500000007450580596923828125)) + vec3(16.0)) * vec3(0.03125), vec3(0.0), vec3(1.0));
                        vec3 sp2VolumeUVW = clamp(sp2LocalPos, vec3(0.0), vec3(1.0));
                        uint sp2DensityPageIdx = uint(volumeAnimState._m0[sp2VolumeId].z);
                        float sp2UOffset = 34.0 * float(sp2DensityPageIdx);
                        sp2VolumeUVW.x = (sp2UOffset + (sp2VolumeUVW.x * 32.0)) * 0.0018450184725224971771240234375;
                        vec4 sp2DensitySample = textureLod(sampler3D(volumeDensityTexture, volumeSampler), sp2VolumeUVW.xyz, 0.0);
                        vec2 sp2DensityChannels = mix(sp2DensitySample.xz, sp2DensitySample.yw, vec2(volumeAnimState._m0[sp2VolumeId].y));
                        float sp2DensityMin = sp2DensityChannels.x;
                        float sp2DensityMax = sp2DensityChannels.y;
                        vec4 sp2DensityVec4;
                        sp2DensityVec4.w = sp2DensityMax;
                        float sp2DistToEnd = distance(sp2OffsetPos, marchEndPos);
                        vec4 sp2AdjustedDens;
                        if (sp2DensityMin > sp2DensityMax)
                        {
                            vec4 sp2DensityBlend;
                            sp2DensityBlend.w = mix(sp2DensityMax, sp2DensityMin, smoothstep(10.0, 40.0, sp2DistToEnd));
                            sp2AdjustedDens = sp2DensityBlend;
                        }
                        else
                        {
                            sp2AdjustedDens = sp2DensityVec4.xyzw;
                        }
                        float sp2CavityDens = clamp(mix(sp2AdjustedDens.w, -0.0500000007450580596923828125, sp2CavityStr), 0.0, 1.0);
                        if (sp2CavityDens > 0.00999999977648258209228515625)
                        {
                            float sp2OcclusionDist = max(0.0, sp2DistToEnd - min(20.0, abs(backProjectedPoint.z - volumeCenters._m0[sp2VolumeIdxInt].z) * 2.0));
                            float sp2DensMult = clamp(clamp((sp2CavityDens - 0.00999999977648258209228515625) * 1.01010096073150634765625, 0.0, 1.0), 0.0, 1.0) * volumeFadeParams._m0[sp2VolumeId].x;
                            float sp2ScaledDens = clamp(sp2DensMult + ((1.0 - clamp(distance(cameraPosition, sp2OffsetPos) * 0.100000001490116119384765625, 0.0, 1.0)) * sp2DensMult), 0.0, 1.0);
                            vec3 sp2ShadowTestPos;
                            float sp2ShadowMult;
                            float sp2EffectiveDens;
                            float sp2ShadowAmount;
                            if (hasExplosionLayer)
                            {
                                vec3 sp2DissipLoopPos;
                                float sp2DissipAccum;
                                float sp2DissipScale;
                                sp2DissipLoopPos = sp2OffsetPos;
                                sp2DissipAccum = 0.0;
                                sp2DissipScale = 1.0;
                                uint sp2DissipIdxNext;
                                vec3 sp2DissipPosRes;
                                float sp2DissipScaleRes;
                                float sp2DissipAccumRes;
                                uint sp2DissipLoopIdx = 0u;
                                for (;;)
                                {
                                    bool sp2DissipBreak = false;
                                    do
                                    {
                                        if (!(sp2DissipLoopIdx < min(explosionCount, 5u)))
                                        {
                                            sp2DissipBreak = true;
                                            break;
                                        }
                                        if ((uint(volumeTracerMasks._m0[sp2DissipLoopIdx >> uint(2)][sp2DissipLoopIdx & 3u]) & (1u << sp2DensityPageIdx)) == 0u)
                                        {
                                            sp2DissipPosRes = sp2DissipLoopPos;
                                            sp2DissipScaleRes = sp2DissipScale;
                                            sp2DissipAccumRes = sp2DissipAccum;
                                            break;
                                        }
                                        float sp2DissipAge = animationTime - explosionPositions._m0[sp2DissipLoopIdx].w;
                                        vec3 sp2DissipPosInt;
                                        float sp2DissipScaleInt;
                                        float sp2DissipEffectInt;
                                        if (sp2DissipAge < (volumeAnimState._m0[sp2VolumeId].x - 0.4000000059604644775390625))
                                        {
                                            float sp2DistToDissip = distance(sp2DissipLoopPos, explosionPositions._m0[sp2DissipLoopIdx].xyz);
                                            vec3 sp2DissipPosInner;
                                            float sp2DissipScaleInner;
                                            float sp2DissipEffectInner;
                                            if (sp2DistToDissip < 250.0)
                                            {
                                                float sp2DissipPulse = pow(1.0 - smoothstep(0.0, 2.0, sp2DissipAge), 128.0);
                                                float sp2SurfaceProx;
                                                if (!skipDueToOcclusion)
                                                {
                                                    sp2SurfaceProx = clamp((48.0 - sp2OcclusionDist) * 0.02083333395421504974365234375, 0.0, 1.0) * (1.0 - smoothstep(0.0, 7.0, sp2DissipAge));
                                                }
                                                else
                                                {
                                                    sp2SurfaceProx = sp2DissipAccum;
                                                }
                                                sp2DissipPosInner = mix(sp2DissipLoopPos, explosionPositions._m0[sp2DissipLoopIdx].xyz, vec3(((1.0 - smoothstep(100.0, 250.0, sp2DistToDissip)) * step(sp2DissipAge * 1250.0, sp2DistToDissip)) * (1.0 - sp2DissipPulse)));
                                                sp2DissipScaleInner = min(sp2DissipScale, max(smoothstep(200.0, 240.0, sp2DistToDissip + (sp2DissipPulse * 250.0)) + pow(smoothstep(0.5, 5.0, sp2DissipAge), 1.7999999523162841796875), sp2SurfaceProx));
                                                sp2DissipEffectInner = sp2SurfaceProx;
                                            }
                                            else
                                            {
                                                sp2DissipPosInner = sp2DissipLoopPos;
                                                sp2DissipScaleInner = sp2DissipScale;
                                                sp2DissipEffectInner = sp2DissipAccum;
                                            }
                                            sp2DissipPosInt = sp2DissipPosInner;
                                            sp2DissipScaleInt = sp2DissipScaleInner;
                                            sp2DissipEffectInt = sp2DissipEffectInner;
                                        }
                                        else
                                        {
                                            sp2DissipPosInt = sp2DissipLoopPos;
                                            sp2DissipScaleInt = sp2DissipScale;
                                            sp2DissipEffectInt = sp2DissipAccum;
                                        }
                                        sp2DissipPosRes = sp2DissipPosInt;
                                        sp2DissipScaleRes = sp2DissipScaleInt;
                                        sp2DissipAccumRes = sp2DissipEffectInt;
                                        break;
                                    } while(false);
                                    if (sp2DissipBreak)
                                    {
                                        break;
                                    }
                                    sp2DissipIdxNext = sp2DissipLoopIdx + 1u;
                                    sp2DissipLoopPos = sp2DissipPosRes;
                                    sp2DissipAccum = sp2DissipAccumRes;
                                    sp2DissipScale = sp2DissipScaleRes;
                                    sp2DissipLoopIdx = sp2DissipIdxNext;
                                    continue;
                                }
                                sp2ShadowMult = sp2DissipScale;
                                sp2ShadowAmount = sp2DissipAccum;
                                sp2EffectiveDens = mix(sp2ScaledDens * 0.0199999995529651641845703125, sp2ScaledDens, sp2DissipScale);
                                sp2ShadowTestPos = sp2DissipLoopPos;
                            }
                            else
                            {
                                sp2ShadowMult = 1.0;
                                sp2ShadowAmount = 0.0;
                                sp2EffectiveDens = sp2ScaledDens;
                                sp2ShadowTestPos = sp2OffsetPos;
                            }
                            float sp2AnimTime = globalTime * timeScale;
                            vec3 sp2CenteredPos = sp2LocalPos - vec3(0.5);
                            vec3 sp2NoiseCoord = sp2CenteredPos * 7.0;
                            float sp2NoiseZ = sp2NoiseCoord.z;
                            float sp2RotAngle1 = sp2AnimTime * 0.5;
                            float sp2RotOffset = (sp2AnimTime * 0.039999999105930328369140625) + ((((0.20000000298023223876953125 + ((sin(sp2NoiseZ * 5.0) + 0.5) * 0.1500000059604644775390625)) * sin(sp2RotAngle1 + 0.5)) * sin((sp2AnimTime * 0.1870000064373016357421875) + 0.5)) * 0.20000000298023223876953125);
                            float sp2SinRot = sin(sp2RotOffset);
                            float sp2CosRot = cos(sp2RotOffset);
                            vec2 sp2RotatedXY = sp2NoiseCoord.xy * mat2(vec2(sp2CosRot, -sp2SinRot), vec2(sp2SinRot, sp2CosRot));
                            float sp2RotatedX = sp2RotatedXY.x;
                            vec3 sp2NoisePosTemp = sp2NoiseCoord;
                            sp2NoisePosTemp.x = sp2RotatedX;
                            float sp2RotatedY = sp2RotatedXY.y;
                            float sp2WaveTime = sp2AnimTime + (sin(sp2RotAngle1) * 0.0199999995529651641845703125);
                            vec2 sp2WaveOffset = sp2NoisePosTemp.xz + (vec2(sin(sp2WaveTime + (sp2NoiseZ * 2.7000000476837158203125)), cos(sp2WaveTime + (sp2RotatedX * 2.7000000476837158203125))) * 0.0500000007450580596923828125);
                            float sp2PerturbedX = sp2WaveOffset.x;
                            float sp2PerturbedZ = sp2WaveOffset.y;
                            vec3 sp2NoisePosPerturbed = vec3(sp2PerturbedX, sp2RotatedY, sp2PerturbedZ);
                            float sp2FinalNoiseZ = sp2PerturbedZ + ((sin((sp2PerturbedX * 3.0) + (sp2AnimTime * 0.3499999940395355224609375)) + sin((sp2RotatedY * 2.8399999141693115234375) + (sp2AnimTime * 0.23499999940395355224609375))) * 0.0500000007450580596923828125);
                            sp2NoisePosPerturbed.z = sp2FinalNoiseZ;
                            vec3 sp2BaseNoiseCoord = sp2NoisePosPerturbed * noise1Scale;
                            vec3 sp2TimeOffset3D = vec3(2.0, 2.0, 4.5) * (sp2AnimTime * 0.100000001490116119384765625);
                            vec3 sp2RightOffset = cameraRight * 0.20000000298023223876953125;
                            vec3 sp2UpOffset = cameraSideVector * 0.20000000298023223876953125;
                            vec4 sp2NoisePowerVec = vec4(noisePower);
                            vec4 sp2RawNoiseSample = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((abs(sp2BaseNoiseCoord) - sp2TimeOffset3D) * 0.070000000298023223876953125).xyz, 0.0), sp2NoisePowerVec);
                            vec4 sp2LowFreqParams = vec4(noiseColorA);
                            vec4 sp2HighFreqParams = vec4(noiseColorB);
                            vec4 sp2NoiseBlend = vec4(noiseMixFactor);
                            vec4 sp2NoiseProcessed = mix(mix(sp2LowFreqParams, sp2HighFreqParams, sp2RawNoiseSample), mix(vec4(0.25), vec4(-1.5), sp2RawNoiseSample), sp2NoiseBlend);
                            float sp2BaseNoiseCombined = (sp2NoiseProcessed.x + (sp2NoiseProcessed.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 sp2NoiseSampleX = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((abs(sp2BaseNoiseCoord + sp2RightOffset) - sp2TimeOffset3D) * 0.070000000298023223876953125).xyz, 0.0), sp2NoisePowerVec);
                            vec4 sp2ProcessedX = mix(mix(sp2LowFreqParams, sp2HighFreqParams, sp2NoiseSampleX), mix(vec4(0.25), vec4(-1.5), sp2NoiseSampleX), sp2NoiseBlend);
                            vec4 sp2NoiseSampleY = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((abs(sp2BaseNoiseCoord + sp2UpOffset) - sp2TimeOffset3D) * 0.070000000298023223876953125).xyz, 0.0), sp2NoisePowerVec);
                            vec4 sp2ProcessedY = mix(mix(sp2LowFreqParams, sp2HighFreqParams, sp2NoiseSampleY), mix(vec4(0.25), vec4(-1.5), sp2NoiseSampleY), sp2NoiseBlend);
                            float sp2GradStep = 0.800000011920928955078125 / noise1Scale;
                            vec3 sp2NoiseNormal = normalize(vec3(sp2BaseNoiseCombined - ((sp2ProcessedY.x + (sp2ProcessedY.y * 0.949999988079071044921875)) * 4.599999904632568359375), sp2BaseNoiseCombined - ((sp2ProcessedX.x + (sp2ProcessedX.y * 0.949999988079071044921875)) * 4.599999904632568359375), sp2GradStep));
                            mat4 sp2ViewTransform = mat4(vec4(invViewProjMatrix._m0[0].x, invViewProjMatrix._m0[1].x, invViewProjMatrix._m0[2].x, invViewProjMatrix._m0[3].x), vec4(invViewProjMatrix._m0[0].y, invViewProjMatrix._m0[1].y, invViewProjMatrix._m0[2].y, invViewProjMatrix._m0[3].y), vec4(invViewProjMatrix._m0[0].z, invViewProjMatrix._m0[1].z, invViewProjMatrix._m0[2].z, invViewProjMatrix._m0[3].z), vec4(invViewProjMatrix._m0[0].w, invViewProjMatrix._m0[1].w, invViewProjMatrix._m0[2].w, invViewProjMatrix._m0[3].w));
                            float sp2CenteredPosZ = sp2CenteredPos.z;
                            vec3 sp2DetailCoord = (sp2NoiseCoord + ((((sp2ViewTransform * vec4((sp2NoiseNormal + vec3(0.0, 0.0, 1.0)).xyz, 0.0)).xyz * pow(sp2BaseNoiseCombined, 0.100000001490116119384765625)) * normalDetailScale) * 0.20000000298023223876953125)) + (vec3(2.0, 2.0, 4.5) * ((((sp2BaseNoiseCombined - 1.0) * 0.20000000298023223876953125) * normalDetailScale) * sp2CenteredPosZ));
                            sp2DetailCoord.x = sp2DetailCoord.x + (sin(sp2FinalNoiseZ + (sp2AnimTime * 0.25)) * 0.0500000007450580596923828125);
                            vec3 sp2DetailScaled = sp2DetailCoord * noise2Scale;
                            vec4 sp2DetailSample = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), (sp2DetailScaled * 0.070000000298023223876953125).xyz, 0.0), sp2NoisePowerVec);
                            vec4 sp2DetailProcessed = mix(mix(sp2LowFreqParams, sp2HighFreqParams, sp2DetailSample), mix(vec4(0.25), vec4(-1.5), sp2DetailSample), sp2NoiseBlend);
                            float sp2DetailCombined = (sp2DetailProcessed.x + (sp2DetailProcessed.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 sp2DetailSampleX = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((sp2DetailScaled + sp2RightOffset) * 0.070000000298023223876953125).xyz, 0.0), sp2NoisePowerVec);
                            vec4 sp2DetailProcessedX = mix(mix(sp2LowFreqParams, sp2HighFreqParams, sp2DetailSampleX), mix(vec4(0.25), vec4(-1.5), sp2DetailSampleX), sp2NoiseBlend);
                            vec4 sp2DetailSampleY = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), ((sp2DetailScaled + sp2UpOffset) * 0.070000000298023223876953125).xyz, 0.0), sp2NoisePowerVec);
                            vec4 sp2DetailProcessedY = mix(mix(sp2LowFreqParams, sp2HighFreqParams, sp2DetailSampleY), mix(vec4(0.25), vec4(-1.5), sp2DetailSampleY), sp2NoiseBlend);
                            float sp2DepthFade = detailNoiseInfluence * (dot(rayDirection, cameraForward) * clamp(distance(sp2ShadowTestPos, cameraPosition) * 0.004999999888241291046142578125, 0.0, 1.0));
                            float sp2CombinedNoise = (mix(0.949999988079071044921875, clamp(sp2BaseNoiseCombined, 0.0, 1.0), noise1Influence) + mix(0.949999988079071044921875, clamp(sp2DetailCombined, 0.0, 1.0), sp2DepthFade * 0.25)) + noiseOffset;
                            float sp2HeightFade;
                            if (volumeFadeParams._m0[sp2VolumeId].w < 1.0)
                            {
                                float sp2HeightParam = clamp(volumeFadeParams._m0[sp2VolumeId].w, 9.9999997473787516355514526367188e-05, 0.99989998340606689453125);
                                float sp2FadeStart = smoothstep(0.0, 0.800000011920928955078125, sp2HeightParam);
                                float sp2FadeEnd = smoothstep(0.20000000298023223876953125, 1.0, sp2HeightParam);
                                float sp2HeightFadeResult;
                                if (sp2FadeStart == sp2FadeEnd)
                                {
                                    sp2HeightFadeResult = sp2EffectiveDens * sp2HeightParam;
                                }
                                else
                                {
                                    vec3 sp2HeightTestPos = sp2CenteredPos;
                                    sp2HeightTestPos.z = sp2CenteredPosZ * 1.2000000476837158203125;
                                    sp2HeightFadeResult = sp2EffectiveDens * clamp(smoothstep(sp2FadeStart, sp2FadeEnd, clamp(length(sp2HeightTestPos), 0.0, 1.0)), 0.0, 1.0);
                                }
                                sp2HeightFade = sp2HeightFadeResult;
                            }
                            else
                            {
                                sp2HeightFade = sp2EffectiveDens;
                            }
                            float sp2StepDensity = mix(sp2HeightFade - (1.0 - sp2CombinedNoise), sp2HeightFade + sp2CombinedNoise, sp2HeightFade) * clamp((volumeFadeParams._m0[sp2VolumeId].x * volumeFadeParams._m0[sp2VolumeId].w) * 8.0, 0.0, 1.0);
                            if (sp2StepDensity < 9.9999997473787516355514526367188e-05)
                            {
                                sp2SampleSun = sp2SunAccum;
                                sp2SampleGodray = sp2FogAccum;
                                sp2SampleColor = sp2ColorAccum;
                                sp2HasDensity = false;
                                break;
                            }
                            vec3 sp2BaseNormalDir = normalize(sp2CenteredPos) * mix(1.0, 0.0, clamp(sp2ShadowAmount, 0.0, 1.0));
                            vec4 sp2NormalTransform = sp2ViewTransform * vec4(((vec4(sp2BaseNormalDir.xyz, 0.0).xyzw * sp2ViewTransform).xyz + ((vec3((sp2NoiseNormal.xy * noise1Influence) + ((normalize(vec3(sp2DetailCombined - ((sp2DetailProcessedY.x + (sp2DetailProcessedY.y * 0.949999988079071044921875)) * 4.599999904632568359375), sp2DetailCombined - ((sp2DetailProcessedX.x + (sp2DetailProcessedX.y * 0.949999988079071044921875)) * 4.599999904632568359375), sp2GradStep)) * mix(0.5, 1.0, clamp(sp2BaseNoiseCombined - 0.5, 0.0, 1.0))).xy * (sp2DepthFade * 1.5)), 0.0) * normalPerturbScale) * mix(1.0, 2.0, clamp((200.0 - distance(sp2ShadowTestPos, volumeCenters._m0[sp2VolumeIdxInt].xyz)) * 0.004999999888241291046142578125, 0.0, 1.0)))).xyz, 0.0);
                            vec3 sp2ViewSpaceNormal = sp2NormalTransform.xyz;
                            vec3 sp2ScatterUVW = clamp(clamp(mix(sp2CenteredPos * dot(sp2BaseNormalDir, sp2ViewSpaceNormal), normalize(sp2ViewSpaceNormal + vec3(0.0, 0.0, 0.5)) * length(sp2CenteredPos), vec3(0.20000000298023223876953125)) + vec3(0.5), vec3(0.02999999932944774627685546875), vec3(0.9700000286102294921875)), vec3(0.0), vec3(1.0));
                            sp2ScatterUVW.x = (sp2UOffset + (sp2ScatterUVW.x * 32.0)) * 0.0018450184725224971771240234375;
                            vec4 sp2ScatterColor = textureLod(sampler3D(colorLUTTexture, volumeSampler), sp2ScatterUVW.xyz, 0.0);
                            float sp2SunDot = dot(mix(sp2BaseNormalDir, sp2ViewSpaceNormal, vec3(phaseBlend)), mainLightDirection.xyz);
                            float sp2Phase = pow(clamp((sp2SunDot * 0.800000011920928955078125) + 0.20000000298023223876953125, 0.0, 1.0), 1.5) + pow(clamp((sp2SunDot * 1.39999997615814208984375) - 0.5, 0.0, 1.0), 3.0);
                            float sp2Sunlight;
                            if (sp2Phase > 0.0)
                            {
                                sp2Sunlight = sp2Phase * sp2ScatterColor.w;
                            }
                            else
                            {
                                sp2Sunlight = sp2Phase;
                            }
                            float sp2ScatterR = sp2ScatterColor.x;
                            float sp2ScatterG = sp2ScatterColor.y;
                            float sp2ScatterB = sp2ScatterColor.z;
                            float sp2MaxRGB = max(sp2ScatterR, max(sp2ScatterG, sp2ScatterB));
                            float sp2ColorRange = sp2MaxRGB - min(sp2ScatterR, min(sp2ScatterG, sp2ScatterB));
                            vec3 sp2HSVTemp = vec3(0.0);
                            sp2HSVTemp.z = sp2MaxRGB;
                            vec3 sp2HSVColor;
                            if (sp2ColorRange != 0.0)
                            {
                                float sp2Saturation = sp2ColorRange / sp2MaxRGB;
                                vec3 sp2ChromaDelta = (sp2HSVTemp.zzz - sp2ScatterColor.xyz) / vec3(sp2ColorRange);
                                vec3 sp2HueComponents = sp2ChromaDelta.xyz - sp2ChromaDelta.zxy;
                                vec2 sp2HueOffset = sp2HueComponents.xy + vec2(2.0, 4.0);
                                vec3 sp2HSVResult;
                                if (sp2ScatterR >= sp2MaxRGB)
                                {
                                    sp2HSVResult = vec3(sp2HueComponents.z, sp2Saturation, sp2MaxRGB);
                                }
                                else
                                {
                                    vec3 sp2HSVBranch;
                                    if (sp2ScatterG >= sp2MaxRGB)
                                    {
                                        sp2HSVBranch = vec3(sp2HueOffset.x, sp2Saturation, sp2MaxRGB);
                                    }
                                    else
                                    {
                                        sp2HSVBranch = vec3(sp2HueOffset.y, sp2Saturation, sp2MaxRGB);
                                    }
                                    sp2HSVResult = sp2HSVBranch;
                                }
                                vec3 sp2HSVFinal = sp2HSVResult;
                                sp2HSVFinal.x = fract(sp2HSVResult.x * 0.16666667163372039794921875);
                                sp2HSVColor = sp2HSVFinal;
                            }
                            else
                            {
                                sp2HSVColor = sp2HSVTemp;
                            }
                            float sp2AdjustedSat = clamp(sp2HSVColor.y * 1.10000002384185791015625, 0.0, 1.0);
                            vec3 sp2FinalRGB;
                            if (sp2AdjustedSat != 0.0)
                            {
                                float sp2HueAngle6 = sp2HSVColor.x * 6.0;
                                float sp2HueFloor = floor(sp2HueAngle6);
                                float sp2RGBDesat = sp2HSVColor.z * (1.0 - sp2AdjustedSat);
                                float sp2HueFraction = sp2HueAngle6 - sp2HueFloor;
                                float sp2RGBInterp1 = sp2HSVColor.z * (1.0 - (sp2AdjustedSat * sp2HueFraction));
                                float sp2RGBInterp2 = sp2HSVColor.z * (1.0 - (sp2AdjustedSat * (1.0 - sp2HueFraction)));
                                vec3 sp2RGBFromHSV;
                                if (sp2HueFloor == 0.0)
                                {
                                    sp2RGBFromHSV = vec3(sp2HSVColor.z, sp2RGBInterp2, sp2RGBDesat);
                                }
                                else
                                {
                                    vec3 sp2RGBBranch1;
                                    if (sp2HueFloor == 1.0)
                                    {
                                        sp2RGBBranch1 = vec3(sp2RGBInterp1, sp2HSVColor.z, sp2RGBDesat);
                                    }
                                    else
                                    {
                                        vec3 sp2RGBBranch2;
                                        if (sp2HueFloor == 2.0)
                                        {
                                            sp2RGBBranch2 = vec3(sp2RGBDesat, sp2HSVColor.z, sp2RGBInterp2);
                                        }
                                        else
                                        {
                                            vec3 sp2RGBBranch3;
                                            if (sp2HueFloor == 3.0)
                                            {
                                                sp2RGBBranch3 = vec3(sp2RGBDesat, sp2RGBInterp1, sp2HSVColor.z);
                                            }
                                            else
                                            {
                                                vec3 sp2RGBBranch4;
                                                if (sp2HueFloor == 4.0)
                                                {
                                                    sp2RGBBranch4 = vec3(sp2RGBInterp2, sp2RGBDesat, sp2HSVColor.z);
                                                }
                                                else
                                                {
                                                    sp2RGBBranch4 = vec3(sp2HSVColor.z, sp2RGBDesat, sp2RGBInterp1);
                                                }
                                                sp2RGBBranch3 = sp2RGBBranch4;
                                            }
                                            sp2RGBBranch2 = sp2RGBBranch3;
                                        }
                                        sp2RGBBranch1 = sp2RGBBranch2;
                                    }
                                    sp2RGBFromHSV = sp2RGBBranch1;
                                }
                                sp2FinalRGB = sp2RGBFromHSV;
                            }
                            else
                            {
                                sp2FinalRGB = sp2HSVColor.zzz;
                            }
                            vec3 sp2LitColor = (((((((normalize(sp2FinalRGB + vec3(0.001000000047497451305389404296875)) * min(length(sp2FinalRGB), 4.0)) * clamp(1.0 - min(0.25, sp2StepDensity), 0.0, 1.0)) * clamp(1.0 - (((sp2HeightFade * 2.400000095367431640625) - sp2StepDensity) * densityContrast), 0.0, 1.0)) * sp2CombinedNoise) * (0.75 + (sp2Sunlight * 0.25))) * (1.0 + (sp2NormalTransform.z * 0.5))) * baseColorIntensity) + ((mainLightColor.xyz * ((0.5 * sp2Sunlight) * (1.0 - sp2CavityStr))) * sunColorIntensity);
                            vec3 sp2TintedColor = sp2LitColor * volumeTintColor._m0[sp2VolumeId].xyz;
                            vec3 sp2DesaturatedColor = (mix(sp2LitColor, sp2TintedColor * (dot(sp2LitColor.xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125)) / dot((sp2TintedColor + vec3(0.001000000047497451305389404296875)).xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125))), vec3(0.5 * (1.0 - volumeFadeParams._m0[sp2VolumeId].z))) * mix(vec3(1.0), normalize(colorTint + vec3(0.00999999977648258209228515625)) * 1.73199999332427978515625, vec3(clamp(0.5 + (sp2StepDensity * 6.0), 0.0, 1.0)))).xyz;
                            vec3 sp2ShadowedColor = mix(sp2DesaturatedColor, sp2DesaturatedColor * sp2ShadowMult, vec3(0.60000002384185791015625)).xyz;
                            float sp2FogAmount = smoothstep(0.0, 0.20000000298023223876953125, sp2StepDensity + 0.300000011920928955078125) * (((clamp((godrayFalloffDist - sp2OcclusionDist) / godrayFalloffDist, 0.0, 1.0) * sp2HeightFade) * 6.0) * godrayIntensity);
                            float sp2StepAlpha = smoothstep(0.0, 0.20000000298023223876953125 / (alphaScale * mix(0.5, 2.0, sp2ColorAccum.w)), sp2StepDensity);
                            vec4 sp2StepContribution = vec4(((sp2ShadowedColor + ((sp2ShadowedColor * vec3(8.0, 4.0, 0.0)) * sp2TracerGlow)) * mix(1.0, 0.85000002384185791015625, clamp(sp2ShadowAmount * 20.0, 0.0, 1.0))) * sp2StepAlpha, sp2StepAlpha);
                            float sp2SunAccumLoop;
                            vec4 sp2ColorAccumLoop;
                            float sp2SampleWeight;
                            float sp2FogAccumLoop;
                            sp2SunAccumLoop = sp2SunAccum;
                            sp2ColorAccumLoop = sp2ColorAccum;
                            sp2FogAccumLoop = sp2FogAccum;
                            sp2SampleWeight = sp2RayLength * 0.25;
                            float sp2SunUpdated;
                            vec4 sp2ColorUpdated;
                            float sp2FogUpdated;
                            float sp2WeightDecrement;
                            for (;;)
                            {
                                if (!(sp2SampleWeight >= 1.0))
                                {
                                    break;
                                }
                                sp2FogUpdated = sp2FogAccumLoop + sp2FogAmount;
                                sp2ColorUpdated = sp2ColorAccumLoop + (sp2StepContribution * (1.0 - sp2ColorAccumLoop.w));
                                sp2SunUpdated = sp2SunAccumLoop + sp2Sunlight;
                                sp2WeightDecrement = sp2SampleWeight - 1.0;
                                sp2SunAccumLoop = sp2SunUpdated;
                                sp2ColorAccumLoop = sp2ColorUpdated;
                                sp2FogAccumLoop = sp2FogUpdated;
                                sp2SampleWeight = sp2WeightDecrement;
                                continue;
                            }
                            sp2SampleSun = sp2SunAccumLoop + (sp2Sunlight * sp2SampleWeight);
                            sp2SampleGodray = sp2FogAccumLoop + (sp2FogAmount * sp2SampleWeight);
                            sp2SampleColor = sp2ColorAccumLoop + (sp2StepContribution * ((1.0 - sp2ColorAccumLoop.w) * sp2SampleWeight));
                            sp2HasDensity = (sp2StepAlpha + sp2FogAmount) > 0.0;
                            break;
                        }
                        sp2SampleSun = sp2SunAccum;
                        sp2SampleGodray = sp2FogAccum;
                        sp2SampleColor = sp2ColorAccum;
                        sp2HasDensity = false;
                        break;
                    } while(false);
                    volumeBoxList[sp2VolumeIdx] = volumeBoxList[sp2VolumeIdx];
                    bool sp2ShouldRecordHit;
                    if (sp2HasDensity)
                    {
                        sp2ShouldRecordHit = !sp2HadSampleState;
                    }
                    else
                    {
                        sp2ShouldRecordHit = false;
                    }
                    vec3 sp2FirstHitUpdate = mix(sp2CurrentPos, sp2StartPos, bvec3(sp2ShouldRecordHit));
                    if (sp2SampleColor.w > 0.990999996662139892578125)
                    {
                        vec4 sp2ColorClamped = sp2SampleColor;
                        sp2ColorClamped.w = 1.0;
                        sp2LastHitTemp = sp2StartPos;
                        sp2FirstHitResult = sp2FirstHitUpdate;
                        sp2SunlightOut = sp2SampleSun;
                        sp2GodrayOut = sp2SampleGodray;
                        sp2ColorOut = sp2ColorClamped;
                        sp2EarlyExit = true;
                        sp2LoopBreak = true;
                        break;
                    }
                    sp2HadPrevSample = sp2ShouldRecordHit ? true : sp2HadSampleState;
                    sp2Sunlight = sp2SampleSun;
                    sp2Godray = sp2SampleGodray;
                    sp2ColorResult = sp2SampleColor;
                    sp2TracerGlow = sp2TracerGlow;
                    sp2TracerDirResult = sp2TracerDir;
                    sp2CavityStr = sp2CavityStr;
                    sp2TracerBits = sp2TracerCache;
                    sp2PosOut = sp2FirstHitUpdate;
                    break;
                } while(false);
                if (sp2LoopBreak)
                {
                    break;
                }
                sp2VolumeIdxNext = sp2VolumeIdx + 1u;
                sp2HadSampleState = sp2HadPrevSample;
                sp2SunAccum = sp2Sunlight;
                sp2FogAccum = sp2Godray;
                sp2ColorAccum = sp2ColorResult;
                sp2CachedGlow = sp2TracerGlow;
                sp2TracerDir = sp2TracerDirResult;
                sp2CachedCavity = sp2CavityStr;
                sp2CachedBits = sp2TracerBits;
                sp2VolumeIdx = sp2VolumeIdxNext;
                sp2CurrentPos = sp2PosOut;
                continue;
            }
            if (sp2EarlyExit)
            {
                finalLastHitPos = sp2LastHitTemp;
                finalFirstHitPos = sp2FirstHitResult;
                finalSunlightAccum = sp2SunlightOut;
                finalGodrayAccum = sp2GodrayOut;
                finalAccumColor = sp2ColorOut;
                break;
            }
            sp2LastHit = sp2LastHitTemp;
            sp2FirstHit = sp2FirstHitResult;
            sp2Sunlight = sp2SunlightOut;
            sp2Godray = sp2GodrayOut;
            sp2Color = sp2ColorOut;
        }
        else
        {
            sp2LastHit = loopLastHitPos;
            sp2FirstHit = loopFirstHitPos;
            sp2Sunlight = loopSunlightOut;
            sp2Godray = loopGodrayOut;
            sp2Color = loopColorOut;
        }
        finalLastHitPos = sp2LastHit;
        finalFirstHitPos = sp2FirstHit;
        finalSunlightAccum = sp2Sunlight;
        finalGodrayAccum = sp2Godray;
        finalAccumColor = sp2Color;
        break;
    } while(false);
    float sunRimDot = pow(clamp(dot(normalize(rayDirection), mainLightDirection.xyz), 0.0, 1.0), 4.0) * 0.25;
    float foggedDensity = clamp(finalGodrayAccum - (finalAccumColor.w * 0.20000000298023223876953125), 0.0, 1.0);
    vec4 preRimColor = mix(vec4(finalAccumColor.xyz * mix(1.0, 0.0, foggedDensity), finalAccumColor.w + foggedDensity), finalAccumColor, bvec4(godrayIntensity == 0.0));
    vec3 rimEnhancedColor = preRimColor.xyz * (vec3(1.0) + ((pow(mainLightColor.xyz, vec3(2.0)) * (((sunRimDot + (pow(sunRimDot, 50.0) * 8.0)) * mix(1.0, 0.0, pow(finalAccumColor.w, 0.5))) * finalAccumColor.w)) * (finalSunlightAccum * rimLightIntensity)));
    vec4 finalOutputColor = preRimColor;
    finalOutputColor.x = rimEnhancedColor.x;
    finalOutputColor.y = rimEnhancedColor.y;
    finalOutputColor.z = rimEnhancedColor.z;
    float finalAlpha = preRimColor.w;
    if (finalAlpha < 9.9999997473787516355514526367188e-06)
    {
        discard;
    }
    float logDepthRange = logDepthFar - logDepthNear;
    float logDepthNear = (((log(dot(cameraForward.xyz, finalFirstHitPos.xyz - cameraPosition.xyz)) - logDepthNear) / logDepthRange) * 2.0) - 1.0;
    float logDepthFar = (((log(dot(cameraForward.xyz, finalLastHitPos.xyz - cameraPosition.xyz)) - logDepthNear) / logDepthRange) * 2.0) - 1.0;
    vec4 moment0Accum;
    vec4 moment1Accum;
    vec4 moment2Accum;
    moment0Accum = vec4(0.0);
    moment1Accum = vec4(0.0);
    moment2Accum = vec4(0.0);
    int momentLoopIdx;
    vec4 moment1Updated;
    vec4 moment2Updated;
    vec4 moment0Updated;
    int momentLoopCounter = 0;
    for (;;)
    {
        if (!(momentLoopCounter < 4))
        {
            break;
        }
        momentLoopIdx = momentLoopCounter + 1;
        float momentParam = 0.25 * float(momentLoopIdx);
        float depthInterpolated = mix(logDepthNear, logDepthFar, momentParam);
        float momentWeight = -log(1.0 - clamp(finalAlpha * momentParam, 9.9999997473787516355514526367188e-06, 0.99989998340606689453125));
        float depthSquared = depthInterpolated * depthInterpolated;
        float depthQuartic = depthSquared * depthSquared;
        moment0Updated = moment0Accum + vec4(momentWeight, 0.0, 0.0, 0.0);
        moment1Updated = moment1Accum + vec4(vec2(depthInterpolated, depthSquared) * momentWeight, 0.0, 0.0);
        moment2Updated = moment2Accum + (vec4(depthSquared * depthInterpolated, depthQuartic, depthQuartic * depthInterpolated, depthQuartic * depthSquared) * momentWeight);
        moment0Accum = moment0Updated;
        moment1Accum = moment1Updated;
        moment2Accum = moment2Updated;
        momentLoopCounter = momentLoopIdx;
        continue;
    }
    outMoment0 = moment0Accum;
    outMoment1 = moment1Accum;
    outMoment2 = moment2Accum;
    outSmokeColor = finalOutputColor;
    outDepthMinMax = vec4(logDepthNear, logDepthFar, 0.0, 0.0);
    outTransmittance = finalAlpha;
}