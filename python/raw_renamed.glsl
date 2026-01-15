#version 460
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_samplerless_texture_functions : require
layout(early_fragment_tests) in;

// ============================================================================
// COMPILE-TIME CONSTANTS
// ============================================================================

// --- Array/Loop Limits ---
#define MAX_TRACER_COUNT            16u
#define MAX_EXPLOSION_COUNT         5u
#define MAX_ACTIVE_VOLUMES          1u
#define MAX_MARCH_STEPS             500.0
#define MOMENT_LOOP_COUNT           4

// --- Volume Sampling ---
#define VOLUME_LOCAL_SCALE          0.05                // 1/20 - world to local space
#define VOLUME_CENTER_OFFSET        16.0                // offset to center volume
#define VOLUME_UVW_SCALE            0.03125             // 1/32 - local to UVW
#define VOLUME_TILE_SIZE            32.0                // texture tile dimension
#define DENSITY_ATLAS_U_SCALE       0.0018450184725224971771240234375  // 1/542
#define DENSITY_PAGE_STRIDE         34.0                // U offset per density page

// --- Ray Marching ---
#define RAY_NEAR_CLIP_OFFSET        4.0                 // minimum ray start distance
#define SCENE_DEPTH_OFFSET          2.0                 // offset from scene depth
#define OCCLUSION_DEPTH_THRESHOLD   10.0                // secondary depth occlusion test
#define STEP_DISTANCE_MULTIPLIER    1.5                 // base step size modifier
#define STEP_COUNT_PADDING          10.0                // extra steps for safety

// --- Noise Sampling ---
#define NOISE_TEXTURE_SCALE         0.07                // high-freq noise UV scale
#define NOISE_COORD_SCALE           7.0                 // volume to noise space
#define NOISE_CHANNEL_WEIGHT        0.95                // secondary channel weight
#define NOISE_COMBINE_MULTIPLIER    4.6                 // final noise amplitude (approx 4.599999...)
#define NORMAL_GRAD_STEP_BASE       0.8                 // base value for normal gradient

// --- Time/Animation ---
#define TIME_OFFSET_SCALE           0.1                 // global time offset multiplier
#define ROTATION_TIME_MULT          0.5                 // rotation animation speed
#define ROTATION_OFFSET_BASE        0.04                // base rotation offset
#define ROTATION_MOD_FREQ           0.187               // rotation modulation frequency
#define WAVE_FREQ_MULT              2.7                 // wave perturbation frequency
#define WAVE_ANIM_FREQ_1            0.35                // wave animation speed 1
#define WAVE_ANIM_FREQ_2            0.235               // wave animation speed 2
#define DETAIL_TIME_MULT            0.25                // detail noise time multiplier
#define GOLDEN_RATIO_FRACT          0.61803400516510009765625  // φ - 1, for jitter

// --- Alpha/Density Thresholds ---
#define OPAQUE_THRESHOLD            0.990999996662139892578125   // ~0.991
#define MIN_DENSITY_THRESHOLD       0.00999999977648258209228515625  // ~0.01
#define EPSILON                     9.9999997473787516355514526367188e-05  // ~0.0001
#define MAX_CLAMP_VALUE             0.99989998340606689453125    // ~0.9999
#define FIRST_PASS_WEIGHT           0.375               // sample weight for main pass
#define SECOND_PASS_WEIGHT          0.25                // sample weight for second pass

// --- Distance Thresholds ---
#define TRACER_DIST_SCALE           0.05                // tracer distance falloff
#define TRACER_OFFSET_SCALE         20.0                // tracer cavity offset distance
#define TRACER_GLOW_POWER           64.0                // power for tracer glow falloff
#define TRACER_AGE_DIST_SCALE       1250.0              // tracer age to distance conversion
#define EXPLOSION_MAX_DIST          250.0               // maximum explosion influence range
#define DISSIP_FADE_NEAR            200.0               // dissipation fade start
#define DISSIP_FADE_FAR             240.0               // dissipation fade end
#define SURFACE_PROX_THRESHOLD      48.0                // surface proximity distance
#define SURFACE_PROX_SCALE          0.02083333395421504974365234375  // 1/48
#define DENSITY_BLEND_NEAR          10.0                // density blend start distance
#define DENSITY_BLEND_FAR           40.0                // density blend end distance
#define CAMERA_DIST_SCALE           0.1                 // camera distance density scale
#define DEPTH_FADE_DIST_SCALE       0.005               // depth fade distance factor

// --- Lighting/Phase ---
#define PHASE_SCALE_1               0.8                 // phase function scale
#define PHASE_OFFSET_1              0.2                 // phase function offset
#define PHASE_POWER_1               1.5                 // phase function power (front)
#define PHASE_SCALE_2               1.4                 // secondary phase scale
#define PHASE_OFFSET_2              0.5                 // secondary phase offset
#define PHASE_POWER_2               3.0                 // phase function power (back)
#define RIM_LIGHT_POWER             4.0                 // rim light falloff power
#define RIM_LIGHT_SCALE             0.25                // rim light base intensity
#define RIM_HIGHLIGHT_POWER         50.0                // rim highlight hotspot power
#define RIM_HIGHLIGHT_SCALE         8.0                 // rim highlight intensity

// --- Color Constants ---
#define LUMA_R                      0.2125000059604644775390625   // Rec.709 red
#define LUMA_G                      0.7153999805450439453125      // Rec.709 green
#define LUMA_B                      0.07209999859333038330078125  // Rec.709 blue
#define COLOR_TINT_NORM             1.73199999332427978515625     // sqrt(3) for normalization
#define SATURATION_BOOST            1.1                 // HSV saturation multiplier
#define COLOR_EPSILON               0.001               // epsilon for color normalization
#define MAX_COLOR_LENGTH            4.0                 // maximum color vector length
#define TRACER_GLOW_R               8.0                 // tracer glow red
#define TRACER_GLOW_G               4.0                 // tracer glow green
#define TRACER_GLOW_B               0.0                 // tracer glow blue

// --- Blend/Mix Factors ---
#define HALF                        0.5
#define SHADOW_BLEND_FACTOR         0.6                 // shadow color blend
#define SHADOW_AMOUNT_SCALE         0.85                // shadow amount color multiplier
#define HEIGHT_FADE_DENSITY_MULT    2.4                 // height fade contrast
#define HEIGHT_TEST_Z_SCALE         1.2                 // height test position scale
#define NORMAL_DIST_SCALE           0.005               // normal distance blend factor
#define CAMERA_RIGHT_OFFSET         0.2                 // camera vector offsets for normals
#define EXPLOSION_PULSE_POWER       128.0               // explosion pulse sharpness

// --- Density Remapping ---
#define DENSITY_REMAP_FACTOR        1.01010096073150634765625  // 1/(1-0.01)
#define DENSITY_FADE_MULT           8.0                 // density fade multiplier
#define FOG_DENSITY_MULT            6.0                 // fog amount multiplier
#define FOG_STEP_THRESHOLD          0.3                 // fog step offset

// --- Jitter/Sampling ---
#define JITTER_MIN_BLEND            0.1                 // minimum jitter blend
#define JITTER_MAX_BLEND            0.8                 // maximum jitter blend
#define JITTER_DIST_OFFSET          150.0               // jitter distance offset
#define JITTER_DIST_SCALE           0.05                // jitter distance scale

// --- Tracer Animation ---
#define TRACER_CACHE_INTERVAL       15                  // steps between tracer updates (mask)
#define TRACER_WARMUP_STEPS         16                  // initial steps to always update

// --- HSV Conversion ---
#define HSV_HUE_SCALE               0.16666667163372039794921875  // 1/6
#define HSV_HUE_SECTORS             6.0                 // hue sector count

// ============================================================================
// DATA STRUCTURES
// ============================================================================

