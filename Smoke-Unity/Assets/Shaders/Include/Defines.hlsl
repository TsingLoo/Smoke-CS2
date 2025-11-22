#ifndef DEFINES_INCLUDED
#define DEFINES_INCLUDED
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