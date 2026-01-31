#ifndef DEFINES_INCLUDED
#define DEFINES_INCLUDED

// ============================================================================
// WORLD SCALE CONFIGURATION
// ============================================================================
// Original CS2 volume: 640 units
// Your volume: 12 units
// Scale factor: 12 / 640 = 0.01875

#define DEBUG_PINK_COLOR float4(1.0f, 0.0f, 1.0f, 1.0f)


// ============================================================================
// VOLUME CONFIGURATION
// ============================================================================

#define HOLE_NOISE_SCALE            4.0
#define HOLE_NOISE_STRENGTH         1.2
#define HOLE_NOISE_SCROLL           0.5


#define VOLUME_CENTER_OFFSET        16.0                // offset to center volume
#define VOLUME_UVW_SCALE            0.03125             // 1/32 - local to UVW
#define SINGLE_VOLUME_TILE_SIZE     32.0                // texture tile dimension
//#define DENSITY_ATLAS_WIDE_INV      0.0018450184725224971771240234375  // 1/542
#define DENSITY_PAGE_STRIDE         34.0                // U offset per density page

static const float VOLUME_WORLD_SIZE = 14.0;
static const float CS2_VOLUME_WORLD_SIZE = 640.0;

static const float VOLUME_RESOLUTION = SINGLE_VOLUME_TILE_SIZE;
static const float VOLUME_RESOLUTION_INV = 1.0 / VOLUME_RESOLUTION;
static const float WORLD_POS_TO_VOXEL_COORD = VOLUME_RESOLUTION / VOLUME_WORLD_SIZE;

static const float VOLUME_WORLD_SIZE_INV = 1.0 / VOLUME_WORLD_SIZE;
static const int MAX_SMOKE_COUNT = 16;

static const float SINGLE_GRID_WIDTH = VOLUME_WORLD_SIZE / SINGLE_VOLUME_TILE_SIZE;
static const float VOLUME_LOCAL_SCALE = 1.0 / SINGLE_GRID_WIDTH;

static const float DENSITY_ATLAS_WIDTH = (SINGLE_VOLUME_TILE_SIZE * MAX_SMOKE_COUNT) + ((MAX_SMOKE_COUNT - 1) * 2);
static const float DENSITY_ATLAS_WIDTH_INV = 1.0 / DENSITY_ATLAS_WIDTH;

//14/640 0.021875
static const float RAW_CS2_DISTANCE_TO_UNITY = VOLUME_WORLD_SIZE / CS2_VOLUME_WORLD_SIZE;
static const float RAW_CS2_DISTANCE_TO_UNITY_INV = 1 / RAW_CS2_DISTANCE_TO_UNITY;

// ============================================================================
// ARRAY / LOOP LIMITS
// ============================================================================

#define MAX_TRACER_COUNT            16u
#define MAX_EXPLOSION_COUNT         5u
#define MAX_ACTIVE_VOLUMES          1u
#define MAX_MARCH_STEPS             500
#define MOMENT_LOOP_COUNT           4

// ============================================================================
// RAY MARCHING
// ============================================================================

#define RAY_NEAR_CLIP_OFFSET        4.0  *  RAW_CS2_DISTANCE_TO_UNITY                // minimum ray start distance
#define SCENE_DEPTH_OFFSET          2.0  *  RAW_CS2_DISTANCE_TO_UNITY                // offset from scene depth
#define OCCLUSION_DEPTH_THRESHOLD   10.0 *  RAW_CS2_DISTANCE_TO_UNITY                // (original 10.0 × 0.01875)
#define STEP_DISTANCE_MULTIPLIER    1.5                 // base step size modifier
#define STEP_COUNT_PADDING          10.0                // extra steps for safety

// ============================================================================
// NOISE SAMPLING (UV space - no change needed)
// ============================================================================

#define NOISE_TEXTURE_SCALE         0.07                // high-freq noise UV scale
#define NOISE_COORD_SCALE           7                   // volume to noise space
#define NOISE_CHANNEL_WEIGHT        0.95                // secondary channel weight
#define NOISE_COMBINE_MULTIPLIER    4.6                 // final noise amplitude
#define NORMAL_GRAD_STEP_BASE       0.8                 // base value for normal gradient

// ============================================================================
// TIME / ANIMATION (no change needed)
// ============================================================================

#define TIME_OFFSET_SCALE           0.1                 // global time offset multiplier
#define ROTATION_TIME_MULT          0.5                 // rotation animation speed
#define ROTATION_OFFSET_BASE        0.04                // base rotation offset
#define ROTATION_MOD_FREQ           0.187               // rotation modulation frequency
#define WAVE_FREQ_MULT              2.7               // wave perturbation frequency
#define WAVE_ANIM_FREQ_1            0.35                // wave animation speed 1
#define WAVE_ANIM_FREQ_2            0.235               // wave animation speed 2
#define DETAIL_TIME_MULT            0.25                // detail noise time multiplier
#define GOLDEN_RATIO_FRACT          0.618034            // φ - 1, for jitter