struct VolumeBoxData
{
    vec4 _m0; // x=tEnter, y=tExit, z=volumeIndex
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

// ============================================================================
// UNIFORM BLOCKS
// ============================================================================

layout(set = 1, binding = 1, std140) uniform CameraDataBlock
{
    layout(offset = 128) Matrix4x4 invViewProjMatrix;
    layout(offset = 256) vec4 projectionParams;
    layout(offset = 304) vec3 cameraPosition;
    layout(offset = 316) float depthNear;
    layout(offset = 320) vec3 cameraForward;
    layout(offset = 332) float depthFar;
    layout(offset = 336) vec3 cameraRight;
    layout(offset = 492) float globalTime;
} cameraData;

layout(set = 1, binding = 5, scalar) uniform VolumeDataBlock
{
    layout(offset = 0) VolumeArray16 volumeMinBounds;
    layout(offset = 256) VolumeArray16 volumeMaxBounds;
    layout(offset = 512) VolumeArray16 volumeCenters;
    layout(offset = 768) VolumeArray16 volumeAnimState;
    layout(offset = 1024) VolumeArray16 volumeTintColor;
    layout(offset = 1280) VolumeArray16 volumeFadeParams;
    layout(offset = 1536) vec4 sceneAABBMin;
    layout(offset = 1552) vec4 sceneAABBMax;
    layout(offset = 1568) VolumeArray16 bulletTracerStarts;
    layout(offset = 1824) VolumeArray16 bulletTracerEnds;
    layout(offset = 2080) VolumeArray16 tracerInfluenceParams;
    layout(offset = 2336) PointArray5 explosionPositions;
    layout(offset = 2416) MaskArray2 volumeTracerMasks;
    layout(offset = 2468) uint activeTracerCount;
    layout(offset = 2472) float animationTime;
    layout(offset = 2476) uint explosionCount;
} volumeData;

layout(set = 1, binding = 0, std140) uniform RenderParamsBlock
{
    layout(offset = 8) float jitterScale;
    layout(offset = 12) float alphaScale;
    layout(offset = 16) float timeScale;
    layout(offset = 20) float noise1Influence;
    layout(offset = 24) float detailNoiseInfluence;
    layout(offset = 28) float normalPerturbScale;
    layout(offset = 32) float phaseBlend;
    layout(offset = 36) float noiseOffset;
    layout(offset = 44) float noise1Scale;
    layout(offset = 48) float noise2Scale;
    layout(offset = 52) float noisePower;
    layout(offset = 56) float noiseColorA;
    layout(offset = 60) float noiseColorB;
    layout(offset = 64) float baseColorIntensity;
    layout(offset = 68) float sunColorIntensity;
    layout(offset = 72) float rimLightIntensity;
    layout(offset = 76) float densityContrast;
    layout(offset = 80) float baseStepSize;
    layout(offset = 84) float normalDetailScale;
    layout(offset = 92) int enableSecondPass;
    layout(offset = 96) vec3 colorTint;
    layout(offset = 108) float godrayIntensity;
    layout(offset = 112) float godrayFalloffDist;
    layout(offset = 128) float noiseMixFactor;
    layout(offset = 132) int depthDownscaleFactor;
} renderParams;

layout(set = 1, binding = 4, std140) uniform ScreenDataBlock
{
    layout(offset = 176) ivec2 noiseTileSize;
    layout(offset = 604) float logDepthNear;
    layout(offset = 608) float logDepthFar;
} screenData;

layout(set = 3, binding = 0, std140) uniform LightingDataBlock
{
    layout(offset = 304) vec4 mainLightDirection;
    layout(offset = 320) vec4 mainLightColor;
} lightingData;

// ============================================================================
// TEXTURES AND SAMPLERS
// ============================================================================

layout(set = 1, binding = 30) uniform texture2D blueNoiseTexture;
layout(set = 1, binding = 56) uniform texture2D sceneDepthTexture;
layout(set = 1, binding = 58) uniform texture2D secondaryDepthTexture;
layout(set = 1, binding = 57) uniform texture2D volumeMaskTexture;
layout(set = 1, binding = 53) uniform texture3D volumeDensityTexture;
layout(set = 1, binding = 17) uniform sampler volumeSampler;
layout(set = 1, binding = 55) uniform texture3D highFreqNoiseTexture;
layout(set = 1, binding = 16) uniform sampler noiseSampler;
layout(set = 1, binding = 54) uniform texture3D colorLUTTexture;

// ============================================================================
// INPUTS / OUTPUTS
// ============================================================================

layout(location = 0) in vec3 inWorldViewDir;
layout(location = 0) out vec4 outMoment0;
layout(location = 1) out vec4 outMoment1;
layout(location = 2) out vec4 outMoment2;
layout(location = 3) out vec4 outSmokeColor;
layout(location = 4) out vec4 outDepthMinMax;
layout(location = 5) out float outTransmittance;

// ============================================================================
// HELPER FUNCTIONS: RAY-BOX INTERSECTION
// ============================================================================

vec2 rayBoxIntersection(vec3 invRayDir, vec3 rayOrigin, vec3 boxMin, vec3 boxMax)
{
    vec3 tToMin = invRayDir * (boxMin - rayOrigin);
    vec3 tToMax = invRayDir * (boxMax - rayOrigin);
    vec3 tMinPerAxis = min(tToMax, tToMin);
    vec3 tMaxPerAxis = max(tToMax, tToMin);
    vec2 tMinComp = max(tMinPerAxis.xx, tMinPerAxis.yz);
    vec2 tMaxComp = min(tMaxPerAxis.xx, tMaxPerAxis.yz);
    return vec2(max(tMinComp.x, tMinComp.y), min(tMaxComp.x, tMaxComp.y));
}

// ============================================================================
// HELPER FUNCTIONS: COLOR SPACE CONVERSION
// ============================================================================

vec3 rgbToHsv(vec3 rgb)
{
    float maxVal = max(rgb.x, max(rgb.y, rgb.z));
    float minVal = min(rgb.x, min(rgb.y, rgb.z));
    float range = maxVal - minVal;
    
    vec3 hsv = vec3(0.0);
    hsv.z = maxVal;
    
    if (range != 0.0)
    {
        float saturation = range / maxVal;
        vec3 chromaDelta = (hsv.zzz - rgb) / vec3(range);
        vec3 hueComponents = chromaDelta.xyz - chromaDelta.zxy;
        vec2 hueOffset = hueComponents.xy + vec2(2.0, 4.0);
        
        vec3 hsvResult;
        if (rgb.x >= maxVal)
            hsvResult = vec3(hueComponents.z, saturation, maxVal);
        else if (rgb.y >= maxVal)
            hsvResult = vec3(hueOffset.x, saturation, maxVal);
        else
            hsvResult = vec3(hueOffset.y, saturation, maxVal);
        
        hsvResult.x = fract(hsvResult.x * HSV_HUE_SCALE);
        return hsvResult;
    }
    
    return hsv;
}

vec3 hsvToRgb(vec3 hsv)
{
    if (hsv.y == 0.0)
        return vec3(hsv.z);
    
    float hueAngle6 = hsv.x * HSV_HUE_SECTORS;
    float hueFloor = floor(hueAngle6);
    float hueFraction = hueAngle6 - hueFloor;
    float p = hsv.z * (1.0 - hsv.y);
    float q = hsv.z * (1.0 - (hsv.y * hueFraction));
    float t = hsv.z * (1.0 - (hsv.y * (1.0 - hueFraction)));
    
    if (hueFloor == 0.0) return vec3(hsv.z, t, p);
    if (hueFloor == 1.0) return vec3(q, hsv.z, p);
    if (hueFloor == 2.0) return vec3(p, hsv.z, t);
    if (hueFloor == 3.0) return vec3(p, q, hsv.z);
    if (hueFloor == 4.0) return vec3(t, p, hsv.z);
    return vec3(hsv.z, p, q);
}

// ============================================================================
// HELPER FUNCTIONS: VIEW TRANSFORM
// ============================================================================

mat4 getViewTransform()
{
    return mat4(
        vec4(cameraData.invViewProjMatrix._m0[0].x, cameraData.invViewProjMatrix._m0[1].x, cameraData.invViewProjMatrix._m0[2].x, cameraData.invViewProjMatrix._m0[3].x),
        vec4(cameraData.invViewProjMatrix._m0[0].y, cameraData.invViewProjMatrix._m0[1].y, cameraData.invViewProjMatrix._m0[2].y, cameraData.invViewProjMatrix._m0[3].y),
        vec4(cameraData.invViewProjMatrix._m0[0].z, cameraData.invViewProjMatrix._m0[1].z, cameraData.invViewProjMatrix._m0[2].z, cameraData.invViewProjMatrix._m0[3].z),
        vec4(cameraData.invViewProjMatrix._m0[0].w, cameraData.invViewProjMatrix._m0[1].w, cameraData.invViewProjMatrix._m0[2].w, cameraData.invViewProjMatrix._m0[3].w));
}

// ============================================================================
// HELPER FUNCTIONS: NOISE SAMPLING
// ============================================================================

vec4 sampleProcessedNoise(vec3 coord, vec4 powerVec, vec4 lowFreq, vec4 highFreq, vec4 mixFactor)
{
    vec4 raw = pow(textureLod(sampler3D(highFreqNoiseTexture, noiseSampler), (coord * NOISE_TEXTURE_SCALE).xyz, 0.0), powerVec);
    return mix(mix(lowFreq, highFreq, raw), mix(vec4(SECOND_PASS_WEIGHT), vec4(-1.5), raw), mixFactor);
}

float combineNoiseChannels(vec4 processed)
{
    return (processed.x + (processed.y * NOISE_CHANNEL_WEIGHT)) * NOISE_COMBINE_MULTIPLIER;
}

// ============================================================================
// HELPER FUNCTIONS: TRACER CALCULATIONS
// ============================================================================

void calculateTracerInfluence(vec3 samplePos, inout float tracerGlow, inout vec3 tracerDir, inout float cavityStrength)
{
    for (uint i = 0u; i < min(volumeData.activeTracerCount, MAX_TRACER_COUNT); i++)
    {
        vec3 lineDir = volumeData.bulletTracerEnds._m0[i].xyz - volumeData.bulletTracerStarts._m0[i].xyz;
        vec3 toStart = samplePos - volumeData.bulletTracerStarts._m0[i].xyz;
        
        float t = clamp(dot(toStart, lineDir) / dot(lineDir, lineDir), 0.0, 1.0);
        float distToLine = clamp((length(toStart - (lineDir * t)) * TRACER_DIST_SCALE) * volumeData.tracerInfluenceParams._m0[i].x, 0.0, 1.0);
        
        float age = volumeData.bulletTracerStarts._m0[i].w;
        float fade = smoothstep(0.0, MIN_DENSITY_THRESHOLD, age) * (1.0 - smoothstep(MIN_DENSITY_THRESHOLD, CAMERA_RIGHT_OFFSET, age));
        
        float spotGlow;
        if (distToLine < 1.0)
        {
            float wind = max(cavityStrength, smoothstep(0.0, 1.0, 1.0 - clamp(age + clamp(distToLine + (1.0 - clamp(length(samplePos - volumeData.bulletTracerEnds._m0[i].xyz) * MIN_DENSITY_THRESHOLD, 0.0, 1.0)), 0.0, 1.0), 0.0, 1.0)));
            tracerDir = mix(tracerDir, normalize(volumeData.bulletTracerStarts._m0[i].xyz - volumeData.bulletTracerEnds._m0[i].xyz), vec3(wind));
            cavityStrength = wind;
            spotGlow = (pow(1.0 - distToLine, TRACER_GLOW_POWER) * fade) * 10.0;
        }
        else
        {
            spotGlow = 0.0;
        }
        
        if (volumeData.bulletTracerEnds._m0[i].w > 0.0)
        {
            float pointGlow = (1.0 - clamp(length(toStart) * MIN_DENSITY_THRESHOLD, 0.0, 1.0)) * fade;
            tracerGlow = max(tracerGlow, max(pointGlow * pointGlow, spotGlow));
        }
    }
}

// ============================================================================
// HELPER FUNCTIONS: DISSIPATION
// ============================================================================

void calculateDissipation(inout vec3 samplePos, inout float dissipScale, inout float dissipAccum,
                          float occlusionDist, uint volumeIdx, uint densityPageIdx, bool skipOcclusion)
{
    for (uint i = 0u; i < min(volumeData.explosionCount, MAX_EXPLOSION_COUNT); i++)
    {
        if ((uint(volumeData.volumeTracerMasks._m0[i >> uint(2)][i & 3u]) & (1u << densityPageIdx)) == 0u)
            continue;
        
        float dissipAge = volumeData.animationTime - volumeData.explosionPositions._m0[i].w;
        if (dissipAge >= (volumeData.volumeAnimState._m0[volumeIdx].x - 0.4))
            continue;
        
        float dist = distance(samplePos, volumeData.explosionPositions._m0[i].xyz);
        if (dist >= EXPLOSION_MAX_DIST)
            continue;
        
        float pulse = pow(1.0 - smoothstep(0.0, 2.0, dissipAge), EXPLOSION_PULSE_POWER);
        float surfaceProx;
        if (!skipOcclusion)
            surfaceProx = clamp((SURFACE_PROX_THRESHOLD - occlusionDist) * SURFACE_PROX_SCALE, 0.0, 1.0) * (1.0 - smoothstep(0.0, NOISE_COORD_SCALE, dissipAge));
        else
            surfaceProx = dissipAccum;
        
        samplePos = mix(samplePos, volumeData.explosionPositions._m0[i].xyz, vec3(((1.0 - smoothstep(100.0, EXPLOSION_MAX_DIST, dist)) * step(dissipAge * TRACER_AGE_DIST_SCALE, dist)) * (1.0 - pulse)));
        dissipScale = min(dissipScale, max(smoothstep(DISSIP_FADE_NEAR, DISSIP_FADE_FAR, dist + (pulse * EXPLOSION_MAX_DIST)) + pow(smoothstep(HALF, 5.0, dissipAge), 1.8), surfaceProx));
        dissipAccum = surfaceProx;
    }
}

// ============================================================================
// MAIN VOLUME SAMPLE FUNCTION
// ============================================================================

bool sampleVolumeAtPosition(
    vec3 currentMarchPos,
    vec3 marchEndWorldPos,
    vec3 backProjectedPoint,
    vec3 rayDirection,
    vec3 cameraSideVector,
    uint volumeIdx,
    float densityUOffset,
    uint densityPageIdx,
    float tracerGlow,
    vec3 tracerDir,
    float cavityStrength,
    bool hasExplosionLayer,
    bool skipDueToOcclusion,
    inout vec4 stepColor,
    inout float stepLightEnergy,
    inout float stepFogDensity)
{
    // Apply tracer offset to sample position
    vec3 tracerOffsetSamplePos = currentMarchPos + ((normalize(tracerDir) * pow(cavityStrength, PHASE_POWER_2)) * TRACER_OFFSET_SCALE);
    
    int volumeIdxInt = int(volumeIdx);
    vec3 volumeLocalPos = clamp((((tracerOffsetSamplePos - volumeData.volumeCenters._m0[volumeIdxInt].xyz) * vec3(VOLUME_LOCAL_SCALE)) + vec3(VOLUME_CENTER_OFFSET)) * vec3(VOLUME_UVW_SCALE), vec3(0.0), vec3(1.0));
    vec3 volumeUVW = clamp(volumeLocalPos, vec3(0.0), vec3(1.0));
    volumeUVW.x = (densityUOffset + (volumeUVW.x * VOLUME_TILE_SIZE)) * DENSITY_ATLAS_U_SCALE;
    
    // Sample density
    vec4 densitySample = textureLod(sampler3D(volumeDensityTexture, volumeSampler), volumeUVW.xyz, 0.0);
    vec2 densityChannels = mix(densitySample.xz, densitySample.yw, vec2(volumeData.volumeAnimState._m0[volumeIdx].y));
    float sampledDensityMin = densityChannels.x;
    float sampledDensityMax = densityChannels.y;
    
    float distanceToMarchEnd = distance(tracerOffsetSamplePos, marchEndWorldPos);
    float adjustedDensity = sampledDensityMax;
    if (sampledDensityMin > sampledDensityMax)
        adjustedDensity = mix(sampledDensityMax, sampledDensityMin, smoothstep(DENSITY_BLEND_NEAR, DENSITY_BLEND_FAR, distanceToMarchEnd));
    
    float cavityDensity = clamp(mix(adjustedDensity, -VOLUME_LOCAL_SCALE, cavityStrength), 0.0, 1.0);
    if (cavityDensity <= MIN_DENSITY_THRESHOLD)
        return false;
    
    // Calculate occlusion and density multiplier
    float occlusionDistance = max(0.0, distanceToMarchEnd - min(TRACER_OFFSET_SCALE, abs(backProjectedPoint.z - volumeData.volumeCenters._m0[volumeIdxInt].z) * 2.0));
    float densityMultiplier = clamp(clamp((cavityDensity - MIN_DENSITY_THRESHOLD) * DENSITY_REMAP_FACTOR, 0.0, 1.0), 0.0, 1.0) * volumeData.volumeFadeParams._m0[volumeIdx].x;
    float finalScaledDensity = clamp(densityMultiplier + ((1.0 - clamp(distance(cameraData.cameraPosition, tracerOffsetSamplePos) * CAMERA_DIST_SCALE, 0.0, 1.0)) * densityMultiplier), 0.0, 1.0);
    
    // Dissipation / explosion effects
    vec3 shadowTestPos = tracerOffsetSamplePos;
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
        effectiveDensity = mix(finalScaledDensity * 0.02, finalScaledDensity, dissipScale);
    }
    
