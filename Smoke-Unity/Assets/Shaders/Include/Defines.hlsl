#ifndef DEFINES_INCLUDED
#define DEFINES_INCLUDED

#define HOLE_NOISE_SCALE 4.0
#define HOLE_NOISE_STRENGTH 1.2
#define HOLE_NOISE_SCROLL 0.5

static const float VOXEL_RESOLUTION = 32.0;
static const float VOXEL_RESOLUTION_INV = 1.0 / VOXEL_RESOLUTION;
static const float VOXEL_WORLD_SIZE = 12.0;
static const float VOXEL_WORLD_SIZE_INV = 1.0 / VOXEL_WORLD_SIZE;
static const float MAX_SMOKE_COUNT = 16.0;
static const float ATLAS_DEPTH = VOXEL_RESOLUTION * MAX_SMOKE_COUNT;
static const float ATLAS_DEPTH_INV = 1.0f / ATLAS_DEPTH;

struct Matrix4x4 {
    float4 rows[4];
};

struct Matrix16x4 {
    float4 rows[16];
};

struct Array5x4 {
    float4 data[5];
};

struct Array2x4 {
    float4 data[2];
};

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

struct VolumeBoxData
{
    float tMin;
    float tMax;
    int index;
};

#endif