// ============================================================================
// ALPHA / DENSITY THRESHOLDS (ratios - no change needed)
// ============================================================================

#define OPAQUE_THRESHOLD            0.991               // ~0.991
#define MIN_DENSITY_THRESHOLD       0.01                // ~0.01
#define EPSILON                     0.0001              // ~0.0001
#define MAX_CLAMP_VALUE             0.9999              // ~0.9999
#define FIRST_PASS_WEIGHT           0.375          // sample weight for main pass
#define SECOND_PASS_WEIGHT          0.235         // sample weight for second pass

// ============================================================================
// DISTANCE THRESHOLDS (scaled for 12-unit volume)
// ============================================================================

#define NOISE_PERTURB_AMPLITUDE     0.05                
#define TRACER_OFFSET_SCALE         20.0 * RAW_CS2_DISTANCE_TO_UNITY
#define TRACER_GLOW_POWER           64.0                
#define TRACER_AGE_DIST_SCALE       23.4                
#define EXPLOSION_MAX_DIST          250.0              
#define DISSIP_FADE_NEAR            200.0 * RAW_CS2_DISTANCE_TO_UNITY
#define DISSIP_FADE_FAR             240.0 * RAW_CS2_DISTANCE_TO_UNITY
#define SURFACE_PROX_THRESHOLD      0.9                 
#define SURFACE_PROX_SCALE          1.111               
#define DENSITY_BLEND_NEAR          10 * RAW_CS2_DISTANCE_TO_UNITY
#define DENSITY_BLEND_FAR           40 * RAW_CS2_DISTANCE_TO_UNITY
#define CAMERA_DIST_SCALE           0.1                
#define DEPTH_FADE_DIST_SCALE       0.005 * RAW_CS2_DISTANCE_TO_UNITY_INV             

// ============================================================================
// LIGHTING / PHASE (ratios - no change needed)
// ============================================================================

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

// ============================================================================
// COLOR CONSTANTS (no change needed)
// ============================================================================

#define LUMA_R                      0.2125              // Rec.709 red
#define LUMA_G                      0.7154              // Rec.709 green
#define LUMA_B                      0.0721              // Rec.709 blue
#define COLOR_TINT_NORM             1.732               // sqrt(3) for normalization
#define SATURATION_BOOST            1.1                 // HSV saturation multiplier
#define COLOR_EPSILON               0.001               // epsilon for color normalization
#define MAX_COLOR_LENGTH            4.0                 // maximum color vector length
#define TRACER_GLOW_R               8.0                 // tracer glow red
#define TRACER_GLOW_G               4.0                 // tracer glow green
#define TRACER_GLOW_B               0.0                 // tracer glow blue

// ============================================================================
// BLEND / MIX FACTORS (ratios - no change needed)
// ============================================================================

#define HALF                        0.5
#define SHADOW_BLEND_FACTOR         0.6                 // shadow color blend
#define SHADOW_AMOUNT_SCALE         0.85                // shadow amount color multiplier
#define HEIGHT_FADE_DENSITY_MULT    2.4                 // height fade contrast
#define HEIGHT_TEST_Z_SCALE         1.2                 // height test position scale
#define NORMAL_DIST_SCALE           0.005 * RAW_CS2_DISTANCE_TO_UNITY_INV // (original 0.005 / 0.01875) - inverse scale
#define DISTORTION_AMPLITUDE        0.2                 // camera vector offsets for normals
#define EXPLOSION_PULSE_POWER       128.0               // explosion pulse sharpness

// ============================================================================
// DENSITY REMAPPING (ratios - no change needed)
// ============================================================================

#define DENSITY_REMAP_FACTOR        1.0101              // 1/(1-0.01)
#define DENSITY_FADE_MULT           8.0                 // density fade multiplier
#define FOG_DENSITY_MULT            6.0                 // fog amount multiplier
#define FOG_STEP_THRESHOLD          0.3                 // fog step offset

// ============================================================================
// JITTER / SAMPLING (scaled for 12-unit volume)
// ============================================================================

#define JITTER_SCALE                1.4

#define JITTER_MIN_BLEND            0.1                 // minimum jitter blend
#define JITTER_MAX_BLEND            0.8                 // maximum jitter blend
#define JITTER_DIST_OFFSET          150.0 * RAW_CS2_DISTANCE_TO_UNITY                 // (original 150.0 × 0.01875)
#define JITTER_DIST_SCALE           WORLD_POS_TO_VOXEL_COORD                // (original 0.05 / 0.01875) - inverse scale

// ============================================================================
// TRACER ANIMATION (no change needed)
// ============================================================================

#define TRACER_CACHE_INTERVAL       15                  // steps between tracer updates (mask)
#define TRACER_WARMUP_STEPS         16                  // initial steps to always update

// ============================================================================
// HSV CONVERSION (no change needed)
// ============================================================================

#define HSV_HUE_SCALE               0.16666667          // 1/6
#define HSV_HUE_SECTORS             6.0                 // hue sector count

// ============================================================================
// STRUCTS
// ============================================================================

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