    // ========== NOISE CALCULATION (FULL DETAIL) ==========
    float animTime = cameraData.globalTime * renderParams.timeScale;
    vec3 volumeCenteredPos = volumeLocalPos - vec3(HALF);
    vec3 noiseCoord = volumeCenteredPos * NOISE_COORD_SCALE;
    float noiseZ = noiseCoord.z;
    
    // Rotation
    float rotAngle1 = animTime * ROTATION_TIME_MULT;
    float rotOffset = (animTime * ROTATION_OFFSET_BASE) + ((((CAMERA_RIGHT_OFFSET + ((sin(noiseZ * 5.0) + HALF) * 0.15)) * sin(rotAngle1 + HALF)) * sin((animTime * ROTATION_MOD_FREQ) + HALF)) * CAMERA_RIGHT_OFFSET);
    float sinRot = sin(rotOffset);
    float cosRot = cos(rotOffset);
    vec2 rotatedXY = noiseCoord.xy * mat2(vec2(cosRot, -sinRot), vec2(sinRot, cosRot));
    float rotatedX = rotatedXY.x;
    vec3 noisePosTemp = noiseCoord;
    noisePosTemp.x = rotatedX;
    float rotatedY = rotatedXY.y;
    
    // Wave perturbation
    float waveTime = animTime + (sin(rotAngle1) * 0.02);
    vec2 waveOffset = noisePosTemp.xz + (vec2(sin(waveTime + (noiseZ * WAVE_FREQ_MULT)), cos(waveTime + (rotatedX * WAVE_FREQ_MULT))) * TRACER_DIST_SCALE);
    float perturbedX = waveOffset.x;
    float perturbedZ = waveOffset.y;
    vec3 noisePosPerturbed = vec3(perturbedX, rotatedY, perturbedZ);
    float finalNoiseZ = perturbedZ + ((sin((perturbedX * PHASE_POWER_2) + (animTime * WAVE_ANIM_FREQ_1)) + sin((rotatedY * 2.84) + (animTime * WAVE_ANIM_FREQ_2))) * TRACER_DIST_SCALE);
    noisePosPerturbed.z = finalNoiseZ;
    
