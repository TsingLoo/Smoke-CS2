#ifndef DEFINES_INCLUDED
#define DEFINES_INCLUDED

#define HOLE_NOISE_SCALE 4.0
#define HOLE_NOISE_STRENGTH 1.2
#define HOLE_NOISE_SCROLL 0.5

#define VOLUME_TILE_SIZE 32.0

static const float VOXEL_RESOLUTION = VOLUME_TILE_SIZE;
static const float VOXEL_RESOLUTION_INV = 1.0 / VOXEL_RESOLUTION;
static const float VOXEL_WORLD_SIZE = 12.0;
static const float VOXEL_WORLD_SIZE_INV = 1.0 / VOXEL_WORLD_SIZE;
static const float MAX_SMOKE_COUNT = 16.0;
static const float ATLAS_DEPTH = VOXEL_RESOLUTION * MAX_SMOKE_COUNT;
static const float ATLAS_DEPTH_INV = 1.0f / ATLAS_DEPTH;

// --- Array/Loop Limits ---
#define MAX_TRACER_COUNT            16u
#define MAX_EXPLOSION_COUNT         5u
#define MAX_ACTIVE_VOLUMES          1u
#define MAX_MARCH_STEPS             500.0
#define MOMENT_LOOP_COUNT           4

// --- Volume Sampling ---
#define VOLUME_LOCAL_SCALE          0.05
#define VOLUME_CENTER_OFFSET        16.0                // offset to center volume
#define DENSITY_ATLAS_U_SCALE       0.0018450184725224971771240234375  // 1/542
//34.0 in CS2
#define DENSITY_PAGE_STRIDE         32.0                // U offset per density page

// --- Ray Marching ---
#define RAY_NEAR_CLIP_OFFSET        0.1                 // minimum ray start distance
#define SCENE_DEPTH_OFFSET          0.01                 // offset from scene depth
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
#define GOLDEN_RATIO_FRACT          0.61803400516510009765625  // ? - 1, for jitter

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