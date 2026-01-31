#ifndef UTILS_INCLUDED
#define UTILS_INCLUDED

#include  "./Defines.hlsl"

float Random(float3 p) 
{
    return frac(sin(dot(p, float3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float Noise3D(float3 p) 
{
    float3 i = floor(p);
    float3 f = frac(p);
    f = f * f * (3.0 - 2.0 * f); // Hermite 插值，让边缘更圆滑
    
    return lerp(
        lerp(lerp(Random(i + float3(0,0,0)), Random(i + float3(1,0,0)), f.x),
             lerp(Random(i + float3(0,1,0)), Random(i + float3(1,1,0)), f.x), f.y),
        lerp(lerp(Random(i + float3(0,0,1)), Random(i + float3(1,0,1)), f.x),
             lerp(Random(i + float3(0,1,1)), Random(i + float3(1,1,1)), f.x), f.y), f.z);
}

float Fbm3D(float3 p) 
{
    float v = 0.0;
    float a = 0.5;
    float3 shift = float3(100.0, 100.0, 100.0);
    for (int i = 0; i < 2; ++i) {
        v += a * Noise3D(p);
        p = p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float2 Rotate2D(float2 v, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float2(v.x * c - v.y * s, v.x * s + v.y * c);
}

float hash(float n) { return frac(sin(n) * 43758.5453123); }

// 1D noise
float noise1(float x)
{
    float i = floor(x);
    float f = frac(x);
    float u = f * f * (3.0 - 2.0 * f);
    return lerp(hash(i), hash(i + 1.0), u);
}

float3 ApplyCloudDistortion(float3 uvw, float time)
{
    float3 p = (uvw - 0.5) * 7.0;

    // --- 主方向：始终往下（不反向） ---
    float downSpeed = 0.2;
    p.y -= time * downSpeed;

    // --- 非周期扰动：使用 noise 而不是 sin ---
    float n1 = noise1(p.x * 1.3 + time * 0.4);
    float n2 = noise1(p.z * 1.7 + time * 0.5);
    float n3 = noise1(p.y * 1.1 + time * 0.3);

    // 小扰动（永远不会“反向”主运动，只会左右小幅变化）
    p.x += (n1 - 0.5) * 0.25;
    p.z += (n2 - 0.5) * 0.25;
    p.y += (n3 - 0.5) * 0.08;   // y 的扰动保持很小，避免反向

    return p;
}

/// 
/// @param cosTheta 
/// @param g if g>0, forward scattering, light will more likely travel through the original direction
/// @return 
float PhaseHG(float cosTheta, float g)
{
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
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

// float3 SampleColorLUT(Texture3D colorLUT3D, SamplerState colorLUT3DSampler, float atlasTextureWidth, float atlasSliceWidth, float saturation, float colorBoost, float3 normalizedPos, float density, uint volumeIndex)
// {
//     // Clamp position to valid range
//     float3 lutCoord = clamp(normalizedPos, 0.03, 0.97);
//                 
//     // Add volume index offset (CS2 uses atlas texture)
//     float atlasOffset = volumeIndex * atlasSliceWidth;
//     lutCoord.x = (atlasOffset + lutCoord.x * 32.0) * (1.0 / atlasTextureWidth);
//                 
//     // Sample color LUT
//     float4 colorSample = colorLUT3D.SampleLevel(colorLUT3DSampler, lutCoord, 0);
//                 
//     // Convert to HSV for manipulation
//     float3 hsv = RGBtoHSV(colorSample.rgb);
//                 
//     // Adjust saturation based on density
//     hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
//                 
//     // Convert back to RGB
//     float3 color = HSVtoRGB(hsv);
//                 
//     // Normalize and boost
//     color = normalize(color + 0.001) * min(length(color), 4.0);
//                 
//     return color * colorBoost;
// }

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
    float atlasDepth, 
    float atlasDepthInv)
{
    // x,z,y as the data is dumped from CS2
    //float3 swizzledUVW = float3(localUVW.x, localUVW.y, localUVW.z);
    float zOffset = float(volumeIndex) * voxelResolution;  // 0, 32, 64, ..., 480

    return float3(
    localUVW.x,
    localUVW.y,
    (localUVW.z * voxelResolution + zOffset) * atlasDepthInv);
    
    // calculate U
    //float atlasU = (atlasSliceWidth * float(volumeIndex) + (swizzledUVW.x * voxelResolution)) * atlasTextureWidthInv;
    
    //return float3(atlasU, swizzledUVW.y, swizzledUVW.z);
}

float2 rayBoxIntersection(float3 invRayDir, float3 rayOrigin, float3 boxMin, float3 boxMax)
{
    float3 tToMin = invRayDir * (boxMin - rayOrigin);
    float3 tToMax = invRayDir * (boxMax - rayOrigin);
    float3 tMinPerAxis = min(tToMax, tToMin);
    float3 tMaxPerAxis = max(tToMax, tToMin);
    float2 tMinComp = max(tMinPerAxis.xx, tMinPerAxis.yz);
    float2 tMaxComp = min(tMaxPerAxis.xx, tMaxPerAxis.yz);
    return float2(max(tMinComp.x, tMinComp.y), min(tMaxComp.x, tMaxComp.y));
}


float4 SampleSmokeAtUVW(
    Texture3D smokeTex,
    SamplerState smokeSampler,
    float3 uvw,           // 传入的本地 [0, 1] 坐标
    int volumeIndex
)
{
    // 1. 边界检查
    if (any(uvw < 0.0) || any(uvw > 1.0))
        return 0.0;

    // 2. 修正计算逻辑
    // 将 localU 映射到 Atlas 里的像素位置，然后整体转为归一化坐标
    float pixelX = (float)volumeIndex * DENSITY_PAGE_STRIDE + (uvw.x * SINGLE_VOLUME_TILE_SIZE);
    
    // 关键修正：将结果存入新的变量，不要污染传入的 uvw.yz
    float3 atlasUVW = uvw;
    atlasUVW.x = pixelX;
    
    // 3. 采样 (使用 SampleLevel 避免导数计算问题)
    return smokeTex.SampleLevel(smokeSampler, atlasUVW, 0);
}

/// 
/// @param smokeTex the smoke atlas texture
/// @param smokeSampler sampler
/// @param worldPos the input world space
/// @param volumeCenter the center of the volume in the world space
/// @param volumeIndex the index of the smoke metadata
/// @param volumeSize the volumeSize in the unit of world space, the size of the entire AABB box in the world
/// @param voxelResolution VOXEL_RESOLUTION
/// @param atlasTextureWidth ATLAS_DEPTH
/// @param atlasSliceWidth VOXEL_RESOLUTION
/// @param uvw the 3D sample coordination in the volume space
/// @return get the density of the given worldPos
float4 SampleSmokeDensity(
    Texture3D smokeTex,
    SamplerState smokeSampler,
    float3 worldPos,
    float3 volumeCenter,
    int volumeIndex,
    float volumeSize,
    float voxelResolution,
    float atlasTextureWidth,
    float atlasSliceWidth,
    out float3 uvw
)
{
    
    float halfVolumeSize = volumeSize * 0.5;
    
    float3 localPos = (worldPos - volumeCenter) + halfVolumeSize;
    
    uvw = saturate(localPos / volumeSize); 
    
    return SampleSmokeAtUVW(
        smokeTex, 
        smokeSampler, 
        uvw, 
        volumeIndex
    );
}

/// 
/// @return the noised density at the given position in world space 
float GetSmokeDensity(
    float3 samplePos, 
    SmokeVolume smoke, 
    Texture3D smokeTex, SamplerState samplerSmoke,
    Texture3D noiseTex, SamplerState samplerNoise,
    float volumeSize, float time,
    float detailNoiseSpeed, float detailNoiseUVWScale, float detailNoiseStrength, float densityMultiplier, float interpolationT)
{
    float3 rawUVW;
    // 1. 获取宏观体素密度 (骨架)
    float4 smokeData = SampleSmokeDensity(
        smokeTex, samplerSmoke,
        samplePos, smoke.position, smoke.volumeIndex,
        volumeSize, VOLUME_RESOLUTION, DENSITY_ATLAS_WIDTH, VOLUME_RESOLUTION, rawUVW
    );

    float baseDensity = lerp( smokeData.x, smokeData.y, interpolationT);
    //float baseDensity = smokeData.y;
    //float  baseDensity = 0.0;

    if (baseDensity <= 0.001) return 0.0;

    // 2. 坐标扭曲 (Distortion) - 模拟流体翻滚 [关键改进]
    // 使用宏观密度和时间来驱动扭曲，让核心动得慢，边缘动得快
    float3 curlFreq = samplePos * 2.0; 
    float3 distortion = float3(
        sin(curlFreq.y + time * detailNoiseSpeed),
        sin(curlFreq.z + time * detailNoiseSpeed * 1.3),
        sin(curlFreq.x + time * detailNoiseSpeed * 0.7)
    ) * 0.01; // 0.1 是扭曲强度，可调

    // 3. 计算细节纹理坐标
    float3 detailUVW = rawUVW * detailNoiseUVWScale + distortion;
    
    // 4. 采样细节噪声 (皮肉)
    // 加上 abs() 做镜像，减少重复感 [小技巧]
    // 加上 time 做一点整体向上的漂移
    float3 sampleCoords = abs(detailUVW + float3(0, time * 0.1, 0)); 
    float4 noiseVal = noiseTex.SampleLevel(samplerNoise, sampleCoords, 0);

    // 5. 多通道混合 (FBM-like) [改进]
    // R通道作为基础形状，G通道作为高频细节
    float detailShape = noiseVal.r;
    float detailFine  = noiseVal.g;
    float combinedNoise = detailShape * 0.7 + detailFine * 0.3;

    // 6. 边缘侵蚀与核心保护 (Erosion & Preservation) [核心算法改进]
    // 这种写法模仿了参考代码的 mix 逻辑
    // 当 baseDensity 小时 (边缘)，result = base - noise (被吃掉)
    // 当 baseDensity 大时 (核心)，result = base (保持厚重)
    // 甚至可以写成 lerp(base - noise, base + noise, base) 让核心更厚
    float erosionAmount = combinedNoise * detailNoiseStrength;
    
    float finalDensity = lerp(
        baseDensity - erosionAmount, // 边缘：做减法，产生絮状物
        baseDensity,                 // 核心：保持原样 (或者 baseDensity + erosionAmount * 0.5)
        saturate(baseDensity * 2.0)  // 权重：快速过渡到保护模式
    );

    // 7. 最后的修剪与增强
    // 把被减成负数的部分切掉，并乘上强度
    return saturate(finalDensity * densityMultiplier * smoke.intensity);
}

float GetSmokeDensityWithGradient(
    float gradientOffset,
    float3 worldPos, 
    SmokeVolume smoke,
    Texture3D smokeTex, 
    SamplerState smokeSampler,
    Texture3D noiseTex, 
    SamplerState noiseSampler,
    float volumeSize, 
    float time,
    float noiseSpeed, 
    float noiseScale, 
    float noiseStrength, 
    float densityMult,
    float interpolationT,
    out float3 baseUVW,
    out float3 densityGradient
)
{
    float finalDensity = GetSmokeDensity(
        worldPos, smoke, 
        smokeTex, smokeSampler,
        noiseTex, noiseSampler,
        volumeSize, time,
        noiseSpeed, noiseScale, noiseStrength, densityMult, interpolationT
    );

    float3 localPos = worldPos - smoke.position;
    baseUVW = (localPos / volumeSize) + 0.5;

    float3 uvwX = baseUVW + float3(gradientOffset, 0, 0);
    float3 uvwY = baseUVW + float3(0, gradientOffset, 0);
    float3 uvwZ = baseUVW + float3(0, 0, gradientOffset);
    
    float densityX = GetSmokeDensity(
        smoke.position + (uvwX - 0.5) * volumeSize, smoke,
        smokeTex, smokeSampler,
        noiseTex, noiseSampler,
        volumeSize, time,
        noiseSpeed, noiseScale, noiseStrength, densityMult, interpolationT
    );

    float densityY = GetSmokeDensity(
        smoke.position + (uvwY - 0.5) * volumeSize, smoke,
        smokeTex, smokeSampler,
        noiseTex, noiseSampler,
        volumeSize, time,
        noiseSpeed, noiseScale, noiseStrength, densityMult, interpolationT
    );

    // float densityZ = GetSmokeDensity(
    //     smoke.position + (uvwZ - 0.5) * volumeSize, smoke,
    //     smokeTex, smokeSampler,
    //     noiseTex, noiseSampler,
    //     volumeSize, time,
    //     noiseSpeed, noiseScale, noiseStrength, densityMult, interpolationT
    // );


    float strength = 1.0;
    densityGradient = normalize(float3(
        (finalDensity - densityX) * strength,
        (finalDensity - densityY)* strength,
        0.8
    ));

    //densityGradient = float3(0,0,0);
    
    return finalDensity;
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
    
    float3 localPos = (startPos - volumeCenter) + halfVolumeSize;
    float3 voxelPos = localPos * worldToVoxel;
    voxelPos = clamp(voxelPos, 0.0, maxVoxelIndex);
    
    int3 currentVoxel = int3(floor(voxelPos));
    int3 voxelStep = int3(sign(rayDir));
    
    // 每个轴方向上走一个体素需要的 t 距离
    float3 tDeltaUnit = abs(voxelSize / (rayDir + 1e-7));
    
    // 计算到达下一个体素边界的初始 t 值
    float3 nextBoundary = float3(currentVoxel) + saturate(float3(voxelStep)); // 下一个边界的体素坐标
    float3 tMax = (nextBoundary * voxelSize - localPos) / (rayDir + 1e-7);
    
    // 修正负方向的情况
    tMax = abs(tMax);
    
    [loop]
    for (uint i = 0; i < maxDDASteps; i++)
    {
        // 边界检查
        if (any(currentVoxel < 0) || any(currentVoxel >= (int)voxelResolution))
        {
            break;
        }

        // 计算 Atlas 采样坐标
        float atlasU = (volumeIndex * DENSITY_PAGE_STRIDE + currentVoxel.x + 0.5) * DENSITY_ATLAS_WIDTH_INV;
        float atlasV = (currentVoxel.y + 0.5) / SINGLE_VOLUME_TILE_SIZE;
        float atlasW = (currentVoxel.z + 0.5) / SINGLE_VOLUME_TILE_SIZE;
        
        float4 smokeData = smokeTex.SampleLevel(smokeSampler, float3(atlasU, atlasV, atlasW), 0);

        if (smokeData.x > 0.0)
        {
            return true;
        }

        // 距离检查
        float distTraveled = length((float3(currentVoxel) + 0.5) * voxelSize - localPos);
        if (distTraveled > maxDist) 
            break;

        // DDA 步进：只允许一个轴前进，避免对角线跳跃
        if (tMax.x < tMax.y)
        {
            if (tMax.x < tMax.z)
            {
                currentVoxel.x += voxelStep.x;
                tMax.x += tDeltaUnit.x;
            }
            else
            {
                currentVoxel.z += voxelStep.z;
                tMax.z += tDeltaUnit.z;
            }
        }
        else
        {
            if (tMax.y < tMax.z)
            {
                currentVoxel.y += voxelStep.y;
                tMax.y += tDeltaUnit.y;
            }
            else
            {
                currentVoxel.z += voxelStep.z;
                tMax.z += tDeltaUnit.z;
            }
        }
    }
    
    return false;
}


bool TraverseVoxelsWithNoise(
    Texture3D smokeTex,
    SamplerState smokeSampler,
    Texture3D noiseTex,
    SamplerState noiseSampler,
    float3 startPos,
    float3 rayDir,
    float maxDist,
    float3 volumeCenter,
    int volumeIndex,
    float volumeSize,
    float voxelResolution,
    uint maxDDASteps,
    float time,
    float noiseSpeed,
    float noiseScale,
    float noiseStrength,
    float densityThreshold
)
{
    float halfVolumeSize = volumeSize * 0.5;
    float voxelSize = volumeSize / voxelResolution;
    float worldToVoxel = 1.0 / voxelSize;
    float voxelToNormalized = 1.0 / voxelResolution;
    float maxVoxelIndex = voxelResolution - 1.0;
    
    // 1. 计算本地 Voxel 坐标
    float3 localPos = (startPos - volumeCenter) + halfVolumeSize;
    float3 voxelPos = localPos * worldToVoxel;
    voxelPos = clamp(voxelPos, 0.0, maxVoxelIndex);
    
    int3 currentVoxel = int3(floor(voxelPos));
    int3 voxelStep = int3(sign(rayDir));
    float3 rayStepSize = abs(1.0 / (rayDir + 1e-5)); // 步进斜率
    
    float3 stepDir = float3(voxelStep);
    float3 tDelta = ((stepDir * (float3(currentVoxel) - voxelPos)) + (stepDir * 0.5) + 0.5) * rayStepSize;
    
    [loop]
    for (uint i = 0; i < maxDDASteps; i++)
    {
        // --- 核心修改：计算 X 轴堆叠的全局 UVW ---
        // currentVoxel 是 0-31 的本地整数坐标
        
        // 计算全局像素坐标 X (包含 Stride)
        float globalPixelX = (float)volumeIndex * (voxelResolution + 2.0) + (float)currentVoxel.x;
        
        // 映射到全局 UVW [0, 1]
        // 使用 +0.5 偏移以确保采样在像素中心，防止浮点数误差导致的边缘渗漏
        float3 atlasUVW;
        atlasUVW.x = (globalPixelX + 0.5) / DENSITY_ATLAS_WIDTH; 
        atlasUVW.y = ((float)currentVoxel.y + 0.5) / voxelResolution;
        atlasUVW.z = ((float)currentVoxel.z + 0.5) / voxelResolution;

        // 采样 Texture3D
        float4 smokeData = smokeTex.SampleLevel(smokeSampler, atlasUVW, 0);

        // 注意：根据你之前的 C# 脚本，R/G 通道存的是 All Density，B/A 存的是 Smoke
        // 如果你做了插值混合，这里应该是：lerp(smokeData.r, smokeData.g, _SmokeInterpolationT)
        float baseDensity = smokeData.r; // 这里示例取 Target All (G通道)
        
        if (baseDensity > 0.01)
        {
            // 噪声计算（使用 local uvw，保证噪声随烟雾移动）
            float3 localUVW = (float3)currentVoxel * voxelToNormalized;
            float animTime = time * noiseSpeed;
            float3 noiseUVW = localUVW * noiseScale;
            float4 noiseData = noiseTex.SampleLevel(noiseSampler, noiseUVW + animTime, 0);
            float noiseValue = noiseData.r * 0.8 + noiseData.b * 0.2;
            
            float adjustedDensity = baseDensity - (noiseValue * noiseStrength) * (1.0 - baseDensity);
            
            if (adjustedDensity > densityThreshold)
            {
                return true;
            }
        }

        // DDA 步进逻辑
        float3 mask = step(tDelta.xyz, min(tDelta.yzx, tDelta.zxy));
        tDelta += mask * rayStepSize;
        currentVoxel += int3(mask) * voxelStep;

        // 边界检查
        if (any(currentVoxel < 0) || any(currentVoxel >= (int)voxelResolution)) break;
        
        float distTraveled = length(((float3(currentVoxel) + 0.5) * voxelSize) - localPos);
        if (distTraveled > maxDist) break;
    }
    
    return false;
}

float GetBulletPenetration(float3 currentPos, StructuredBuffer<BulletHoleData> bulletHoleBuffer, int bulletHoleCount)
{
    float densityMult = 1.0;

    float noiseVal = Fbm3D(currentPos * HOLE_NOISE_SCALE + float3(0, _Time.y * 0.2, 0));
    float disturbance = (noiseVal - 0.5) * 2.0;
    
    int count = min(bulletHoleCount, 32); 
    
    for(int i = 0; i < count; i++)
    {
        BulletHoleData hole = bulletHoleBuffer[i];
        
        float intensity = hole.startPosAndIntensity.w;
        if (intensity < 0.001) continue;

        float3 posA = hole.startPosAndIntensity.xyz;
        float3 posB = hole.endPosAndRadius.xyz;
        float radius = hole.endPosAndRadius.w;

        float noisyRadius = radius * (1.0 + disturbance * HOLE_NOISE_STRENGTH);
        noisyRadius = max(0.01, noisyRadius);
        
        float3 pa = currentPos - posA;
        float3 ba = posB - posA;
        
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        
        float3 vecToLine = pa - ba * h;
        float distSqr = dot(vecToLine, vecToLine);
        
        float radiusSqr = noisyRadius * noisyRadius;
        
        float holeFactor = 1.0 - smoothstep(0.0, radiusSqr, distSqr);
        
        float finalMask = 1.0 - (holeFactor * intensity);
        
        densityMult = min(densityMult, finalMask);
    }
    
    return densityMult;
}

// CS2风格的噪声采样函数
float4 SampleNoiseCS2(
    Texture3D noiseTex, 
    SamplerState noiseSampler,
    float3 coord,
    float3 timeOffset,
    float gamma,
    float colorA,
    float colorB,
    float blendFactor
)
{
    // 1. abs() 镜像 + 时间滚动
    float3 sampleCoord = (abs(coord) - timeOffset) * 0.07;
    
    // 2. 采样并做gamma校正
    float4 noise = pow(noiseTex.SampleLevel(noiseSampler, sampleCoord, 0), gamma);
    
    // 3. CS2的颜色混合方式
    float4 colorMixA = lerp(colorA, colorB, noise);
    float4 colorMixB = lerp(0.25, -1.5, noise);
    float4 result = lerp(colorMixA, colorMixB, blendFactor);
    
    return result;
}

// 从噪声计算密度值
float ExtractDensity(float4 noiseSample)
{
    return (noiseSample.x + noiseSample.y * 0.95) * 4.6;
}


/// 
/// @return the origin is a corner
float3 GetVolumeLocalUVW(float3 worldPos, float3 volumeCenter, out float3 localUVW)
{
    localUVW = clamp(((worldPos - volumeCenter) * VOLUME_WORLD_SIZE_INV) + 0.5, 0.0, 1.0);
    return localUVW;
}

#endif