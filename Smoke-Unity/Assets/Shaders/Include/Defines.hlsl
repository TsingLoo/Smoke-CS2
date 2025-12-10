#ifndef DEFINES_INCLUDED
#define DEFINES_INCLUDED

#define HOLE_NOISE_SCALE 4.0
#define HOLE_NOISE_STRENGTH 1.2
#define HOLE_NOISE_SCROLL 0.5

static const float VOXEL_RESOLUTION = 32.0;
static const float MAX_SMOKE_COUNT = 16.0;
static const float ATLAS_DEPTH = VOXEL_RESOLUTION * MAX_SMOKE_COUNT;
static const float ATLAS_DEPTH_INV = 1.0f / ATLAS_DEPTH;

struct BulletHoleData
{
    float4 startPosAndIntensity;
    float4 endPosAndRadius;
};

struct SmokeVolume
{
    float3 position;
    int volumeIndex;
    float3 aabbMin;
    float padding1;
    float3 aabbMax;
    float padding2;
    float3 tint;
    float intensity;
};

struct ActiveSmoke
{
    float tMin;
    float tMax;
    int index;
};

#endif