    // Base noise sampling
    vec3 baseNoiseCoord = noisePosPerturbed * renderParams.noise1Scale;
    vec3 timeOffset3D = vec3(2.0, 2.0, 4.5) * (animTime * TIME_OFFSET_SCALE);
    vec3 camRightOffset = cameraData.cameraRight * CAMERA_RIGHT_OFFSET;
    vec3 camUpOffset = cameraSideVector * CAMERA_RIGHT_OFFSET;
    
    vec4 noisePowerVec = vec4(renderParams.noisePower);
    vec4 lowFreqParams = vec4(renderParams.noiseColorA);
    vec4 highFreqParams = vec4(renderParams.noiseColorB);
    vec4 noiseBlendParam = vec4(renderParams.noiseMixFactor);
    
    vec4 baseNoiseProcessed = sampleProcessedNoise(abs(baseNoiseCoord) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    float baseNoiseCombined = combineNoiseChannels(baseNoiseProcessed);
    
    vec4 processedNoiseX = sampleProcessedNoise(abs(baseNoiseCoord + camRightOffset) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    vec4 processedNoiseY = sampleProcessedNoise(abs(baseNoiseCoord + camUpOffset) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    
    float normalGradStep = NORMAL_GRAD_STEP_BASE / renderParams.noise1Scale;
    vec3 noiseNormal = normalize(vec3(baseNoiseCombined - combineNoiseChannels(processedNoiseY), baseNoiseCombined - combineNoiseChannels(processedNoiseX), normalGradStep));
    
    // View transform and detail noise coordinate
    mat4 viewTransform = getViewTransform();
    float centeredPosZ = volumeCenteredPos.z;
    
    vec3 detailNoiseCoord = (noiseCoord + ((((viewTransform * vec4((noiseNormal + vec3(0.0, 0.0, 1.0)).xyz, 0.0)).xyz * pow(baseNoiseCombined, TIME_OFFSET_SCALE)) * renderParams.normalDetailScale) * CAMERA_RIGHT_OFFSET)) + (vec3(2.0, 2.0, 4.5) * ((((baseNoiseCombined - 1.0) * CAMERA_RIGHT_OFFSET) * renderParams.normalDetailScale) * centeredPosZ));
    detailNoiseCoord.x = detailNoiseCoord.x + (sin(finalNoiseZ + (animTime * DETAIL_TIME_MULT)) * TRACER_DIST_SCALE);
    
    // Detail noise sampling
    vec3 detailScaledCoord = detailNoiseCoord * renderParams.noise2Scale;
    vec4 detailNoiseProcessed = sampleProcessedNoise(detailScaledCoord, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    float detailNoiseCombined = combineNoiseChannels(detailNoiseProcessed);
    
    vec4 detailProcessedX = sampleProcessedNoise(detailScaledCoord + camRightOffset, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    vec4 detailProcessedY = sampleProcessedNoise(detailScaledCoord + camUpOffset, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    
    // Depth fade and combined noise
    float depthFade = renderParams.detailNoiseInfluence * (dot(rayDirection, cameraData.cameraForward) * clamp(distance(shadowTestPos, cameraData.cameraPosition) * DEPTH_FADE_DIST_SCALE, 0.0, 1.0));
    float combinedNoise = (mix(NOISE_CHANNEL_WEIGHT, clamp(baseNoiseCombined, 0.0, 1.0), renderParams.noise1Influence) + mix(NOISE_CHANNEL_WEIGHT, clamp(detailNoiseCombined, 0.0, 1.0), depthFade * SECOND_PASS_WEIGHT)) + renderParams.noiseOffset;
    
    // Height fade
    float heightFade;
    if (volumeData.volumeFadeParams._m0[volumeIdx].w < 1.0)
    {
        float heightParam = clamp(volumeData.volumeFadeParams._m0[volumeIdx].w, EPSILON, MAX_CLAMP_VALUE);
        float fadeStart = smoothstep(0.0, NORMAL_GRAD_STEP_BASE, heightParam);
        float fadeEnd = smoothstep(CAMERA_RIGHT_OFFSET, 1.0, heightParam);
        if (fadeStart == fadeEnd)
        {
            heightFade = effectiveDensity * heightParam;
        }
        else
        {
            vec3 heightTestPos = volumeCenteredPos;
            heightTestPos.z = centeredPosZ * HEIGHT_TEST_Z_SCALE;
            heightFade = effectiveDensity * clamp(smoothstep(fadeStart, fadeEnd, clamp(length(heightTestPos), 0.0, 1.0)), 0.0, 1.0);
        }
    }
    else
    {
        heightFade = effectiveDensity;
    }
    
    // Step density
    float stepDensity = mix(heightFade - (1.0 - combinedNoise), heightFade + combinedNoise, heightFade) * clamp((volumeData.volumeFadeParams._m0[volumeIdx].x * volumeData.volumeFadeParams._m0[volumeIdx].w) * DENSITY_FADE_MULT, 0.0, 1.0);
    if (stepDensity < EPSILON)
        return false;
    
    // ========== NORMAL CALCULATION (FULL DETAIL) ==========
    vec3 baseNormalDir = normalize(volumeCenteredPos) * mix(1.0, 0.0, clamp(shadowAmount, 0.0, 1.0));
    
    // Detail noise normal
    vec3 detailNoiseNormal = normalize(vec3(detailNoiseCombined - combineNoiseChannels(detailProcessedY), detailNoiseCombined - combineNoiseChannels(detailProcessedX), normalGradStep));
    
    vec4 normalTransform = viewTransform * vec4(((vec4(baseNormalDir.xyz, 0.0).xyzw * viewTransform).xyz + ((vec3((noiseNormal.xy * renderParams.noise1Influence) + ((detailNoiseNormal * mix(HALF, 1.0, clamp(baseNoiseCombined - HALF, 0.0, 1.0))).xy * (depthFade * PHASE_POWER_1)), 0.0) * renderParams.normalPerturbScale) * mix(1.0, 2.0, clamp((DISSIP_FADE_NEAR - distance(shadowTestPos, volumeData.volumeCenters._m0[volumeIdxInt].xyz)) * NORMAL_DIST_SCALE, 0.0, 1.0)))).xyz, 0.0);
    vec3 viewSpaceNormal = normalTransform.xyz;
    
    // ========== COLOR LOOKUP ==========
    vec3 scatterUVW = clamp(clamp(mix(volumeCenteredPos * dot(baseNormalDir, viewSpaceNormal), normalize(viewSpaceNormal + vec3(0.0, 0.0, HALF)) * length(volumeCenteredPos), vec3(CAMERA_RIGHT_OFFSET)) + vec3(HALF), vec3(0.03), vec3(0.97)), vec3(0.0), vec3(1.0));
    scatterUVW.x = (densityUOffset + (scatterUVW.x * VOLUME_TILE_SIZE)) * DENSITY_ATLAS_U_SCALE;
    vec4 scatterColor = textureLod(sampler3D(colorLUTTexture, volumeSampler), scatterUVW.xyz, 0.0);
    
    // ========== LIGHTING ==========
    float sunDot = dot(mix(baseNormalDir, viewSpaceNormal, vec3(renderParams.phaseBlend)), lightingData.mainLightDirection.xyz);
    float phaseFunction = pow(clamp((sunDot * PHASE_SCALE_1) + PHASE_OFFSET_1, 0.0, 1.0), PHASE_POWER_1) + pow(clamp((sunDot * PHASE_SCALE_2) - PHASE_OFFSET_2, 0.0, 1.0), PHASE_POWER_2);
    float sunScattering = (phaseFunction > 0.0) ? (phaseFunction * scatterColor.w) : phaseFunction;
    
    // ========== COLOR PROCESSING (RGB <-> HSV) ==========
    vec3 hsv = rgbToHsv(scatterColor.xyz);
    hsv.y = clamp(hsv.y * SATURATION_BOOST, 0.0, 1.0);
    vec3 finalRGB = hsvToRgb(hsv);
    
    // ========== LIT COLOR ==========
    vec3 litColor = (((((((normalize(finalRGB + vec3(COLOR_EPSILON)) * min(length(finalRGB), MAX_COLOR_LENGTH)) * clamp(1.0 - min(SECOND_PASS_WEIGHT, stepDensity), 0.0, 1.0)) * clamp(1.0 - (((heightFade * HEIGHT_FADE_DENSITY_MULT) - stepDensity) * renderParams.densityContrast), 0.0, 1.0)) * combinedNoise) * (0.75 + (sunScattering * SECOND_PASS_WEIGHT))) * (1.0 + (normalTransform.z * HALF))) * renderParams.baseColorIntensity) + ((lightingData.mainLightColor.xyz * ((HALF * sunScattering) * (1.0 - cavityStrength))) * renderParams.sunColorIntensity);
    
    // ========== TINTING AND DESATURATION ==========
    vec3 lumaWeights = vec3(LUMA_R, LUMA_G, LUMA_B);
    vec3 volumeTintedColor = litColor * volumeData.volumeTintColor._m0[volumeIdx].xyz;
    vec3 desaturatedColor = (mix(litColor, volumeTintedColor * (dot(litColor.xyz, lumaWeights) / dot((volumeTintedColor + vec3(COLOR_EPSILON)).xyz, lumaWeights)), vec3(HALF * (1.0 - volumeData.volumeFadeParams._m0[volumeIdx].z))) * mix(vec3(1.0), normalize(renderParams.colorTint + vec3(MIN_DENSITY_THRESHOLD)) * COLOR_TINT_NORM, vec3(clamp(HALF + (stepDensity * HSV_HUE_SECTORS), 0.0, 1.0)))).xyz;
    vec3 shadowedColor = mix(desaturatedColor, desaturatedColor * shadowMultiplier, vec3(SHADOW_BLEND_FACTOR)).xyz;
    
    // ========== FOG AND ALPHA ==========
    float fogAmount = smoothstep(0.0, CAMERA_RIGHT_OFFSET, stepDensity + FOG_STEP_THRESHOLD) * (((clamp((renderParams.godrayFalloffDist - occlusionDistance) / renderParams.godrayFalloffDist, 0.0, 1.0) * heightFade) * FOG_DENSITY_MULT) * renderParams.godrayIntensity);
    float stepAlpha = smoothstep(0.0, CAMERA_RIGHT_OFFSET / (renderParams.alphaScale * mix(HALF, 2.0, stepColor.w)), stepDensity);
    
    vec3 tracerGlowColor = vec3(TRACER_GLOW_R, TRACER_GLOW_G, TRACER_GLOW_B);
    vec4 stepContribution = vec4(((shadowedColor + ((shadowedColor * tracerGlowColor) * tracerGlow)) * mix(1.0, SHADOW_AMOUNT_SCALE, clamp(shadowAmount * TRACER_OFFSET_SCALE, 0.0, 1.0))) * stepAlpha, stepAlpha);
    
    // ========== ACCUMULATION ==========
    float sampleWeight = renderParams.baseStepSize * FIRST_PASS_WEIGHT;
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
    
    return (stepAlpha + fogAmount) > 0.0;
}

// Second pass sample function (slightly different weight calculation)
bool sampleVolumeSecondPass(
    vec3 sp2StartPos,
    vec3 marchEndWorldPos,
    vec3 backProjectedPoint,
    vec3 rayDirection,
    vec3 cameraSideVector,
    uint volumeIdx,
    float densityUOffset,
    uint densityPageIdx,
    float tracerGlow,
    vec3 tracerDir,
    float cavityStrength,
    bool hasExplosionLayer,
    bool skipDueToOcclusion,
    float sp2RayLength,
    inout vec4 stepColor,
    inout float stepLightEnergy,
    inout float stepFogDensity)
{
    vec3 tracerOffsetSamplePos = sp2StartPos + ((normalize(tracerDir) * pow(cavityStrength, PHASE_POWER_2)) * TRACER_OFFSET_SCALE);
    
    int volumeIdxInt = int(volumeIdx);
    vec3 volumeLocalPos = clamp((((tracerOffsetSamplePos - volumeData.volumeCenters._m0[volumeIdxInt].xyz) * vec3(VOLUME_LOCAL_SCALE)) + vec3(VOLUME_CENTER_OFFSET)) * vec3(VOLUME_UVW_SCALE), vec3(0.0), vec3(1.0));
    vec3 volumeUVW = clamp(volumeLocalPos, vec3(0.0), vec3(1.0));
    volumeUVW.x = (densityUOffset + (volumeUVW.x * VOLUME_TILE_SIZE)) * DENSITY_ATLAS_U_SCALE;
    
    vec4 densitySample = textureLod(sampler3D(volumeDensityTexture, volumeSampler), volumeUVW.xyz, 0.0);
    vec2 densityChannels = mix(densitySample.xz, densitySample.yw, vec2(volumeData.volumeAnimState._m0[volumeIdx].y));
    float sampledDensityMin = densityChannels.x;
    float sampledDensityMax = densityChannels.y;
    
    float distanceToMarchEnd = distance(tracerOffsetSamplePos, marchEndWorldPos);
    float adjustedDensity = sampledDensityMax;
    if (sampledDensityMin > sampledDensityMax)
        adjustedDensity = mix(sampledDensityMax, sampledDensityMin, smoothstep(DENSITY_BLEND_NEAR, DENSITY_BLEND_FAR, distanceToMarchEnd));
    
    float cavityDensity = clamp(mix(adjustedDensity, -VOLUME_LOCAL_SCALE, cavityStrength), 0.0, 1.0);
    if (cavityDensity <= MIN_DENSITY_THRESHOLD)
        return false;
    
    float occlusionDistance = max(0.0, distanceToMarchEnd - min(TRACER_OFFSET_SCALE, abs(backProjectedPoint.z - volumeData.volumeCenters._m0[volumeIdxInt].z) * 2.0));
    float densityMultiplier = clamp(clamp((cavityDensity - MIN_DENSITY_THRESHOLD) * DENSITY_REMAP_FACTOR, 0.0, 1.0), 0.0, 1.0) * volumeData.volumeFadeParams._m0[volumeIdx].x;
    float finalScaledDensity = clamp(densityMultiplier + ((1.0 - clamp(distance(cameraData.cameraPosition, tracerOffsetSamplePos) * CAMERA_DIST_SCALE, 0.0, 1.0)) * densityMultiplier), 0.0, 1.0);
    
    vec3 shadowTestPos = tracerOffsetSamplePos;
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
        effectiveDensity = mix(finalScaledDensity * 0.02, finalScaledDensity, dissipScale);
    }
    
    // Full noise calculation (same as first pass)
    float animTime = cameraData.globalTime * renderParams.timeScale;
    vec3 volumeCenteredPos = volumeLocalPos - vec3(HALF);
    vec3 noiseCoord = volumeCenteredPos * NOISE_COORD_SCALE;
    float noiseZ = noiseCoord.z;
    
    float rotAngle1 = animTime * ROTATION_TIME_MULT;
    float rotOffset = (animTime * ROTATION_OFFSET_BASE) + ((((CAMERA_RIGHT_OFFSET + ((sin(noiseZ * 5.0) + HALF) * 0.15)) * sin(rotAngle1 + HALF)) * sin((animTime * ROTATION_MOD_FREQ) + HALF)) * CAMERA_RIGHT_OFFSET);
    float sinRot = sin(rotOffset);
    float cosRot = cos(rotOffset);
    vec2 rotatedXY = noiseCoord.xy * mat2(vec2(cosRot, -sinRot), vec2(sinRot, cosRot));
    float rotatedX = rotatedXY.x;
    vec3 noisePosTemp = noiseCoord;
    noisePosTemp.x = rotatedX;
    float rotatedY = rotatedXY.y;
    
    float waveTime = animTime + (sin(rotAngle1) * 0.02);
    vec2 waveOffset = noisePosTemp.xz + (vec2(sin(waveTime + (noiseZ * WAVE_FREQ_MULT)), cos(waveTime + (rotatedX * WAVE_FREQ_MULT))) * TRACER_DIST_SCALE);
    float perturbedX = waveOffset.x;
    float perturbedZ = waveOffset.y;
    vec3 noisePosPerturbed = vec3(perturbedX, rotatedY, perturbedZ);
    float finalNoiseZ = perturbedZ + ((sin((perturbedX * PHASE_POWER_2) + (animTime * WAVE_ANIM_FREQ_1)) + sin((rotatedY * 2.84) + (animTime * WAVE_ANIM_FREQ_2))) * TRACER_DIST_SCALE);
    noisePosPerturbed.z = finalNoiseZ;
    
    vec3 baseNoiseCoord = noisePosPerturbed * renderParams.noise1Scale;
    vec3 timeOffset3D = vec3(2.0, 2.0, 4.5) * (animTime * TIME_OFFSET_SCALE);
    vec3 camRightOffset = cameraData.cameraRight * CAMERA_RIGHT_OFFSET;
    vec3 camUpOffset = cameraSideVector * CAMERA_RIGHT_OFFSET;
    
    vec4 noisePowerVec = vec4(renderParams.noisePower);
    vec4 lowFreqParams = vec4(renderParams.noiseColorA);
    vec4 highFreqParams = vec4(renderParams.noiseColorB);
    vec4 noiseBlendParam = vec4(renderParams.noiseMixFactor);
    
    vec4 baseNoiseProcessed = sampleProcessedNoise(abs(baseNoiseCoord) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    float baseNoiseCombined = combineNoiseChannels(baseNoiseProcessed);
    
    vec4 processedNoiseX = sampleProcessedNoise(abs(baseNoiseCoord + camRightOffset) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    vec4 processedNoiseY = sampleProcessedNoise(abs(baseNoiseCoord + camUpOffset) - timeOffset3D, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    
    float normalGradStep = NORMAL_GRAD_STEP_BASE / renderParams.noise1Scale;
    vec3 noiseNormal = normalize(vec3(baseNoiseCombined - combineNoiseChannels(processedNoiseY), baseNoiseCombined - combineNoiseChannels(processedNoiseX), normalGradStep));
    
    mat4 viewTransform = getViewTransform();
    float centeredPosZ = volumeCenteredPos.z;
    
    vec3 detailNoiseCoord = (noiseCoord + ((((viewTransform * vec4((noiseNormal + vec3(0.0, 0.0, 1.0)).xyz, 0.0)).xyz * pow(baseNoiseCombined, TIME_OFFSET_SCALE)) * renderParams.normalDetailScale) * CAMERA_RIGHT_OFFSET)) + (vec3(2.0, 2.0, 4.5) * ((((baseNoiseCombined - 1.0) * CAMERA_RIGHT_OFFSET) * renderParams.normalDetailScale) * centeredPosZ));
    detailNoiseCoord.x = detailNoiseCoord.x + (sin(finalNoiseZ + (animTime * DETAIL_TIME_MULT)) * TRACER_DIST_SCALE);
    
    vec3 detailScaledCoord = detailNoiseCoord * renderParams.noise2Scale;
    vec4 detailNoiseProcessed = sampleProcessedNoise(detailScaledCoord, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    float detailNoiseCombined = combineNoiseChannels(detailNoiseProcessed);
    
    vec4 detailProcessedX = sampleProcessedNoise(detailScaledCoord + camRightOffset, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    vec4 detailProcessedY = sampleProcessedNoise(detailScaledCoord + camUpOffset, noisePowerVec, lowFreqParams, highFreqParams, noiseBlendParam);
    
    float depthFade = renderParams.detailNoiseInfluence * (dot(rayDirection, cameraData.cameraForward) * clamp(distance(shadowTestPos, cameraData.cameraPosition) * DEPTH_FADE_DIST_SCALE, 0.0, 1.0));
    float combinedNoise = (mix(NOISE_CHANNEL_WEIGHT, clamp(baseNoiseCombined, 0.0, 1.0), renderParams.noise1Influence) + mix(NOISE_CHANNEL_WEIGHT, clamp(detailNoiseCombined, 0.0, 1.0), depthFade * SECOND_PASS_WEIGHT)) + renderParams.noiseOffset;
    
    float heightFade;
    if (volumeData.volumeFadeParams._m0[volumeIdx].w < 1.0)
    {
        float heightParam = clamp(volumeData.volumeFadeParams._m0[volumeIdx].w, EPSILON, MAX_CLAMP_VALUE);
        float fadeStart = smoothstep(0.0, NORMAL_GRAD_STEP_BASE, heightParam);
        float fadeEnd = smoothstep(CAMERA_RIGHT_OFFSET, 1.0, heightParam);
        if (fadeStart == fadeEnd)
            heightFade = effectiveDensity * heightParam;
        else
        {
            vec3 heightTestPos = volumeCenteredPos;
            heightTestPos.z = centeredPosZ * HEIGHT_TEST_Z_SCALE;
            heightFade = effectiveDensity * clamp(smoothstep(fadeStart, fadeEnd, clamp(length(heightTestPos), 0.0, 1.0)), 0.0, 1.0);
        }
    }
    else
    {
        heightFade = effectiveDensity;
    }
    
    float stepDensity = mix(heightFade - (1.0 - combinedNoise), heightFade + combinedNoise, heightFade) * clamp((volumeData.volumeFadeParams._m0[volumeIdx].x * volumeData.volumeFadeParams._m0[volumeIdx].w) * DENSITY_FADE_MULT, 0.0, 1.0);
    if (stepDensity < EPSILON)
        return false;
    
    vec3 baseNormalDir = normalize(volumeCenteredPos) * mix(1.0, 0.0, clamp(shadowAmount, 0.0, 1.0));
    vec3 detailNoiseNormal = normalize(vec3(detailNoiseCombined - combineNoiseChannels(detailProcessedY), detailNoiseCombined - combineNoiseChannels(detailProcessedX), normalGradStep));
    
    vec4 normalTransform = viewTransform * vec4(((vec4(baseNormalDir.xyz, 0.0).xyzw * viewTransform).xyz + ((vec3((noiseNormal.xy * renderParams.noise1Influence) + ((detailNoiseNormal * mix(HALF, 1.0, clamp(baseNoiseCombined - HALF, 0.0, 1.0))).xy * (depthFade * PHASE_POWER_1)), 0.0) * renderParams.normalPerturbScale) * mix(1.0, 2.0, clamp((DISSIP_FADE_NEAR - distance(shadowTestPos, volumeData.volumeCenters._m0[volumeIdxInt].xyz)) * NORMAL_DIST_SCALE, 0.0, 1.0)))).xyz, 0.0);
    vec3 viewSpaceNormal = normalTransform.xyz;
    
    vec3 scatterUVW = clamp(clamp(mix(volumeCenteredPos * dot(baseNormalDir, viewSpaceNormal), normalize(viewSpaceNormal + vec3(0.0, 0.0, HALF)) * length(volumeCenteredPos), vec3(CAMERA_RIGHT_OFFSET)) + vec3(HALF), vec3(0.03), vec3(0.97)), vec3(0.0), vec3(1.0));
    scatterUVW.x = (densityUOffset + (scatterUVW.x * VOLUME_TILE_SIZE)) * DENSITY_ATLAS_U_SCALE;
    vec4 scatterColor = textureLod(sampler3D(colorLUTTexture, volumeSampler), scatterUVW.xyz, 0.0);
    
    float sunDot = dot(mix(baseNormalDir, viewSpaceNormal, vec3(renderParams.phaseBlend)), lightingData.mainLightDirection.xyz);
    float phaseFunction = pow(clamp((sunDot * PHASE_SCALE_1) + PHASE_OFFSET_1, 0.0, 1.0), PHASE_POWER_1) + pow(clamp((sunDot * PHASE_SCALE_2) - PHASE_OFFSET_2, 0.0, 1.0), PHASE_POWER_2);
    float sunScattering = (phaseFunction > 0.0) ? (phaseFunction * scatterColor.w) : phaseFunction;
    
    vec3 hsv = rgbToHsv(scatterColor.xyz);
    hsv.y = clamp(hsv.y * SATURATION_BOOST, 0.0, 1.0);
    vec3 finalRGB = hsvToRgb(hsv);
    
    vec3 litColor = (((((((normalize(finalRGB + vec3(COLOR_EPSILON)) * min(length(finalRGB), MAX_COLOR_LENGTH)) * clamp(1.0 - min(SECOND_PASS_WEIGHT, stepDensity), 0.0, 1.0)) * clamp(1.0 - (((heightFade * HEIGHT_FADE_DENSITY_MULT) - stepDensity) * renderParams.densityContrast), 0.0, 1.0)) * combinedNoise) * (0.75 + (sunScattering * SECOND_PASS_WEIGHT))) * (1.0 + (normalTransform.z * HALF))) * renderParams.baseColorIntensity) + ((lightingData.mainLightColor.xyz * ((HALF * sunScattering) * (1.0 - cavityStrength))) * renderParams.sunColorIntensity);
    
    vec3 lumaWeights = vec3(LUMA_R, LUMA_G, LUMA_B);
    vec3 volumeTintedColor = litColor * volumeData.volumeTintColor._m0[volumeIdx].xyz;
    vec3 desaturatedColor = (mix(litColor, volumeTintedColor * (dot(litColor.xyz, lumaWeights) / dot((volumeTintedColor + vec3(COLOR_EPSILON)).xyz, lumaWeights)), vec3(HALF * (1.0 - volumeData.volumeFadeParams._m0[volumeIdx].z))) * mix(vec3(1.0), normalize(renderParams.colorTint + vec3(MIN_DENSITY_THRESHOLD)) * COLOR_TINT_NORM, vec3(clamp(HALF + (stepDensity * HSV_HUE_SECTORS), 0.0, 1.0)))).xyz;
    vec3 shadowedColor = mix(desaturatedColor, desaturatedColor * shadowMultiplier, vec3(SHADOW_BLEND_FACTOR)).xyz;
    
    float fogAmount = smoothstep(0.0, CAMERA_RIGHT_OFFSET, stepDensity + FOG_STEP_THRESHOLD) * (((clamp((renderParams.godrayFalloffDist - occlusionDistance) / renderParams.godrayFalloffDist, 0.0, 1.0) * heightFade) * FOG_DENSITY_MULT) * renderParams.godrayIntensity);
    float stepAlpha = smoothstep(0.0, CAMERA_RIGHT_OFFSET / (renderParams.alphaScale * mix(HALF, 2.0, stepColor.w)), stepDensity);
    
    vec3 tracerGlowColor = vec3(TRACER_GLOW_R, TRACER_GLOW_G, TRACER_GLOW_B);
    vec4 stepContribution = vec4(((shadowedColor + ((shadowedColor * tracerGlowColor) * tracerGlow)) * mix(1.0, SHADOW_AMOUNT_SCALE, clamp(shadowAmount * TRACER_OFFSET_SCALE, 0.0, 1.0))) * stepAlpha, stepAlpha);
    
    // Different weight for second pass
    float sampleWeight = sp2RayLength * SECOND_PASS_WEIGHT;
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
    
    return (stepAlpha + fogAmount) > 0.0;
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

void main()
{
    vec3 rayDirection = normalize(inWorldViewDir);
    vec3 invRayDirection = vec3(1.0) / rayDirection;
    
    // Scene AABB intersection
    vec2 sceneHit = rayBoxIntersection(invRayDirection, cameraData.cameraPosition, volumeData.sceneAABBMin.xyz, volumeData.sceneAABBMax.xyz);
    float rayEnterDistance = sceneHit.x;
    float rayExitDistance = sceneHit.y;
    
    if (rayEnterDistance > rayExitDistance)
        discard;
    
    float baseStepDistance = renderParams.baseStepSize * STEP_DISTANCE_MULTIPLIER;
    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    float rayMarchStart = max(rayEnterDistance, RAY_NEAR_CLIP_OFFSET) + (((baseStepDistance * fract(texelFetch(blueNoiseTexture, ivec3(fragCoord & screenData.noiseTileSize, 0).xy, 0).x + (cameraData.globalTime * GOLDEN_RATIO_FRACT))) * renderParams.jitterScale) * mix(JITTER_MIN_BLEND, JITTER_MAX_BLEND, clamp((rayEnterDistance + JITTER_DIST_OFFSET) * JITTER_DIST_SCALE, 0.0, 1.0)));
    
    ivec2 screenCoord = ivec3(fragCoord, 0).xy;
    float depthRange = cameraData.depthFar - cameraData.depthNear;
    float linearSceneDepth = (clamp((texelFetch(sceneDepthTexture, screenCoord, 0).x - cameraData.depthNear) / depthRange, 0.0, 1.0) * cameraData.projectionParams.z) + cameraData.projectionParams.w;
    float rayDotForward = dot(cameraData.cameraForward.xyz, rayDirection);
    float sceneDepthAlongRay = 1.0 / (linearSceneDepth * rayDotForward);
    
    vec3 negRayDirection = (-rayDirection).xyz;
    vec3 backProjectedPoint = cameraData.cameraPosition.xyz + (negRayDirection * (1.0 / (linearSceneDepth * dot(cameraData.cameraForward.xyz, negRayDirection))));
    
    bool hasExplosionLayer = volumeData.explosionCount > 0u;
    bool skipDueToOcclusion = false;
    if (hasExplosionLayer)
    {
        skipDueToOcclusion = ((1.0 / (((clamp((texelFetch(secondaryDepthTexture, ivec3(ivec2(gl_FragCoord.xy * float(renderParams.depthDownscaleFactor)), 0).xy, 0).x - cameraData.depthNear) / depthRange, 0.0, 1.0) * cameraData.projectionParams.z) + cameraData.projectionParams.w) * rayDotForward)) - sceneDepthAlongRay) > OCCLUSION_DEPTH_THRESHOLD;
    }
    
    float rayMarchEnd = sceneDepthAlongRay - SCENE_DEPTH_OFFSET;
    if (rayMarchStart > rayMarchEnd)
        discard;
    
    vec3 marchStartWorldPos = cameraData.cameraPosition + (rayDirection * rayMarchStart);
    vec3 marchEndWorldPos = cameraData.cameraPosition + (rayDirection * min(rayExitDistance, rayMarchEnd));
    
    // Active volume detection
    uint activeVolumeMask = uint(texelFetch(volumeMaskTexture, screenCoord, 0).x);
    VolumeBoxData activeVolumeBoxes[1];
    uint activeVolumeCount = 0u;
    uint volumeIndex = 0u;
    uint currentVolumeBit = activeVolumeMask;
    
    for (;;)
    {
        if (currentVolumeBit == 0u)
            break;
        
        if ((currentVolumeBit & 1u) != 0u)
        {
            vec2 volHit = rayBoxIntersection(invRayDirection, cameraData.cameraPosition, volumeData.volumeMinBounds._m0[volumeIndex].xyz, volumeData.volumeMaxBounds._m0[volumeIndex].xyz);
            activeVolumeBoxes[activeVolumeCount]._m0.x = volHit.x;
            activeVolumeBoxes[activeVolumeCount]._m0.y = volHit.y;
            activeVolumeBoxes[activeVolumeCount]._m0.z = float(volumeIndex);
            activeVolumeCount++;
        }
        
        if (activeVolumeCount >= MAX_ACTIVE_VOLUMES)
            break;
        
        currentVolumeBit >>= 1u;
        volumeIndex++;
    }
    
    // Main ray march state
    VolumeBoxData volumeBoxList[1] = activeVolumeBoxes;
    float totalMarchDistance = length(marchEndWorldPos - marchStartWorldPos);
    int maxStepCount = int(clamp(ceil(totalMarchDistance / baseStepDistance) + STEP_COUNT_PADDING, 1.0, MAX_MARCH_STEPS));
    uint validVolumeCount = min(activeVolumeCount, MAX_ACTIVE_VOLUMES);
    vec3 cameraSideVector = cross(cameraData.cameraForward, cameraData.cameraRight);
    float totalRayDistance = rayMarchStart + totalMarchDistance;
    
    vec4 accumulatedColor = vec4(0.0);
    vec3 accumulatedTracerDirection = vec3(0.0, 0.0, MIN_DENSITY_THRESHOLD);
    vec3 currentMarchPos = marchStartWorldPos;
    vec3 lastValidSamplePos = marchEndWorldPos;
    vec3 currentVolumePos = marchEndWorldPos;
    
    bool foundOpaqueFlag = false;
    float accumulatedLightEnergy = 0.0;
    float accumulatedFogDensity = 0.0;
    float accumulatedTracerGlow = 0.0;
    float tracerCavityStrength = 0.0;
    uint tracerAnimationCounter = 0u;
    float currentRayDistance = rayMarchStart;
    bool hasValidSample = false;
    
    vec3 loopLastHitPos = lastValidSamplePos;
    vec3 loopFirstHitPos = currentVolumePos;
    float loopSunlightOut = accumulatedLightEnergy;
    float loopGodrayOut = accumulatedFogDensity;
    vec4 loopColorOut = accumulatedColor;
    float loopRayTOut = currentRayDistance;
    bool loopHadPrevSample = hasValidSample;
    
    // Main ray march loop
    for (int stepIndex = 0; stepIndex < maxStepCount; stepIndex++)
    {
        // Tracer cache refresh
        bool shouldUpdateTracerAnim = false;
        if (volumeData.activeTracerCount > 0u)
        {
            shouldUpdateTracerAnim = ((stepIndex & TRACER_CACHE_INTERVAL) == 0) || (stepIndex < TRACER_WARMUP_STEPS);
        }
        
        if (shouldUpdateTracerAnim)
        {
            accumulatedTracerGlow = 0.0;
            tracerCavityStrength = 0.0;
            tracerAnimationCounter = 0u;
            accumulatedTracerDirection = vec3(0.0, 0.0, MIN_DENSITY_THRESHOLD);
        }
        
        vec3 samplePosition = currentVolumePos;
        bool hadPreviousSample = hasValidSample;
        vec4 stepColor = accumulatedColor;
        vec3 stepTracerDir = accumulatedTracerDirection;
        float stepLightEnergy = accumulatedLightEnergy;
        float stepFogDensity = accumulatedFogDensity;
        float stepTracerGlow = accumulatedTracerGlow;
        float stepCavityStrength = tracerCavityStrength;
        uint stepTracerBits = tracerAnimationCounter;
        
        bool innerLoopBreak = false;
        
        // Volume loop
        for (uint volumeCheckIndex = 0u; volumeCheckIndex < validVolumeCount; volumeCheckIndex++)
        {
            if (currentRayDistance < volumeBoxList[volumeCheckIndex]._m0.x)
                continue;
            if (currentRayDistance > volumeBoxList[volumeCheckIndex]._m0.y)
                continue;
            
            // Tracer influence
            if (volumeData.activeTracerCount > 0u && (stepTracerBits & 3u) == 0u)
            {
                calculateTracerInfluence(currentMarchPos, stepTracerGlow, stepTracerDir, stepCavityStrength);
                stepTracerBits |= 1u;
            }
            
            uint currentVolumeIdx = uint(volumeBoxList[volumeCheckIndex]._m0.z);
            uint densityPageIdx = uint(volumeData.volumeAnimState._m0[currentVolumeIdx].z);
            float densityUOffset = DENSITY_PAGE_STRIDE * float(densityPageIdx);
            
            bool hasValidSampleResult = sampleVolumeAtPosition(
                currentMarchPos, marchEndWorldPos, backProjectedPoint, rayDirection, cameraSideVector,
                currentVolumeIdx, densityUOffset, densityPageIdx,
                stepTracerGlow, stepTracerDir, stepCavityStrength,
                hasExplosionLayer, skipDueToOcclusion,
                stepColor, stepLightEnergy, stepFogDensity);
            
            // Track hit positions
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
        
        // Only update loop outputs if we didn't break due to opaque
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
        
        vec3 nextMarchPos = currentMarchPos + (rayDirection * baseStepDistance);
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
    
    // Finalize first pass results
    vec3 finalLastHitPos = loopLastHitPos;
    vec3 finalFirstHitPos = loopFirstHitPos;
    float finalSunlightAccum = loopSunlightOut;
    float finalGodrayAccum = loopGodrayOut;
    vec4 finalAccumColor = loopColorOut;
    
    // Second pass
    if (!foundOpaqueFlag && renderParams.enableSecondPass != 0)
    {
        float sp2StartT = loopRayTOut - baseStepDistance;
        vec3 sp2StartPos = marchStartWorldPos + (rayDirection * totalMarchDistance);
        float sp2RayLength = totalRayDistance - sp2StartT;
        
        vec4 sp2ColorAccum = loopColorOut;
        vec3 sp2TracerDir = accumulatedTracerDirection;
        vec3 sp2CurrentPos = loopFirstHitPos;
        bool sp2HadSampleState = loopHadPrevSample;
        float sp2SunAccum = loopSunlightOut;
        float sp2FogAccum = loopGodrayOut;
        float sp2CachedGlow = accumulatedTracerGlow;
        float sp2CachedCavity = tracerCavityStrength;
        uint sp2CachedBits = tracerAnimationCounter;
        
        bool sp2EarlyExit = false;
        
        for (uint sp2VolumeIdx = 0u; sp2VolumeIdx < validVolumeCount; sp2VolumeIdx++)
        {
            if (sp2StartT < volumeBoxList[sp2VolumeIdx]._m0.x)
                continue;
            if (sp2StartT > volumeBoxList[sp2VolumeIdx]._m0.y)
                continue;
            
            // Tracer influence
            if (volumeData.activeTracerCount > 0u && (sp2CachedBits & 3u) == 0u)
            {
                calculateTracerInfluence(sp2StartPos, sp2CachedGlow, sp2TracerDir, sp2CachedCavity);
                sp2CachedBits |= 1u;
            }
            
            uint sp2VolumeId = uint(volumeBoxList[sp2VolumeIdx]._m0.z);
            uint sp2DensityPageIdx = uint(volumeData.volumeAnimState._m0[sp2VolumeId].z);
            float sp2UOffset = DENSITY_PAGE_STRIDE * float(sp2DensityPageIdx);
            
            bool sp2HasDensity = sampleVolumeSecondPass(
                sp2StartPos, marchEndWorldPos, backProjectedPoint, rayDirection, cameraSideVector,
                sp2VolumeId, sp2UOffset, sp2DensityPageIdx,
                sp2CachedGlow, sp2TracerDir, sp2CachedCavity,
                hasExplosionLayer, skipDueToOcclusion, sp2RayLength,
                sp2ColorAccum, sp2SunAccum, sp2FogAccum);
            
            bool sp2ShouldRecordFirstHit = sp2HasDensity && !sp2HadSampleState;
            if (sp2ShouldRecordFirstHit)
                sp2CurrentPos = sp2StartPos;
            
            // Track last valid sample position
            vec3 sp2LastSamplePos = loopLastHitPos;
            if (sp2HasDensity)
                sp2LastSamplePos = sp2StartPos;
            
            if (sp2ColorAccum.w > OPAQUE_THRESHOLD)
            {
                sp2ColorAccum.w = 1.0;
                finalLastHitPos = sp2StartPos;
                finalFirstHitPos = sp2CurrentPos;
                finalSunlightAccum = sp2SunAccum;
                finalGodrayAccum = sp2FogAccum;
                finalAccumColor = sp2ColorAccum;
                sp2EarlyExit = true;
                break;
            }
            
            if (sp2ShouldRecordFirstHit)
                sp2HadSampleState = true;
            
            // Update the last hit position for final output
            loopLastHitPos = sp2LastSamplePos;
        }
        
        if (!sp2EarlyExit)
        {
            finalLastHitPos = loopLastHitPos;
            finalFirstHitPos = sp2CurrentPos;
            finalSunlightAccum = sp2SunAccum;
            finalGodrayAccum = sp2FogAccum;
            finalAccumColor = sp2ColorAccum;
        }
    }
    
    // Final color processing
    float sunRimDot = pow(clamp(dot(normalize(rayDirection), lightingData.mainLightDirection.xyz), 0.0, 1.0), RIM_LIGHT_POWER) * RIM_LIGHT_SCALE;
    float foggedDensity = clamp(finalGodrayAccum - (finalAccumColor.w * CAMERA_RIGHT_OFFSET), 0.0, 1.0);
    vec4 preRimColor = mix(vec4(finalAccumColor.xyz * mix(1.0, 0.0, foggedDensity), finalAccumColor.w + foggedDensity), finalAccumColor, bvec4(renderParams.godrayIntensity == 0.0));
    vec3 rimEnhancedColor = preRimColor.xyz * (vec3(1.0) + ((pow(lightingData.mainLightColor.xyz, vec3(2.0)) * (((sunRimDot + (pow(sunRimDot, RIM_HIGHLIGHT_POWER) * RIM_HIGHLIGHT_SCALE)) * mix(1.0, 0.0, pow(finalAccumColor.w, HALF))) * finalAccumColor.w)) * (finalSunlightAccum * renderParams.rimLightIntensity)));
    vec4 finalOutputColor = preRimColor;
    finalOutputColor.x = rimEnhancedColor.x;
    finalOutputColor.y = rimEnhancedColor.y;
    finalOutputColor.z = rimEnhancedColor.z;
    float finalAlpha = preRimColor.w;
    
    if (finalAlpha < EPSILON)
        discard;
    
    // Depth output
    float logDepthRange = screenData.logDepthFar - screenData.logDepthNear;
    float logDepthNear = (((log(dot(cameraData.cameraForward.xyz, finalFirstHitPos.xyz - cameraData.cameraPosition.xyz)) - screenData.logDepthNear) / logDepthRange) * 2.0) - 1.0;
    float logDepthFar = (((log(dot(cameraData.cameraForward.xyz, finalLastHitPos.xyz - cameraData.cameraPosition.xyz)) - screenData.logDepthNear) / logDepthRange) * 2.0) - 1.0;
    
    // Moment buffer calculation
    vec4 moment0Accum = vec4(0.0);
    vec4 moment1Accum = vec4(0.0);
    vec4 moment2Accum = vec4(0.0);
    
    for (int momentLoopCounter = 0; momentLoopCounter < MOMENT_LOOP_COUNT; momentLoopCounter++)
    {
        int momentLoopIdx = momentLoopCounter + 1;
        float momentParam = SECOND_PASS_WEIGHT * float(momentLoopIdx);
        float depthInterpolated = mix(logDepthNear, logDepthFar, momentParam);
        float momentWeight = -log(1.0 - clamp(finalAlpha * momentParam, EPSILON, MAX_CLAMP_VALUE));
        float depthSquared = depthInterpolated * depthInterpolated;
        float depthQuartic = depthSquared * depthSquared;
        moment0Accum += vec4(momentWeight, 0.0, 0.0, 0.0);
        moment1Accum += vec4(vec2(depthInterpolated, depthSquared) * momentWeight, 0.0, 0.0);
        moment2Accum += vec4(depthSquared * depthInterpolated, depthQuartic, depthQuartic * depthInterpolated, depthQuartic * depthSquared) * momentWeight;
    }
    
    outMoment0 = moment0Accum;
    outMoment1 = moment1Accum;
    outMoment2 = moment2Accum;
    outSmokeColor = finalOutputColor;
    outDepthMinMax = vec4(logDepthNear, logDepthFar, 0.0, 0.0);
    outTransmittance = finalAlpha;
}
 