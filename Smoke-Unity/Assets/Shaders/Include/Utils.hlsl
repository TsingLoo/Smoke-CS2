#ifndef UTILS_INCLUDED
#define UTILS_INCLUDED

#include  "./Defines.hlsl"

float PhaseHG(float cosTheta, float g)
{
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

float3 RGBtoHSV(float3 rgb)
{
    float maxVal = max(rgb.r, max(rgb.g, rgb.b));
    float minVal = min(rgb.r, min(rgb.g, rgb.b));
    float delta = maxVal - minVal;
                
    float3 hsv = float3(0, 0, maxVal);
                
    if (delta != 0.0)
    {
        hsv.y = delta / maxVal;
                    
        float3 deltas = (maxVal.xxx - rgb) / delta;
        float3 offset = deltas.xyz - deltas.zxy;
        float2 hueOffset = offset.xy + float2(2.0, 4.0);
                    
        if (rgb.r >= maxVal)
            hsv.x = offset.z;
        else if (rgb.g >= maxVal)
            hsv.x = hueOffset.x;
        else
            hsv.x = hueOffset.y;
                    
        hsv.x = frac(hsv.x / 6.0);
    }
                
    return hsv;
}

float3 HSVtoRGB(float3 hsv)
{
    if (hsv.y == 0.0)
        return hsv.zzz;
                
    float hue = hsv.x * 6.0;
    float sector = floor(hue);
    float fract = hue - sector;
                
    float p = hsv.z * (1.0 - hsv.y);
    float q = hsv.z * (1.0 - hsv.y * fract);
    float t = hsv.z * (1.0 - hsv.y * (1.0 - fract));
                
    if (sector == 0.0)      return float3(hsv.z, t, p);
    else if (sector == 1.0) return float3(q, hsv.z, p);
    else if (sector == 2.0) return float3(p, hsv.z, t);
    else if (sector == 3.0) return float3(p, q, hsv.z);
    else if (sector == 4.0) return float3(t, p, hsv.z);
    else                    return float3(hsv.z, p, q);
}

float SampleLayeredNoise(Texture3D noiseTex3D, SamplerState noiseSampler, float noiseScale, float detailNoiseScale, float3 worldPos, float time, float noiseSpeed)
{
    // Base noise with animation
    float3 noiseCoord = worldPos * noiseScale * 0.07;
                
    // Animate noise (CS2 uses time-based rotation and offset)
    float timeOffset = time * noiseSpeed;
    float s = sin(timeOffset);
    float c = cos(timeOffset);
    float2x2 rot = float2x2(c, -s, s, c);
    noiseCoord.xy = mul(rot, noiseCoord.xy);
                
    // Sample base noise
    float4 noiseSample = noiseTex3D.SampleLevel(noiseSampler, noiseCoord, 0);
    float noise1 = (noiseSample.x + noiseSample.y * 0.95) * 4.6;
                
    // Detail noise with different scale
    float3 detailCoord = worldPos * detailNoiseScale * 0.07;
    float4 detailSample = noiseTex3D.SampleLevel(noiseSampler, detailCoord, 0);
    float noise2 = (detailSample.x + detailSample.y * 0.95) * 4.6;
                
    return (noise1 + noise2) * 0.5;
}

float3 SampleColorLUT(Texture3D colorLUT3D, SamplerState colorLUT3DSampler, float atlasTextureWidth, float atlasSliceWidth, float saturation, float colorBoost, float3 normalizedPos, float density, uint volumeIndex)
{
    // Clamp position to valid range
    float3 lutCoord = clamp(normalizedPos, 0.03, 0.97);
                
    // Add volume index offset (CS2 uses atlas texture)
    float atlasOffset = volumeIndex * atlasSliceWidth;
    lutCoord.x = (atlasOffset + lutCoord.x * 32.0) * (1.0 / atlasTextureWidth);
                
    // Sample color LUT
    float4 colorSample = colorLUT3D.SampleLevel(colorLUT3DSampler, lutCoord, 0);
                
    // Convert to HSV for manipulation
    float3 hsv = RGBtoHSV(colorSample.rgb);
                
    // Adjust saturation based on density
    hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
                
    // Convert back to RGB
    float3 color = HSVtoRGB(hsv);
                
    // Normalize and boost
    color = normalize(color + 0.001) * min(length(color), 4.0);
                
    return color * colorBoost;
}

///
/// @brief Ray–AABB intersection test using the slab method.
///
/// @param aabbMin  The minimum corner of the AABB (x_min, y_min, z_min).
/// @param aabbMax  The maximum corner of the AABB (x_max, y_max, z_max).
///
/// @param rayOrigin  Origin point of the ray.
/// @param rayDir     Direction of the ray (does not need to be normalized).
///
/// @param tMin  Output: the parametric distance at which the ray first enters the AABB.
///              Interpretation:
///                - tMin >= 0  &&  tMax >= 0 : ray origin is outside the box, 
///                                            and the ray hits the front face at tMin.
///                - tMin < 0   &&  tMax >= 0 : ray origin is inside the box; 
///                                            the effective entry is t = 0.
///              tMin can be negative if the origin starts inside the AABB.
///
/// @param tMax  Output: the parametric distance at which the ray exits the AABB.
///              Interpretation:
///                - tMax >= 0 : intersection occurs in front of the ray origin.
///                - tMax < 0  : the entire intersection interval lies behind the origin 
///                              → no valid hit.
///
/// @return true if the ray intersects the AABB in the forward direction (t >= 0),
///         false otherwise.
///
/// @note Valid intersection conditions:
///       - AABB is hit if: tMin <= tMax AND tMax >= 0
///       - Effective intersection interval is: [max(tMin, 0), tMax]
///
bool AABBIntersect(
    float3 aabbMin,
    float3 aabbMax,
    float3 rayOrigin,
    float3 rayDir,
    out float tMin,
    out float tMax
)
{
    float3 invDir = 1.0 / rayDir;

    float3 t0 = (aabbMin - rayOrigin) * invDir;
    float3 t1 = (aabbMax - rayOrigin) * invDir;

    float3 tNear = min(t0, t1);
    float3 tFar  = max(t0, t1);

    tMin = max(max(tNear.x, tNear.y), tNear.z);
    tMax = min(min(tFar.x,  tFar.y),  tFar.z);

    return tMax >= max(tMin, 0.0);
}

float3 CalculateAtlasUVW(
    float3 localUVW, 
    int volumeIndex, 
    float voxelResolution, 
    float atlasSliceWidth, 
    float atlasTextureWidthInv)
{
    // x,z,y as the data is dumped from CS2
    float3 swizzledUVW = float3(localUVW.x, localUVW.z, localUVW.y); 
    
    // calculate U
    float atlasU = (atlasSliceWidth * float(volumeIndex) + (swizzledUVW.x * voxelResolution)) * atlasTextureWidthInv;
    
    return float3(atlasU, swizzledUVW.y, swizzledUVW.z);
}

float4 SampleSmokeAtUVW(
    Texture3D smokeTex,
    SamplerState smokeSampler,
    float3 uvw,
    int volumeIndex, 
    float voxelResolution,
    float atlasSliceWidth,
    float atlasTextureWidthInv
)
{
    // Check bounds
    if (any(uvw < 0.0) || any(uvw > 1.0))
        return 0.0;

    //  Calculate UVW
    float3 sampleUVW = CalculateAtlasUVW(
        uvw, 
        volumeIndex, 
        voxelResolution, 
        atlasSliceWidth, 
        atlasTextureWidthInv
    );
    
    // Sample
    return smokeTex.SampleLevel(smokeSampler, sampleUVW, 0);
}

float4 SampleSmokeDensity(
    Texture3D smokeTex,
    SamplerState smokeSampler,
    float3 worldPos,
    float3 volumeCenter,
    int volumeIndex,
    float volumeSize,
    float voxelResolution,
    float atlasTextureWidth,
    float atlasSliceWidth
)
{
    float halfVolumeSize = volumeSize * 0.5;
    
    float3 localPos = (worldPos - volumeCenter) + halfVolumeSize;
    
    float3 uvw = localPos / volumeSize;
    
    return SampleSmokeAtUVW(
        smokeTex, 
        smokeSampler, 
        uvw, 
        volumeIndex, 
        voxelResolution, 
        atlasSliceWidth, 
        1.0 / atlasTextureWidth
    );
}


bool TraverseVoxels(
    Texture3D smokeTex,
    SamplerState smokeSampler,
    float3 startPos,
    float3 rayDir,
    float maxDist,
    float3 volumeCenter,
    int volumeIndex,
    float volumeSize,
    float voxelResolution,
    float atlasTextureWidth,
    float atlasSliceWidth,
    uint maxDDASteps
)
{
    float halfVolumeSize = volumeSize * 0.5;
    float voxelSize = volumeSize / voxelResolution;
    float worldToVoxel = 1.0 / voxelSize;
    float voxelToNormalized = 1.0 / voxelResolution;
    float maxVoxelIndex = voxelResolution - 1.0;
    float atlasWidthInv = 1.0 / atlasTextureWidth;
    
    float3 localPos = (startPos - volumeCenter) + halfVolumeSize;
    float3 voxelPos = localPos * worldToVoxel;
    voxelPos = clamp(voxelPos, 0.0, maxVoxelIndex);
    
    int3 currentVoxel = int3(floor(voxelPos));
    int3 voxelStep = int3(sign(rayDir));
    float3 rayStepSize = abs(length(rayDir) / (rayDir + 1e-5));
    float3 stepDir = float3(voxelStep);
    float3 tDelta = ((stepDir * (float3(currentVoxel) - voxelPos)) + (stepDir * 0.5) + 0.5) * rayStepSize;
    
    [loop]
    for (uint i = 0; i < maxDDASteps; i++)
    {

        float3 uvw = float3(currentVoxel) * voxelToNormalized;
        
        float4 smokeData = SampleSmokeAtUVW(
            smokeTex, 
            smokeSampler, 
            uvw, 
            volumeIndex, 
            voxelResolution, 
            atlasSliceWidth, 
            atlasWidthInv
        );
        
        if (any(smokeData.xyzw > 0.0))
        {
            return true;
        }

        float distTraveled = length((float3(currentVoxel) * voxelSize) - localPos);
        if (distTraveled > maxDist) break;

        float3 mask = step(tDelta.xyz, min(tDelta.yzx, tDelta.zxy));
        tDelta += mask * rayStepSize;
        currentVoxel += int3(mask) * voxelStep;
    }
    
    return false;
}

#endif