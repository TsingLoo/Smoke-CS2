#ifndef UTILS_INCLUDED
#define UTILS_INCLUDED

#include  "./Defines.hlsl"

bool AABBIntersect(
    float3 aabbMin,
    float3 aabbMax,
    float3 rayOrigin,
    float3 rayDir,
    out float tMin,
    out float tMax
)
{
    // compute the invDirection
    float3 invDir = 1.0 / (rayDir + 0.0001);
    
    // compute the intersection point of the six faces
    float3 t0 = (aabbMin - rayOrigin) * invDir;
    float3 t1 = (aabbMax - rayOrigin) * invDir;
    
    // find the most close and far one
    float3 tNear = min(t0, t1);
    float3 tFar = max(t0, t1);
    
    // calculate in-out distance
    tMin = max(max(tNear.x, tNear.y), tNear.z);
    tMax = min(min(tFar.x, tFar.y), tFar.z);
    
    // check if intersect
    if (tMin > tMax) return false;
    if (tMax < 0.0) return false;
    
    return true;
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

float4 SampleSmokeDensity(
    Texture3D smokeTex,
    SamplerState smokeSampler,
    float3 worldPos,
    SmokeVolume smoke,
    float volumeSize,
    float atlasTextureWidth,
    float atlasSliceWidth,
    float voxelResolution
)
{
    float3 localPos = (worldPos - smoke.position) + (volumeSize * 0.5);
    
    float3 uvw = localPos / volumeSize;
    
    if (any(uvw < 0.0) || any(uvw > 1.0))
        return 0.0;
    
    float3 sampleUVW = CalculateAtlasUVW(
        uvw, 
        smoke.volumeIndex, 
        voxelResolution, 
        atlasSliceWidth, 
        1.0 / atlasTextureWidth
    );
    
    return smokeTex.SampleLevel(smokeSampler, sampleUVW, 0);
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
    
    // DDA Init
    int3 currentVoxel = int3(floor(voxelPos));
    int3 voxelStep = int3(sign(rayDir));
    
    float3 rayStepSize = abs(length(rayDir) / rayDir);
    
    float3 stepDir = float3(voxelStep);
    float3 tDelta = ((stepDir * (float3(currentVoxel) - voxelPos)) + (stepDir * 0.5) + 0.5) * rayStepSize;
    
    [loop]
    for (uint i = 0; i < maxDDASteps; i++)
    {
        // Voxel Index -> Normalized UVW (0 to 1)
        float3 uvw = (float3(currentVoxel)) * voxelToNormalized;

        // Bounds check
        if (any(uvw < 0.0) || any(uvw > 1.0))
            break; 

        // calculate sample UVW
        float3 sampleUVW = CalculateAtlasUVW(
            uvw, 
            volumeIndex, 
            voxelResolution, 
            atlasSliceWidth, 
            atlasWidthInv
        );
        
        float4 smokeData = smokeTex.SampleLevel(smokeSampler, sampleUVW, 0);
        
        if (any(smokeData.xyzw > 0.0))
        {
            return true;
        }
        
        float distTraveled = length((float3(currentVoxel) * voxelSize) - localPos);
        if (distTraveled > maxDist) break;
        
        float3 mask = float3(
             (tDelta.x <= tDelta.y && tDelta.x <= tDelta.z) ? 1.0 : 0.0,
             (tDelta.y <= tDelta.x && tDelta.y <= tDelta.z) ? 1.0 : 0.0,
             (tDelta.z <= tDelta.x && tDelta.z <= tDelta.y) ? 1.0 : 0.0
        );
        
        tDelta += mask * rayStepSize;
        currentVoxel += int3(mask) * voxelStep;
    }
    
    return false;
}

#endif