#ifndef DEFINES_INCLUDED
#define DEFINES_INCLUDED

static const float VOXEL_RESOLUTION = 32.0;
static const float MAX_SMOKE_COUNT = 16.0;
static const float ATLAS_DEPTH = VOXEL_RESOLUTION * MAX_SMOKE_COUNT;

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