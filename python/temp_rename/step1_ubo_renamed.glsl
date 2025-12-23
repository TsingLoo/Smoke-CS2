#version 460
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_samplerless_texture_functions : require
layout(early_fragment_tests) in;

struct _1017
{
    vec4 _m0;
};

struct _2620
{
    vec4 _m0[4];
};

struct _113
{
    vec4 _m0[16];
};

struct _239
{
    vec4 _m0[5];
};

struct _365
{
    vec4 _m0[2];
};

vec4 _3;

layout(set = 1, binding = 1, std140) uniform CameraDataBlock
{
    layout(offset = 128) _2620 _m0;
    layout(offset = 256) vec4 _m1;
    layout(offset = 304) vec3 _m2;
    layout(offset = 316) float _m3;
    layout(offset = 320) vec3 _m4;
    layout(offset = 332) float _m5;
    layout(offset = 336) vec3 _m6;
    layout(offset = 492) float _m7;
} cameraData;

layout(set = 1, binding = 5, scalar) uniform VolumeDataBlock
{
    layout(offset = 0) _113 _m0;
    layout(offset = 256) _113 _m1;
    layout(offset = 512) _113 _m2;
    layout(offset = 768) _113 _m3;
    layout(offset = 1024) _113 _m4;
    layout(offset = 1280) _113 _m5;
    layout(offset = 1536) vec4 _m6;
    layout(offset = 1552) vec4 _m7;
    layout(offset = 1568) _113 _m8;
    layout(offset = 1824) _113 _m9;
    layout(offset = 2080) _113 _m10;
    layout(offset = 2336) _239 _m11;
    layout(offset = 2416) _365 _m12;
    layout(offset = 2468) uint _m13;
    layout(offset = 2472) float _m14;
    layout(offset = 2476) uint _m15;
} volumeData;

layout(set = 1, binding = 0, std140) uniform RenderParamsBlock
{
    layout(offset = 8) float _m0;
    layout(offset = 12) float _m1;
    layout(offset = 16) float _m2;
    layout(offset = 20) float _m3;
    layout(offset = 24) float _m4;
    layout(offset = 28) float _m5;
    layout(offset = 32) float _m6;
    layout(offset = 36) float _m7;
    layout(offset = 44) float _m8;
    layout(offset = 48) float _m9;
    layout(offset = 52) float _m10;
    layout(offset = 56) float _m11;
    layout(offset = 60) float _m12;
    layout(offset = 64) float _m13;
    layout(offset = 68) float _m14;
    layout(offset = 72) float _m15;
    layout(offset = 76) float _m16;
    layout(offset = 80) float _m17;
    layout(offset = 84) float _m18;
    layout(offset = 92) int _m19;
    layout(offset = 96) vec3 _m20;
    layout(offset = 108) float _m21;
    layout(offset = 112) float _m22;
    layout(offset = 128) float _m23;
    layout(offset = 132) int _m24;
} renderParams;

layout(set = 1, binding = 4, std140) uniform ScreenDataBlock
{
    layout(offset = 176) ivec2 _m0;
    layout(offset = 604) float _m1;
    layout(offset = 608) float _m2;
} screenData;

layout(set = 3, binding = 0, std140) uniform LightingDataBlock
{
    layout(offset = 304) vec4 _m0;
    layout(offset = 320) vec4 _m1;
} lightingData;

layout(set = 1, binding = 30) uniform texture2D _5975;
layout(set = 1, binding = 56) uniform texture2D _4543;
layout(set = 1, binding = 58) uniform texture2D _5967;
layout(set = 1, binding = 57) uniform texture2D _5481;
layout(set = 1, binding = 53) uniform texture3D _3482;
layout(set = 1, binding = 17) uniform sampler _4038;
layout(set = 1, binding = 55) uniform texture3D _3913;
layout(set = 1, binding = 16) uniform sampler _4258;
layout(set = 1, binding = 54) uniform texture3D _4426;

layout(location = 0) in vec3 _5514;
layout(location = 0) out vec4 _3711;
layout(location = 1) out vec4 _3338;
layout(location = 2) out vec4 _3339;
layout(location = 3) out vec4 _3340;
layout(location = 4) out vec4 _3341;
layout(location = 5) out float _3342;

void main()
{
    vec3 _15861 = normalize(_5514);
    vec3 _23296 = vec3(1.0) / _15861;
    vec3 _8251 = _23296 * (volumeData.globalBoundsMin.xyz - cameraData.cameraPosition);
    vec3 _6243 = _23296 * (volumeData.globalBoundsMax.xyz - cameraData.cameraPosition);
    vec3 _7415 = min(_6243, _8251);
    vec3 _13037 = max(_6243, _8251);
    vec2 _11253 = max(_7415.xx, _7415.yz);
    float _12676 = max(_11253.x, _11253.y);
    vec2 _16933 = min(_13037.xx, _13037.yz);
    float _14150 = min(_16933.x, _16933.y);
    if (!(!(_12676 > _14150)))
    {
        discard;
    }
    float _3914 = renderParams.stepSize * 1.5;
    ivec2 _19617 = ivec2(gl_FragCoord.xy);
    float _25102 = max(_12676, 4.0) + (((_3914 * fract(texelFetch(_5975, ivec3(_19617 & screenData.noiseTileSize, 0).xy, 0).x + (cameraData.time * 0.61803400516510009765625))) * renderParams.jitterScale) * mix(0.100000001490116119384765625, 0.800000011920928955078125, clamp((_12676 + 150.0) * 0.0500000007450580596923828125, 0.0, 1.0)));
    ivec2 _17338 = ivec3(_19617, 0).xy;
    float _10955 = cameraData.farPlane - cameraData.nearPlane;
    float _24159 = (clamp((texelFetch(_4543, _17338, 0).x - cameraData.nearPlane) / _10955, 0.0, 1.0) * cameraData.projectionParams.z) + cameraData.projectionParams.w;
    float _15694 = dot(cameraData.viewDirection.xyz, _15861);
    float _19245 = 1.0 / (_24159 * _15694);
    vec3 _18051 = (-_15861).xyz;
    vec3 _7391 = cameraData.cameraPosition.xyz + (_18051 * (1.0 / (_24159 * dot(cameraData.viewDirection.xyz, _18051))));
    bool _6681 = volumeData.dissipationCount > 0u;
    bool _12666;
    if (_6681)
    {
        _12666 = ((1.0 / (((clamp((texelFetch(_5967, ivec3(ivec2(gl_FragCoord.xy * float(renderParams.depthDownscale)), 0).xy, 0).x - cameraData.nearPlane) / _10955, 0.0, 1.0) * cameraData.projectionParams.z) + cameraData.projectionParams.w) * _15694)) - _19245) > 10.0;
    }
    else
    {
        _12666 = false;
    }
    float _4364 = _19245 - 2.0;
    if (_25102 > _4364)
    {
        discard;
    }
    vec3 _5607 = cameraData.cameraPosition + (_15861 * _25102);
    vec3 _4987 = cameraData.cameraPosition + (_15861 * min(_14150, _4364));
    uint _19697 = uint(texelFetch(_5481, _17338, 0).x);
    uint _4249;
    uint _15529;
    _1017 _5767[1];
    uint _6386;
    uint _6864;
    uint _13136 = 0u;
    uint _16324 = 0u;
    uint _17017 = _19697;
    for (;;)
    {
        if (!(_17017 != 0u))
        {
            _6864 = _16324;
            break;
        }
        if ((_17017 & 1u) != 0u)
        {
            vec3 _8252 = _23296 * (volumeData.volumeBoundsMin._m0[_13136].xyz - cameraData.cameraPosition);
            vec3 _6244 = _23296 * (volumeData.volumeBoundsMax._m0[_13136].xyz - cameraData.cameraPosition);
            vec3 _7416 = min(_6244, _8252);
            vec3 _13038 = max(_6244, _8252);
            vec2 _11254 = max(_7416.xx, _7416.yz);
            vec2 _16934 = min(_13038.xx, _13038.yz);
            _5767[_16324]._m0.x = max(_11254.x, _11254.y);
            _5767[_16324]._m0.y = min(_16934.x, _16934.y);
            _5767[_16324]._m0.z = float(_13136);
            _6386 = _16324 + 1u;
        }
        else
        {
            _6386 = _16324;
        }
        if (_6386 >= 1u)
        {
            _6864 = _6386;
            break;
        }
        _4249 = _17017 >> uint(1);
        _15529 = _13136 + 1u;
        _13136 = _15529;
        _16324 = _6386;
        _17017 = _4249;
        continue;
    }
    float _12756;
    vec3 _13175;
    vec4 _14229;
    vec3 _16327;
    float _17192;
    do
    {
        _1017 _20544[1] = _5767;
        float _7668 = length(_4987 - _5607);
        int _14823 = int(clamp(ceil(_7668 / _3914) + 10.0, 1.0, 500.0));
        uint _12127 = min(_6864, 1u);
        vec3 _19298 = cross(cameraData.viewDirection, cameraData.rightVector);
        float _14778 = _25102 + _7668;
        vec3 _17018;
        vec4 _17115;
        vec3 _17117;
        vec3 _17120;
        vec3 _17133;
        _17115 = vec4(0.0);
        _17117 = vec3(0.0, 0.0, 0.00999999977648258209228515625);
        _17120 = _5607;
        _17133 = _4987;
        _17018 = _4987;
        float _20747;
        vec3 _22071;
        int _23989;
        vec3 _13155;
        vec3 _13156;
        bool _16306;
        vec3 _16314;
        vec3 _16315;
        bool _16863;
        bool _16864;
        float _17143;
        float _17144;
        vec4 _17145;
        float _17147;
        vec3 _17148;
        float _17149;
        bool _17150;
        float _17151;
        uint _17152;
        float _17153;
        vec4 _17154;
        float _17156;
        vec3 _17157;
        float _17158;
        uint _17159;
        float _17160;
        bool _13137 = false;
        float _16305 = 0.0;
        float _17114 = 0.0;
        float _17116 = 0.0;
        float _17118 = 0.0;
        uint _17119 = 0u;
        float _17121 = _25102;
        bool _17122 = false;
        int _17123 = 0;
        for (;;)
        {
            if (!(_17123 < _14823))
            {
                _13156 = _17133;
                _16315 = _17018;
                _17150 = _17122;
                _17151 = _16305;
                _17153 = _17114;
                _17154 = _17115;
                _17156 = _17116;
                _17157 = _17117;
                _17158 = _17118;
                _17159 = _17119;
                _17160 = _17121;
                _16864 = _13137;
                break;
            }
            bool _23149;
            if (volumeData.lightCount > 0u)
            {
                bool _12501;
                if ((_17123 & 15) == 0)
                {
                    _12501 = true;
                }
                else
                {
                    _12501 = _17123 < 16;
                }
                _23149 = _12501;
            }
            else
            {
                _23149 = false;
            }
            float _24117 = _23149 ? 0.0 : _17116;
            float _17855 = _23149 ? 0.0 : _17118;
            uint _14433 = _23149 ? 0u : _17119;
            vec3 _13138;
            vec4 _17126;
            vec3 _17128;
            _13138 = _17018;
            _16306 = _17122;
            _17126 = _17115;
            _17128 = mix(_17117, vec3(0.0, 0.0, 0.00999999977648258209228515625), bvec3(_23149));
            uint _8897;
            vec3 _13154;
            float _14891;
            bool _16313;
            float _17138;
            float _17139;
            vec4 _17140;
            float _17141;
            vec3 _17142;
            uint _18361;
            uint _17019 = 0u;
            float _17124 = _16305;
            float _17125 = _17114;
            float _17127 = _24117;
            float _17129 = _17855;
            uint _17134 = _14433;
            for (;;)
            {
                bool _7956_ladder_break = false;
                do
                {
                    if (!(_17019 < _12127))
                    {
                        _13155 = _17133;
                        _16314 = _13138;
                        _17143 = _17124;
                        _17144 = _17125;
                        _17145 = _17126;
                        _17147 = _17127;
                        _17148 = _17128;
                        _17149 = _17129;
                        _17152 = _17134;
                        _16863 = _13137;
                        _7956_ladder_break = true;
                        break;
                    }
                    if (_17121 < _20544[_17019]._m0.x)
                    {
                        _13154 = _13138;
                        _16313 = _16306;
                        _17138 = _17124;
                        _17139 = _17125;
                        _17140 = _17126;
                        _17141 = _17127;
                        _17142 = _17128;
                        _14891 = _17129;
                        _18361 = _17134;
                        break;
                    }
                    if (_17121 > _20544[_17019]._m0.y)
                    {
                        _13154 = _13138;
                        _16313 = _16306;
                        _17138 = _17124;
                        _17139 = _17125;
                        _17140 = _17126;
                        _17141 = _17127;
                        _17142 = _17128;
                        _14891 = _17129;
                        _18361 = _17134;
                        break;
                    }
                    vec3 _7688;
                    uint _13141;
                    float _13618;
                    float _16308;
                    do
                    {
                        bool _12885;
                        if (volumeData.lightCount == 0u)
                        {
                            _12885 = true;
                        }
                        else
                        {
                            _12885 = (_17134 & 3u) != 0u;
                        }
                        if (_12885)
                        {
                            _13141 = _17134;
                            _16308 = _17127;
                            _13618 = _17129;
                            _7688 = _17128;
                            break;
                        }
                        float _13139;
                        vec3 _16307;
                        float _17135;
                        _13139 = _17127;
                        _16307 = _17128;
                        _17135 = _17129;
                        uint _8087;
                        vec3 _13140;
                        float _13189;
                        float _14382;
                        uint _17020 = 0u;
                        for (;;)
                        {
                            if (!(_17020 < min(volumeData.lightCount, 16u)))
                            {
                                break;
                            }
                            vec3 _21554 = volumeData.lightPositionsEnd._m0[_17020].xyz - volumeData.lightPositionsStart._m0[_17020].xyz;
                            vec3 _14636 = _17120 - volumeData.lightPositionsStart._m0[_17020].xyz;
                            float _19448 = clamp((length(_14636 - (_21554 * clamp(dot(_14636, _21554) / dot(_21554, _21554), 0.0, 1.0))) * 0.0500000007450580596923828125) * volumeData.lightParams._m0[_17020].x, 0.0, 1.0);
                            float _14626 = smoothstep(0.0, 0.00999999977648258209228515625, volumeData.lightPositionsStart._m0[_17020].w) * (1.0 - smoothstep(0.00999999977648258209228515625, 0.20000000298023223876953125, volumeData.lightPositionsStart._m0[_17020].w));
                            float _6223;
                            if (_19448 < 1.0)
                            {
                                float _18731 = max(_17135, smoothstep(0.0, 1.0, 1.0 - clamp(volumeData.lightPositionsStart._m0[_17020].w + clamp(_19448 + (1.0 - clamp(length(_17120 - volumeData.lightPositionsEnd._m0[_17020].xyz) * 0.00999999977648258209228515625, 0.0, 1.0)), 0.0, 1.0), 0.0, 1.0)));
                                _13140 = mix(_16307, normalize(volumeData.lightPositionsStart._m0[_17020].xyz - volumeData.lightPositionsEnd._m0[_17020].xyz), vec3(_18731));
                                _13189 = _18731;
                                _6223 = (pow(1.0 - _19448, 64.0) * _14626) * 10.0;
                            }
                            else
                            {
                                _13140 = _16307;
                                _13189 = _17135;
                                _6223 = 0.0;
                            }
                            if (volumeData.lightPositionsEnd._m0[_17020].w > 0.0)
                            {
                                float _10368 = (1.0 - clamp(length(_14636) * 0.00999999977648258209228515625, 0.0, 1.0)) * _14626;
                                _14382 = max(_13139, max(_10368 * _10368, _6223));
                            }
                            else
                            {
                                _14382 = _13139;
                            }
                            _8087 = _17020 + 1u;
                            _13139 = _14382;
                            _16307 = _13140;
                            _17135 = _13189;
                            _17020 = _8087;
                            continue;
                        }
                        _13141 = _17134 | 1u;
                        _16308 = _13139;
                        _13618 = _17135;
                        _7688 = _16307;
                        break;
                    } while(false);
                    uint _25081 = uint(_20544[_17019]._m0.z);
                    bool _10669;
                    float _13153;
                    vec4 _13637;
                    float _16312;
                    do
                    {
                        vec3 _25170 = _17120 + ((normalize(_7688) * pow(_13618, 3.0)) * 20.0);
                        int _22666 = int(_25081);
                        vec3 _14658 = clamp((((_25170 - volumeData.volumeCenters._m0[_22666].xyz) * vec3(0.0500000007450580596923828125)) + vec3(16.0)) * vec3(0.03125), vec3(0.0), vec3(1.0));
                        vec3 _21495 = clamp(_14658, vec3(0.0), vec3(1.0));
                        uint _14092 = uint(volumeData.volumeParams._m0[_25081].z);
                        float _24255 = 34.0 * float(_14092);
                        _21495.x = (_24255 + (_21495.x * 32.0)) * 0.0018450184725224971771240234375;
                        vec4 _11487 = textureLod(sampler3D(_3482, _4038), _21495.xyz, 0.0);
                        vec2 _7714 = mix(_11487.xz, _11487.yw, vec2(volumeData.volumeParams._m0[_25081].y));
                        float _20593 = _7714.x;
                        float _6734 = _7714.y;
                        vec4 _13144;
                        _13144.w = _6734;
                        float _8283 = distance(_25170, _4987);
                        vec4 _18056;
                        if (_20593 > _6734)
                        {
                            vec4 _11248;
                            _11248.w = mix(_6734, _20593, smoothstep(10.0, 40.0, _8283));
                            _18056 = _11248;
                        }
                        else
                        {
                            _18056 = _13144.xyzw;
                        }
                        float _6665 = clamp(mix(_18056.w, -0.0500000007450580596923828125, _13618), 0.0, 1.0);
                        if (_6665 > 0.00999999977648258209228515625)
                        {
                            float _17820 = max(0.0, _8283 - min(20.0, abs(_7391.z - volumeData.volumeCenters._m0[_22666].z) * 2.0));
                            float _20845 = clamp(clamp((_6665 - 0.00999999977648258209228515625) * 1.01010096073150634765625, 0.0, 1.0), 0.0, 1.0) * volumeData.volumeDensityParams._m0[_25081].x;
                            float _22281 = clamp(_20845 + ((1.0 - clamp(distance(cameraData.cameraPosition, _25170) * 0.100000001490116119384765625, 0.0, 1.0)) * _20845), 0.0, 1.0);
                            vec3 _6616;
                            float _13148;
                            float _13694;
                            float _16310;
                            if (_6681)
                            {
                                vec3 _13142;
                                float _16309;
                                float _17136;
                                _13142 = _25170;
                                _16309 = 0.0;
                                _17136 = 1.0;
                                uint _8896;
                                vec3 _13147;
                                float _14082;
                                float _18360;
                                uint _17021 = 0u;
                                for (;;)
                                {
                                    bool _7957_ladder_break = false;
                                    do
                                    {
                                        if (!(_17021 < min(volumeData.dissipationCount, 5u)))
                                        {
                                            _7957_ladder_break = true;
                                            break;
                                        }
                                        if ((uint(volumeData.dissipationChannelMask._m0[_17021 >> uint(2)][_17021 & 3u]) & (1u << _14092)) == 0u)
                                        {
                                            _13147 = _13142;
                                            _14082 = _17136;
                                            _18360 = _16309;
                                            break;
                                        }
                                        float _10810 = volumeData.globalTime - volumeData.dissipationPoints._m0[_17021].w;
                                        vec3 _13146;
                                        float _16382;
                                        float _16480;
                                        if (_10810 < (volumeData.volumeParams._m0[_25081].x - 0.4000000059604644775390625))
                                        {
                                            float _13668 = distance(_13142, volumeData.dissipationPoints._m0[_17021].xyz);
                                            vec3 _13143;
                                            float _16381;
                                            float _16479;
                                            if (_13668 < 250.0)
                                            {
                                                float _16611 = pow(1.0 - smoothstep(0.0, 2.0, _10810), 128.0);
                                                float _13560;
                                                if (!_12666)
                                                {
                                                    _13560 = clamp((48.0 - _17820) * 0.02083333395421504974365234375, 0.0, 1.0) * (1.0 - smoothstep(0.0, 7.0, _10810));
                                                }
                                                else
                                                {
                                                    _13560 = _16309;
                                                }
                                                _13143 = mix(_13142, volumeData.dissipationPoints._m0[_17021].xyz, vec3(((1.0 - smoothstep(100.0, 250.0, _13668)) * step(_10810 * 1250.0, _13668)) * (1.0 - _16611)));
                                                _16381 = min(_17136, max(smoothstep(200.0, 240.0, _13668 + (_16611 * 250.0)) + pow(smoothstep(0.5, 5.0, _10810), 1.7999999523162841796875), _13560));
                                                _16479 = _13560;
                                            }
                                            else
                                            {
                                                _13143 = _13142;
                                                _16381 = _17136;
                                                _16479 = _16309;
                                            }
                                            _13146 = _13143;
                                            _16382 = _16381;
                                            _16480 = _16479;
                                        }
                                        else
                                        {
                                            _13146 = _13142;
                                            _16382 = _17136;
                                            _16480 = _16309;
                                        }
                                        _13147 = _13146;
                                        _14082 = _16382;
                                        _18360 = _16480;
                                        break;
                                    } while(false);
                                    if (_7957_ladder_break)
                                    {
                                        break;
                                    }
                                    _8896 = _17021 + 1u;
                                    _13142 = _13147;
                                    _16309 = _18360;
                                    _17136 = _14082;
                                    _17021 = _8896;
                                    continue;
                                }
                                _13148 = _17136;
                                _16310 = _16309;
                                _13694 = mix(_22281 * 0.0199999995529651641845703125, _22281, _17136);
                                _6616 = _13142;
                            }
                            else
                            {
                                _13148 = 1.0;
                                _16310 = 0.0;
                                _13694 = _22281;
                                _6616 = _25170;
                            }
                            float _20017 = cameraData.time * renderParams.timeScale;
                            vec3 _11675 = _14658 - vec3(0.5);
                            vec3 _11772 = _11675 * 7.0;
                            float _11476 = _11772.z;
                            float _9117 = _20017 * 0.5;
                            float _7385 = (_20017 * 0.039999999105930328369140625) + ((((0.20000000298023223876953125 + ((sin(_11476 * 5.0) + 0.5) * 0.1500000059604644775390625)) * sin(_9117 + 0.5)) * sin((_20017 * 0.1870000064373016357421875) + 0.5)) * 0.20000000298023223876953125);
                            float _17167 = sin(_7385);
                            float _17391 = cos(_7385);
                            vec2 _23932 = _11772.xy * mat2(vec2(_17391, -_17167), vec2(_17167, _17391));
                            float _16176 = _23932.x;
                            vec3 _21583 = _11772;
                            _21583.x = _16176;
                            float _6688 = _23932.y;
                            float _14459 = _20017 + (sin(_9117) * 0.0199999995529651641845703125);
                            vec2 _24074 = _21583.xz + (vec2(sin(_14459 + (_11476 * 2.7000000476837158203125)), cos(_14459 + (_16176 * 2.7000000476837158203125))) * 0.0500000007450580596923828125);
                            float _10133 = _24074.x;
                            float _10752 = _24074.y;
                            vec3 _22420 = vec3(_10133, _6688, _10752);
                            float _8650 = _10752 + ((sin((_10133 * 3.0) + (_20017 * 0.3499999940395355224609375)) + sin((_6688 * 2.8399999141693115234375) + (_20017 * 0.23499999940395355224609375))) * 0.0500000007450580596923828125);
                            _22420.z = _8650;
                            vec3 _10824 = _22420 * renderParams.noise1Scale;
                            vec3 _9985 = vec3(2.0, 2.0, 4.5) * (_20017 * 0.100000001490116119384765625);
                            vec3 _13915 = cameraData.rightVector * 0.20000000298023223876953125;
                            vec3 _13916 = _19298 * 0.20000000298023223876953125;
                            vec4 _16433 = vec4(renderParams.noisePower);
                            vec4 _21177 = pow(textureLod(sampler3D(_3913, _4258), ((abs(_10824) - _9985) * 0.070000000298023223876953125).xyz, 0.0), _16433);
                            vec4 _6421 = vec4(renderParams.noiseColorA);
                            vec4 _7260 = vec4(renderParams.noiseColorB);
                            vec4 _15547 = vec4(renderParams.noiseMixFactor);
                            vec4 _24109 = mix(mix(_6421, _7260, _21177), mix(vec4(0.25), vec4(-1.5), _21177), _15547);
                            float _11087 = (_24109.x + (_24109.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 _17262 = pow(textureLod(sampler3D(_3913, _4258), ((abs(_10824 + _13915) - _9985) * 0.070000000298023223876953125).xyz, 0.0), _16433);
                            vec4 _19777 = mix(mix(_6421, _7260, _17262), mix(vec4(0.25), vec4(-1.5), _17262), _15547);
                            vec4 _17263 = pow(textureLod(sampler3D(_3913, _4258), ((abs(_10824 + _13916) - _9985) * 0.070000000298023223876953125).xyz, 0.0), _16433);
                            vec4 _19778 = mix(mix(_6421, _7260, _17263), mix(vec4(0.25), vec4(-1.5), _17263), _15547);
                            float _20360 = 0.800000011920928955078125 / renderParams.noise1Scale;
                            vec3 _6512 = normalize(vec3(_11087 - ((_19778.x + (_19778.y * 0.949999988079071044921875)) * 4.599999904632568359375), _11087 - ((_19777.x + (_19777.y * 0.949999988079071044921875)) * 4.599999904632568359375), _20360));
                            mat4 _21989 = mat4(vec4(cameraData.viewMatrix._m0[0].x, cameraData.viewMatrix._m0[1].x, cameraData.viewMatrix._m0[2].x, cameraData.viewMatrix._m0[3].x), vec4(cameraData.viewMatrix._m0[0].y, cameraData.viewMatrix._m0[1].y, cameraData.viewMatrix._m0[2].y, cameraData.viewMatrix._m0[3].y), vec4(cameraData.viewMatrix._m0[0].z, cameraData.viewMatrix._m0[1].z, cameraData.viewMatrix._m0[2].z, cameraData.viewMatrix._m0[3].z), vec4(cameraData.viewMatrix._m0[0].w, cameraData.viewMatrix._m0[1].w, cameraData.viewMatrix._m0[2].w, cameraData.viewMatrix._m0[3].w));
                            float _16360 = _11675.z;
                            vec3 _20799 = (_11772 + ((((_21989 * vec4((_6512 + vec3(0.0, 0.0, 1.0)).xyz, 0.0)).xyz * pow(_11087, 0.100000001490116119384765625)) * renderParams.normalDetailScale) * 0.20000000298023223876953125)) + (vec3(2.0, 2.0, 4.5) * ((((_11087 - 1.0) * 0.20000000298023223876953125) * renderParams.normalDetailScale) * _16360));
                            _20799.x = _20799.x + (sin(_8650 + (_20017 * 0.25)) * 0.0500000007450580596923828125);
                            vec3 _19464 = _20799 * renderParams.noise2Scale;
                            vec4 _11130 = pow(textureLod(sampler3D(_3913, _4258), (_19464 * 0.070000000298023223876953125).xyz, 0.0), _16433);
                            vec4 _19779 = mix(mix(_6421, _7260, _11130), mix(vec4(0.25), vec4(-1.5), _11130), _15547);
                            float _11089 = (_19779.x + (_19779.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 _17264 = pow(textureLod(sampler3D(_3913, _4258), ((_19464 + _13915) * 0.070000000298023223876953125).xyz, 0.0), _16433);
                            vec4 _19780 = mix(mix(_6421, _7260, _17264), mix(vec4(0.25), vec4(-1.5), _17264), _15547);
                            vec4 _17265 = pow(textureLod(sampler3D(_3913, _4258), ((_19464 + _13916) * 0.070000000298023223876953125).xyz, 0.0), _16433);
                            vec4 _19781 = mix(mix(_6421, _7260, _17265), mix(vec4(0.25), vec4(-1.5), _17265), _15547);
                            float _17671 = renderParams.detailNoiseInfluence * (dot(_15861, cameraData.viewDirection) * clamp(distance(_6616, cameraData.cameraPosition) * 0.004999999888241291046142578125, 0.0, 1.0));
                            float _13150 = (mix(0.949999988079071044921875, clamp(_11087, 0.0, 1.0), renderParams.noise1Influence) + mix(0.949999988079071044921875, clamp(_11089, 0.0, 1.0), _17671 * 0.25)) + renderParams.noiseOffset;
                            float _11621;
                            if (volumeData.volumeDensityParams._m0[_25081].w < 1.0)
                            {
                                float _14675 = clamp(volumeData.volumeDensityParams._m0[_25081].w, 9.9999997473787516355514526367188e-05, 0.99989998340606689453125);
                                float _8419 = smoothstep(0.0, 0.800000011920928955078125, _14675);
                                float _14551 = smoothstep(0.20000000298023223876953125, 1.0, _14675);
                                float _12502;
                                if (_8419 == _14551)
                                {
                                    _12502 = _13694 * _14675;
                                }
                                else
                                {
                                    vec3 _23051 = _11675;
                                    _23051.z = _16360 * 1.2000000476837158203125;
                                    _12502 = _13694 * clamp(smoothstep(_8419, _14551, clamp(length(_23051), 0.0, 1.0)), 0.0, 1.0);
                                }
                                _11621 = _12502;
                            }
                            else
                            {
                                _11621 = _13694;
                            }
                            float _13439 = mix(_11621 - (1.0 - _13150), _11621 + _13150, _11621) * clamp((volumeData.volumeDensityParams._m0[_25081].x * volumeData.volumeDensityParams._m0[_25081].w) * 8.0, 0.0, 1.0);
                            if (_13439 < 9.9999997473787516355514526367188e-05)
                            {
                                _13153 = _17124;
                                _16312 = _17125;
                                _13637 = _17126;
                                _10669 = false;
                                break;
                            }
                            vec3 _21940 = normalize(_11675) * mix(1.0, 0.0, clamp(_16310, 0.0, 1.0));
                            vec4 _13055 = _21989 * vec4(((vec4(_21940.xyz, 0.0).xyzw * _21989).xyz + ((vec3((_6512.xy * renderParams.noise1Influence) + ((normalize(vec3(_11089 - ((_19781.x + (_19781.y * 0.949999988079071044921875)) * 4.599999904632568359375), _11089 - ((_19780.x + (_19780.y * 0.949999988079071044921875)) * 4.599999904632568359375), _20360)) * mix(0.5, 1.0, clamp(_11087 - 0.5, 0.0, 1.0))).xy * (_17671 * 1.5)), 0.0) * renderParams.normalPerturbScale) * mix(1.0, 2.0, clamp((200.0 - distance(_6616, volumeData.volumeCenters._m0[_22666].xyz)) * 0.004999999888241291046142578125, 0.0, 1.0)))).xyz, 0.0);
                            vec3 _19632 = _13055.xyz;
                            vec3 _16793 = clamp(clamp(mix(_11675 * dot(_21940, _19632), normalize(_19632 + vec3(0.0, 0.0, 0.5)) * length(_11675), vec3(0.20000000298023223876953125)) + vec3(0.5), vec3(0.02999999932944774627685546875), vec3(0.9700000286102294921875)), vec3(0.0), vec3(1.0));
                            _16793.x = (_24255 + (_16793.x * 32.0)) * 0.0018450184725224971771240234375;
                            vec4 _13568 = textureLod(sampler3D(_4426, _4038), _16793.xyz, 0.0);
                            float _15561 = dot(mix(_21940, _19632, vec3(renderParams.phaseBlend)), lightingData.sunDirection.xyz);
                            float _8123 = pow(clamp((_15561 * 0.800000011920928955078125) + 0.20000000298023223876953125, 0.0, 1.0), 1.5) + pow(clamp((_15561 * 1.39999997615814208984375) - 0.5, 0.0, 1.0), 3.0);
                            float _11275;
                            if (_8123 > 0.0)
                            {
                                _11275 = _8123 * _13568.w;
                            }
                            else
                            {
                                _11275 = _8123;
                            }
                            float _16847 = _13568.x;
                            float _15573 = _13568.y;
                            float _21520 = _13568.z;
                            float _16613 = max(_16847, max(_15573, _21520));
                            float _12972 = _16613 - min(_16847, min(_15573, _21520));
                            vec3 _6553 = vec3(0.0);
                            _6553.z = _16613;
                            vec3 _20310;
                            if (_12972 != 0.0)
                            {
                                float _20364 = _12972 / _16613;
                                vec3 _18850 = (_6553.zzz - _13568.xyz) / vec3(_12972);
                                vec3 _18380 = _18850.xyz - _18850.zxy;
                                vec2 _10889 = _18380.xy + vec2(2.0, 4.0);
                                vec3 _20309;
                                if (_16847 >= _16613)
                                {
                                    _20309 = vec3(_18380.z, _20364, _16613);
                                }
                                else
                                {
                                    vec3 _12503;
                                    if (_15573 >= _16613)
                                    {
                                        _12503 = vec3(_10889.x, _20364, _16613);
                                    }
                                    else
                                    {
                                        _12503 = vec3(_10889.y, _20364, _16613);
                                    }
                                    _20309 = _12503;
                                }
                                vec3 _11027 = _20309;
                                _11027.x = fract(_20309.x * 0.16666667163372039794921875);
                                _20310 = _11027;
                            }
                            else
                            {
                                _20310 = _6553;
                            }
                            float _20352 = clamp(_20310.y * 1.10000002384185791015625, 0.0, 1.0);
                            vec3 _14327;
                            if (_20352 != 0.0)
                            {
                                float _23216 = _20310.x * 6.0;
                                float _10653 = floor(_23216);
                                float _19977 = _20310.z * (1.0 - _20352);
                                float _17993 = _23216 - _10653;
                                float _10560 = _20310.z * (1.0 - (_20352 * _17993));
                                float _23319 = _20310.z * (1.0 - (_20352 * (1.0 - _17993)));
                                vec3 _12508;
                                if (_10653 == 0.0)
                                {
                                    _12508 = vec3(_20310.z, _23319, _19977);
                                }
                                else
                                {
                                    vec3 _12507;
                                    if (_10653 == 1.0)
                                    {
                                        _12507 = vec3(_10560, _20310.z, _19977);
                                    }
                                    else
                                    {
                                        vec3 _12506;
                                        if (_10653 == 2.0)
                                        {
                                            _12506 = vec3(_19977, _20310.z, _23319);
                                        }
                                        else
                                        {
                                            vec3 _12505;
                                            if (_10653 == 3.0)
                                            {
                                                _12505 = vec3(_19977, _10560, _20310.z);
                                            }
                                            else
                                            {
                                                vec3 _12504;
                                                if (_10653 == 4.0)
                                                {
                                                    _12504 = vec3(_23319, _19977, _20310.z);
                                                }
                                                else
                                                {
                                                    _12504 = vec3(_20310.z, _19977, _10560);
                                                }
                                                _12505 = _12504;
                                            }
                                            _12506 = _12505;
                                        }
                                        _12507 = _12506;
                                    }
                                    _12508 = _12507;
                                }
                                _14327 = _12508;
                            }
                            else
                            {
                                _14327 = _20310.zzz;
                            }
                            vec3 _24091 = (((((((normalize(_14327 + vec3(0.001000000047497451305389404296875)) * min(length(_14327), 4.0)) * clamp(1.0 - min(0.25, _13439), 0.0, 1.0)) * clamp(1.0 - (((_11621 * 2.400000095367431640625) - _13439) * renderParams.densityContrast), 0.0, 1.0)) * _13150) * (0.75 + (_11275 * 0.25))) * (1.0 + (_13055.z * 0.5))) * renderParams.baseColorIntensity) + ((lightingData.sunColor.xyz * ((0.5 * _11275) * (1.0 - _13618))) * renderParams.sunColorIntensity);
                            vec3 _23772 = _24091 * volumeData.volumeColors._m0[_25081].xyz;
                            vec3 _16436 = (mix(_24091, _23772 * (dot(_24091.xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125)) / dot((_23772 + vec3(0.001000000047497451305389404296875)).xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125))), vec3(0.5 * (1.0 - volumeData.volumeDensityParams._m0[_25081].z))) * mix(vec3(1.0), normalize(renderParams.colorTint + vec3(0.00999999977648258209228515625)) * 1.73199999332427978515625, vec3(clamp(0.5 + (_13439 * 6.0), 0.0, 1.0)))).xyz;
                            vec3 _21313 = mix(_16436, _16436 * _13148, vec3(0.60000002384185791015625)).xyz;
                            float _22660 = smoothstep(0.0, 0.20000000298023223876953125, _13439 + 0.300000011920928955078125) * (((clamp((renderParams.godrayFalloff - _17820) / renderParams.godrayFalloff, 0.0, 1.0) * _11621) * 6.0) * renderParams.godrayIntensity);
                            float _17656 = smoothstep(0.0, 0.20000000298023223876953125 / (renderParams.alphaScale * mix(0.5, 2.0, _17126.w)), _13439);
                            vec4 _22501 = vec4(((_21313 + ((_21313 * vec3(8.0, 4.0, 0.0)) * _16308)) * mix(1.0, 0.85000002384185791015625, clamp(_16310 * 20.0, 0.0, 1.0))) * _17656, _17656);
                            float _13152;
                            vec4 _16311;
                            float _17022;
                            float _17137;
                            _13152 = _17124;
                            _16311 = _17126;
                            _17137 = _17125;
                            _17022 = renderParams.stepSize * 0.375;
                            float _11921;
                            vec4 _19916;
                            float _23566;
                            float _25059;
                            for (;;)
                            {
                                if (!(_17022 >= 1.0))
                                {
                                    break;
                                }
                                _23566 = _17137 + _22660;
                                _19916 = _16311 + (_22501 * (1.0 - _16311.w));
                                _11921 = _13152 + _11275;
                                _25059 = _17022 - 1.0;
                                _13152 = _11921;
                                _16311 = _19916;
                                _17137 = _23566;
                                _17022 = _25059;
                                continue;
                            }
                            _13153 = _13152 + (_11275 * _17022);
                            _16312 = _17137 + (_22660 * _17022);
                            _13637 = _16311 + (_22501 * ((1.0 - _16311.w) * _17022));
                            _10669 = (_17656 + _22660) > 0.0;
                            break;
                        }
                        _13153 = _17124;
                        _16312 = _17125;
                        _13637 = _17126;
                        _10669 = false;
                        break;
                    } while(false);
                    _20544[_17019] = _20544[_17019];
                    bool _21167;
                    if (_10669)
                    {
                        _21167 = !_16306;
                    }
                    else
                    {
                        _21167 = false;
                    }
                    vec3 _14400 = mix(_13138, _17120, bvec3(_21167));
                    if (_13637.w > 0.990999996662139892578125)
                    {
                        vec4 _23482 = _13637;
                        _23482.w = 1.0;
                        _13155 = _17120;
                        _16314 = _14400;
                        _17143 = _13153;
                        _17144 = _16312;
                        _17145 = _23482;
                        _17147 = _16308;
                        _17148 = _7688;
                        _17149 = _13618;
                        _17152 = _13141;
                        _16863 = true;
                        _7956_ladder_break = true;
                        break;
                    }
                    _13154 = _14400;
                    _16313 = _21167 ? true : _16306;
                    _17138 = _13153;
                    _17139 = _16312;
                    _17140 = _13637;
                    _17141 = _16308;
                    _17142 = _7688;
                    _14891 = _13618;
                    _18361 = _13141;
                    break;
                } while(false);
                if (_7956_ladder_break)
                {
                    break;
                }
                _8897 = _17019 + 1u;
                _13138 = _13154;
                _16306 = _16313;
                _17124 = _17138;
                _17125 = _17139;
                _17126 = _17140;
                _17127 = _17141;
                _17128 = _17142;
                _17129 = _14891;
                _17134 = _18361;
                _17019 = _8897;
                continue;
            }
            if (_16863)
            {
                _13156 = _13155;
                _16315 = _16314;
                _17150 = _16306;
                _17151 = _17143;
                _17153 = _17144;
                _17154 = _17145;
                _17156 = _17147;
                _17157 = _17148;
                _17158 = _17149;
                _17159 = _17152;
                _17160 = _17121;
                _16864 = _16863;
                break;
            }
            _22071 = _17120 + (_15861 * _3914);
            _20747 = _17121 + _3914;
            if (_20747 >= _14778)
            {
                _13156 = _13155;
                _16315 = _16314;
                _17150 = _16306;
                _17151 = _17143;
                _17153 = _17144;
                _17154 = _17145;
                _17156 = _17147;
                _17157 = _17148;
                _17158 = _17149;
                _17159 = _17152;
                _17160 = _20747;
                _16864 = _16863;
                break;
            }
            _23989 = _17123 + 1;
            _13137 = _16863;
            _16305 = _17143;
            _17114 = _17144;
            _17115 = _17145;
            _17116 = _17147;
            _17117 = _17148;
            _17118 = _17149;
            _17119 = _17152;
            _17120 = _22071;
            _17121 = _20747;
            _17122 = _16306;
            _17123 = _23989;
            _17133 = _13155;
            _17018 = _16314;
            continue;
        }
        if (_16864)
        {
            _13175 = _13156;
            _16327 = _16315;
            _17192 = _17151;
            _12756 = _17153;
            _14229 = _17154;
            break;
        }
        vec3 _13174;
        vec3 _16326;
        vec4 _16483;
        float _17190;
        float _17191;
        if (renderParams.enableSecondPass != 0)
        {
            float _13238 = _17160 - _3914;
            vec3 _21812 = _5607 + (_15861 * _7668);
            float _13244 = _14778 - _13238;
            vec3 _17023;
            vec4 _17163;
            vec3 _17165;
            _17163 = _17154;
            _17165 = _17157;
            _17023 = _16315;
            uint _8899;
            bool _13172;
            vec3 _13173;
            uint _14892;
            float _16323;
            vec3 _16325;
            bool _16865;
            float _17180;
            vec4 _17181;
            float _17182;
            vec3 _17183;
            float _17184;
            float _17185;
            float _17188;
            vec4 _17189;
            vec3 _18363;
            bool _13157 = _17150;
            float _16316 = _17151;
            float _17161 = _17153;
            float _17164 = _17156;
            float _17166 = _17158;
            uint _17168 = _17159;
            uint _17169 = 0u;
            for (;;)
            {
                bool _7958_ladder_break = false;
                do
                {
                    if (!(_17169 < _12127))
                    {
                        _13173 = _13156;
                        _16325 = _17023;
                        _17185 = _16316;
                        _17188 = _17161;
                        _17189 = _17163;
                        _16865 = _16864;
                        _7958_ladder_break = true;
                        break;
                    }
                    if (_13238 < _20544[_17169]._m0.x)
                    {
                        _13172 = _13157;
                        _16323 = _16316;
                        _17180 = _17161;
                        _17181 = _17163;
                        _17182 = _17164;
                        _17183 = _17165;
                        _17184 = _17166;
                        _14892 = _17168;
                        _18363 = _17023;
                        break;
                    }
                    if (_13238 > _20544[_17169]._m0.y)
                    {
                        _13172 = _13157;
                        _16323 = _16316;
                        _17180 = _17161;
                        _17181 = _17163;
                        _17182 = _17164;
                        _17183 = _17165;
                        _17184 = _17166;
                        _14892 = _17168;
                        _18363 = _17023;
                        break;
                    }
                    vec3 _7689;
                    uint _13160;
                    float _13620;
                    float _16318;
                    do
                    {
                        bool _12886;
                        if (volumeData.lightCount == 0u)
                        {
                            _12886 = true;
                        }
                        else
                        {
                            _12886 = (_17168 & 3u) != 0u;
                        }
                        if (_12886)
                        {
                            _13160 = _17168;
                            _16318 = _17164;
                            _13620 = _17166;
                            _7689 = _17165;
                            break;
                        }
                        float _13158;
                        vec3 _16317;
                        float _17170;
                        _13158 = _17164;
                        _16317 = _17165;
                        _17170 = _17166;
                        uint _8088;
                        vec3 _13159;
                        float _13190;
                        float _14383;
                        uint _17024 = 0u;
                        for (;;)
                        {
                            if (!(_17024 < min(volumeData.lightCount, 16u)))
                            {
                                break;
                            }
                            vec3 _21555 = volumeData.lightPositionsEnd._m0[_17024].xyz - volumeData.lightPositionsStart._m0[_17024].xyz;
                            vec3 _14637 = _21812 - volumeData.lightPositionsStart._m0[_17024].xyz;
                            float _19449 = clamp((length(_14637 - (_21555 * clamp(dot(_14637, _21555) / dot(_21555, _21555), 0.0, 1.0))) * 0.0500000007450580596923828125) * volumeData.lightParams._m0[_17024].x, 0.0, 1.0);
                            float _14627 = smoothstep(0.0, 0.00999999977648258209228515625, volumeData.lightPositionsStart._m0[_17024].w) * (1.0 - smoothstep(0.00999999977648258209228515625, 0.20000000298023223876953125, volumeData.lightPositionsStart._m0[_17024].w));
                            float _6224;
                            if (_19449 < 1.0)
                            {
                                float _18732 = max(_17170, smoothstep(0.0, 1.0, 1.0 - clamp(volumeData.lightPositionsStart._m0[_17024].w + clamp(_19449 + (1.0 - clamp(length(_21812 - volumeData.lightPositionsEnd._m0[_17024].xyz) * 0.00999999977648258209228515625, 0.0, 1.0)), 0.0, 1.0), 0.0, 1.0)));
                                _13159 = mix(_16317, normalize(volumeData.lightPositionsStart._m0[_17024].xyz - volumeData.lightPositionsEnd._m0[_17024].xyz), vec3(_18732));
                                _13190 = _18732;
                                _6224 = (pow(1.0 - _19449, 64.0) * _14627) * 10.0;
                            }
                            else
                            {
                                _13159 = _16317;
                                _13190 = _17170;
                                _6224 = 0.0;
                            }
                            if (volumeData.lightPositionsEnd._m0[_17024].w > 0.0)
                            {
                                float _10369 = (1.0 - clamp(length(_14637) * 0.00999999977648258209228515625, 0.0, 1.0)) * _14627;
                                _14383 = max(_13158, max(_10369 * _10369, _6224));
                            }
                            else
                            {
                                _14383 = _13158;
                            }
                            _8088 = _17024 + 1u;
                            _13158 = _14383;
                            _16317 = _13159;
                            _17170 = _13190;
                            _17024 = _8088;
                            continue;
                        }
                        _13160 = _17168 | 1u;
                        _16318 = _13158;
                        _13620 = _17170;
                        _7689 = _16317;
                        break;
                    } while(false);
                    uint _25082 = uint(_20544[_17169]._m0.z);
                    bool _10670;
                    float _13171;
                    vec4 _13638;
                    float _16322;
                    do
                    {
                        vec3 _25172 = _21812 + ((normalize(_7689) * pow(_13620, 3.0)) * 20.0);
                        int _22667 = int(_25082);
                        vec3 _14659 = clamp((((_25172 - volumeData.volumeCenters._m0[_22667].xyz) * vec3(0.0500000007450580596923828125)) + vec3(16.0)) * vec3(0.03125), vec3(0.0), vec3(1.0));
                        vec3 _21496 = clamp(_14659, vec3(0.0), vec3(1.0));
                        uint _14093 = uint(volumeData.volumeParams._m0[_25082].z);
                        float _24256 = 34.0 * float(_14093);
                        _21496.x = (_24256 + (_21496.x * 32.0)) * 0.0018450184725224971771240234375;
                        vec4 _11488 = textureLod(sampler3D(_3482, _4038), _21496.xyz, 0.0);
                        vec2 _7715 = mix(_11488.xz, _11488.yw, vec2(volumeData.volumeParams._m0[_25082].y));
                        float _20594 = _7715.x;
                        float _6735 = _7715.y;
                        vec4 _13161;
                        _13161.w = _6735;
                        float _8284 = distance(_25172, _4987);
                        vec4 _18057;
                        if (_20594 > _6735)
                        {
                            vec4 _11249;
                            _11249.w = mix(_6735, _20594, smoothstep(10.0, 40.0, _8284));
                            _18057 = _11249;
                        }
                        else
                        {
                            _18057 = _13161.xyzw;
                        }
                        float _6666 = clamp(mix(_18057.w, -0.0500000007450580596923828125, _13620), 0.0, 1.0);
                        if (_6666 > 0.00999999977648258209228515625)
                        {
                            float _17821 = max(0.0, _8284 - min(20.0, abs(_7391.z - volumeData.volumeCenters._m0[_22667].z) * 2.0));
                            float _20846 = clamp(clamp((_6666 - 0.00999999977648258209228515625) * 1.01010096073150634765625, 0.0, 1.0), 0.0, 1.0) * volumeData.volumeDensityParams._m0[_25082].x;
                            float _22282 = clamp(_20846 + ((1.0 - clamp(distance(cameraData.cameraPosition, _25172) * 0.100000001490116119384765625, 0.0, 1.0)) * _20846), 0.0, 1.0);
                            vec3 _6617;
                            float _13166;
                            float _13695;
                            float _16320;
                            if (_6681)
                            {
                                vec3 _13162;
                                float _16319;
                                float _17173;
                                _13162 = _25172;
                                _16319 = 0.0;
                                _17173 = 1.0;
                                uint _8898;
                                vec3 _13165;
                                float _14084;
                                float _18362;
                                uint _17025 = 0u;
                                for (;;)
                                {
                                    bool _7959_ladder_break = false;
                                    do
                                    {
                                        if (!(_17025 < min(volumeData.dissipationCount, 5u)))
                                        {
                                            _7959_ladder_break = true;
                                            break;
                                        }
                                        if ((uint(volumeData.dissipationChannelMask._m0[_17025 >> uint(2)][_17025 & 3u]) & (1u << _14093)) == 0u)
                                        {
                                            _13165 = _13162;
                                            _14084 = _17173;
                                            _18362 = _16319;
                                            break;
                                        }
                                        float _10811 = volumeData.globalTime - volumeData.dissipationPoints._m0[_17025].w;
                                        vec3 _13164;
                                        float _16384;
                                        float _16482;
                                        if (_10811 < (volumeData.volumeParams._m0[_25082].x - 0.4000000059604644775390625))
                                        {
                                            float _13669 = distance(_13162, volumeData.dissipationPoints._m0[_17025].xyz);
                                            vec3 _13163;
                                            float _16383;
                                            float _16481;
                                            if (_13669 < 250.0)
                                            {
                                                float _16614 = pow(1.0 - smoothstep(0.0, 2.0, _10811), 128.0);
                                                float _13561;
                                                if (!_12666)
                                                {
                                                    _13561 = clamp((48.0 - _17821) * 0.02083333395421504974365234375, 0.0, 1.0) * (1.0 - smoothstep(0.0, 7.0, _10811));
                                                }
                                                else
                                                {
                                                    _13561 = _16319;
                                                }
                                                _13163 = mix(_13162, volumeData.dissipationPoints._m0[_17025].xyz, vec3(((1.0 - smoothstep(100.0, 250.0, _13669)) * step(_10811 * 1250.0, _13669)) * (1.0 - _16614)));
                                                _16383 = min(_17173, max(smoothstep(200.0, 240.0, _13669 + (_16614 * 250.0)) + pow(smoothstep(0.5, 5.0, _10811), 1.7999999523162841796875), _13561));
                                                _16481 = _13561;
                                            }
                                            else
                                            {
                                                _13163 = _13162;
                                                _16383 = _17173;
                                                _16481 = _16319;
                                            }
                                            _13164 = _13163;
                                            _16384 = _16383;
                                            _16482 = _16481;
                                        }
                                        else
                                        {
                                            _13164 = _13162;
                                            _16384 = _17173;
                                            _16482 = _16319;
                                        }
                                        _13165 = _13164;
                                        _14084 = _16384;
                                        _18362 = _16482;
                                        break;
                                    } while(false);
                                    if (_7959_ladder_break)
                                    {
                                        break;
                                    }
                                    _8898 = _17025 + 1u;
                                    _13162 = _13165;
                                    _16319 = _18362;
                                    _17173 = _14084;
                                    _17025 = _8898;
                                    continue;
                                }
                                _13166 = _17173;
                                _16320 = _16319;
                                _13695 = mix(_22282 * 0.0199999995529651641845703125, _22282, _17173);
                                _6617 = _13162;
                            }
                            else
                            {
                                _13166 = 1.0;
                                _16320 = 0.0;
                                _13695 = _22282;
                                _6617 = _25172;
                            }
                            float _20018 = cameraData.time * renderParams.timeScale;
                            vec3 _11676 = _14659 - vec3(0.5);
                            vec3 _11773 = _11676 * 7.0;
                            float _11477 = _11773.z;
                            float _9119 = _20018 * 0.5;
                            float _7388 = (_20018 * 0.039999999105930328369140625) + ((((0.20000000298023223876953125 + ((sin(_11477 * 5.0) + 0.5) * 0.1500000059604644775390625)) * sin(_9119 + 0.5)) * sin((_20018 * 0.1870000064373016357421875) + 0.5)) * 0.20000000298023223876953125);
                            float _17176 = sin(_7388);
                            float _17392 = cos(_7388);
                            vec2 _23933 = _11773.xy * mat2(vec2(_17392, -_17176), vec2(_17176, _17392));
                            float _16177 = _23933.x;
                            vec3 _21584 = _11773;
                            _21584.x = _16177;
                            float _6689 = _23933.y;
                            float _14460 = _20018 + (sin(_9119) * 0.0199999995529651641845703125);
                            vec2 _24075 = _21584.xz + (vec2(sin(_14460 + (_11477 * 2.7000000476837158203125)), cos(_14460 + (_16177 * 2.7000000476837158203125))) * 0.0500000007450580596923828125);
                            float _10134 = _24075.x;
                            float _10753 = _24075.y;
                            vec3 _22426 = vec3(_10134, _6689, _10753);
                            float _8651 = _10753 + ((sin((_10134 * 3.0) + (_20018 * 0.3499999940395355224609375)) + sin((_6689 * 2.8399999141693115234375) + (_20018 * 0.23499999940395355224609375))) * 0.0500000007450580596923828125);
                            _22426.z = _8651;
                            vec3 _10825 = _22426 * renderParams.noise1Scale;
                            vec3 _9986 = vec3(2.0, 2.0, 4.5) * (_20018 * 0.100000001490116119384765625);
                            vec3 _13917 = cameraData.rightVector * 0.20000000298023223876953125;
                            vec3 _13918 = _19298 * 0.20000000298023223876953125;
                            vec4 _16434 = vec4(renderParams.noisePower);
                            vec4 _21178 = pow(textureLod(sampler3D(_3913, _4258), ((abs(_10825) - _9986) * 0.070000000298023223876953125).xyz, 0.0), _16434);
                            vec4 _6422 = vec4(renderParams.noiseColorA);
                            vec4 _7261 = vec4(renderParams.noiseColorB);
                            vec4 _15548 = vec4(renderParams.noiseMixFactor);
                            vec4 _24110 = mix(mix(_6422, _7261, _21178), mix(vec4(0.25), vec4(-1.5), _21178), _15548);
                            float _11091 = (_24110.x + (_24110.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 _17266 = pow(textureLod(sampler3D(_3913, _4258), ((abs(_10825 + _13917) - _9986) * 0.070000000298023223876953125).xyz, 0.0), _16434);
                            vec4 _19782 = mix(mix(_6422, _7261, _17266), mix(vec4(0.25), vec4(-1.5), _17266), _15548);
                            vec4 _17267 = pow(textureLod(sampler3D(_3913, _4258), ((abs(_10825 + _13918) - _9986) * 0.070000000298023223876953125).xyz, 0.0), _16434);
                            vec4 _19783 = mix(mix(_6422, _7261, _17267), mix(vec4(0.25), vec4(-1.5), _17267), _15548);
                            float _20361 = 0.800000011920928955078125 / renderParams.noise1Scale;
                            vec3 _6513 = normalize(vec3(_11091 - ((_19783.x + (_19783.y * 0.949999988079071044921875)) * 4.599999904632568359375), _11091 - ((_19782.x + (_19782.y * 0.949999988079071044921875)) * 4.599999904632568359375), _20361));
                            mat4 _21990 = mat4(vec4(cameraData.viewMatrix._m0[0].x, cameraData.viewMatrix._m0[1].x, cameraData.viewMatrix._m0[2].x, cameraData.viewMatrix._m0[3].x), vec4(cameraData.viewMatrix._m0[0].y, cameraData.viewMatrix._m0[1].y, cameraData.viewMatrix._m0[2].y, cameraData.viewMatrix._m0[3].y), vec4(cameraData.viewMatrix._m0[0].z, cameraData.viewMatrix._m0[1].z, cameraData.viewMatrix._m0[2].z, cameraData.viewMatrix._m0[3].z), vec4(cameraData.viewMatrix._m0[0].w, cameraData.viewMatrix._m0[1].w, cameraData.viewMatrix._m0[2].w, cameraData.viewMatrix._m0[3].w));
                            float _16361 = _11676.z;
                            vec3 _20801 = (_11773 + ((((_21990 * vec4((_6513 + vec3(0.0, 0.0, 1.0)).xyz, 0.0)).xyz * pow(_11091, 0.100000001490116119384765625)) * renderParams.normalDetailScale) * 0.20000000298023223876953125)) + (vec3(2.0, 2.0, 4.5) * ((((_11091 - 1.0) * 0.20000000298023223876953125) * renderParams.normalDetailScale) * _16361));
                            _20801.x = _20801.x + (sin(_8651 + (_20018 * 0.25)) * 0.0500000007450580596923828125);
                            vec3 _19465 = _20801 * renderParams.noise2Scale;
                            vec4 _11131 = pow(textureLod(sampler3D(_3913, _4258), (_19465 * 0.070000000298023223876953125).xyz, 0.0), _16434);
                            vec4 _19784 = mix(mix(_6422, _7261, _11131), mix(vec4(0.25), vec4(-1.5), _11131), _15548);
                            float _11093 = (_19784.x + (_19784.y * 0.949999988079071044921875)) * 4.599999904632568359375;
                            vec4 _17268 = pow(textureLod(sampler3D(_3913, _4258), ((_19465 + _13917) * 0.070000000298023223876953125).xyz, 0.0), _16434);
                            vec4 _19785 = mix(mix(_6422, _7261, _17268), mix(vec4(0.25), vec4(-1.5), _17268), _15548);
                            vec4 _17269 = pow(textureLod(sampler3D(_3913, _4258), ((_19465 + _13918) * 0.070000000298023223876953125).xyz, 0.0), _16434);
                            vec4 _19786 = mix(mix(_6422, _7261, _17269), mix(vec4(0.25), vec4(-1.5), _17269), _15548);
                            float _17672 = renderParams.detailNoiseInfluence * (dot(_15861, cameraData.viewDirection) * clamp(distance(_6617, cameraData.cameraPosition) * 0.004999999888241291046142578125, 0.0, 1.0));
                            float _13168 = (mix(0.949999988079071044921875, clamp(_11091, 0.0, 1.0), renderParams.noise1Influence) + mix(0.949999988079071044921875, clamp(_11093, 0.0, 1.0), _17672 * 0.25)) + renderParams.noiseOffset;
                            float _11622;
                            if (volumeData.volumeDensityParams._m0[_25082].w < 1.0)
                            {
                                float _14676 = clamp(volumeData.volumeDensityParams._m0[_25082].w, 9.9999997473787516355514526367188e-05, 0.99989998340606689453125);
                                float _8420 = smoothstep(0.0, 0.800000011920928955078125, _14676);
                                float _14552 = smoothstep(0.20000000298023223876953125, 1.0, _14676);
                                float _12510;
                                if (_8420 == _14552)
                                {
                                    _12510 = _13695 * _14676;
                                }
                                else
                                {
                                    vec3 _23052 = _11676;
                                    _23052.z = _16361 * 1.2000000476837158203125;
                                    _12510 = _13695 * clamp(smoothstep(_8420, _14552, clamp(length(_23052), 0.0, 1.0)), 0.0, 1.0);
                                }
                                _11622 = _12510;
                            }
                            else
                            {
                                _11622 = _13695;
                            }
                            float _13440 = mix(_11622 - (1.0 - _13168), _11622 + _13168, _11622) * clamp((volumeData.volumeDensityParams._m0[_25082].x * volumeData.volumeDensityParams._m0[_25082].w) * 8.0, 0.0, 1.0);
                            if (_13440 < 9.9999997473787516355514526367188e-05)
                            {
                                _13171 = _16316;
                                _16322 = _17161;
                                _13638 = _17163;
                                _10670 = false;
                                break;
                            }
                            vec3 _21941 = normalize(_11676) * mix(1.0, 0.0, clamp(_16320, 0.0, 1.0));
                            vec4 _13056 = _21990 * vec4(((vec4(_21941.xyz, 0.0).xyzw * _21990).xyz + ((vec3((_6513.xy * renderParams.noise1Influence) + ((normalize(vec3(_11093 - ((_19786.x + (_19786.y * 0.949999988079071044921875)) * 4.599999904632568359375), _11093 - ((_19785.x + (_19785.y * 0.949999988079071044921875)) * 4.599999904632568359375), _20361)) * mix(0.5, 1.0, clamp(_11091 - 0.5, 0.0, 1.0))).xy * (_17672 * 1.5)), 0.0) * renderParams.normalPerturbScale) * mix(1.0, 2.0, clamp((200.0 - distance(_6617, volumeData.volumeCenters._m0[_22667].xyz)) * 0.004999999888241291046142578125, 0.0, 1.0)))).xyz, 0.0);
                            vec3 _19633 = _13056.xyz;
                            vec3 _16794 = clamp(clamp(mix(_11676 * dot(_21941, _19633), normalize(_19633 + vec3(0.0, 0.0, 0.5)) * length(_11676), vec3(0.20000000298023223876953125)) + vec3(0.5), vec3(0.02999999932944774627685546875), vec3(0.9700000286102294921875)), vec3(0.0), vec3(1.0));
                            _16794.x = (_24256 + (_16794.x * 32.0)) * 0.0018450184725224971771240234375;
                            vec4 _13570 = textureLod(sampler3D(_4426, _4038), _16794.xyz, 0.0);
                            float _15562 = dot(mix(_21941, _19633, vec3(renderParams.phaseBlend)), lightingData.sunDirection.xyz);
                            float _8124 = pow(clamp((_15562 * 0.800000011920928955078125) + 0.20000000298023223876953125, 0.0, 1.0), 1.5) + pow(clamp((_15562 * 1.39999997615814208984375) - 0.5, 0.0, 1.0), 3.0);
                            float _11276;
                            if (_8124 > 0.0)
                            {
                                _11276 = _8124 * _13570.w;
                            }
                            else
                            {
                                _11276 = _8124;
                            }
                            float _16848 = _13570.x;
                            float _15575 = _13570.y;
                            float _21521 = _13570.z;
                            float _16616 = max(_16848, max(_15575, _21521));
                            float _12973 = _16616 - min(_16848, min(_15575, _21521));
                            vec3 _6554 = vec3(0.0);
                            _6554.z = _16616;
                            vec3 _20312;
                            if (_12973 != 0.0)
                            {
                                float _20365 = _12973 / _16616;
                                vec3 _18851 = (_6554.zzz - _13570.xyz) / vec3(_12973);
                                vec3 _18381 = _18851.xyz - _18851.zxy;
                                vec2 _10890 = _18381.xy + vec2(2.0, 4.0);
                                vec3 _20311;
                                if (_16848 >= _16616)
                                {
                                    _20311 = vec3(_18381.z, _20365, _16616);
                                }
                                else
                                {
                                    vec3 _12511;
                                    if (_15575 >= _16616)
                                    {
                                        _12511 = vec3(_10890.x, _20365, _16616);
                                    }
                                    else
                                    {
                                        _12511 = vec3(_10890.y, _20365, _16616);
                                    }
                                    _20311 = _12511;
                                }
                                vec3 _11028 = _20311;
                                _11028.x = fract(_20311.x * 0.16666667163372039794921875);
                                _20312 = _11028;
                            }
                            else
                            {
                                _20312 = _6554;
                            }
                            float _20353 = clamp(_20312.y * 1.10000002384185791015625, 0.0, 1.0);
                            vec3 _14328;
                            if (_20353 != 0.0)
                            {
                                float _23217 = _20312.x * 6.0;
                                float _10654 = floor(_23217);
                                float _19983 = _20312.z * (1.0 - _20353);
                                float _17997 = _23217 - _10654;
                                float _10563 = _20312.z * (1.0 - (_20353 * _17997));
                                float _23320 = _20312.z * (1.0 - (_20353 * (1.0 - _17997)));
                                vec3 _12516;
                                if (_10654 == 0.0)
                                {
                                    _12516 = vec3(_20312.z, _23320, _19983);
                                }
                                else
                                {
                                    vec3 _12515;
                                    if (_10654 == 1.0)
                                    {
                                        _12515 = vec3(_10563, _20312.z, _19983);
                                    }
                                    else
                                    {
                                        vec3 _12514;
                                        if (_10654 == 2.0)
                                        {
                                            _12514 = vec3(_19983, _20312.z, _23320);
                                        }
                                        else
                                        {
                                            vec3 _12513;
                                            if (_10654 == 3.0)
                                            {
                                                _12513 = vec3(_19983, _10563, _20312.z);
                                            }
                                            else
                                            {
                                                vec3 _12512;
                                                if (_10654 == 4.0)
                                                {
                                                    _12512 = vec3(_23320, _19983, _20312.z);
                                                }
                                                else
                                                {
                                                    _12512 = vec3(_20312.z, _19983, _10563);
                                                }
                                                _12513 = _12512;
                                            }
                                            _12514 = _12513;
                                        }
                                        _12515 = _12514;
                                    }
                                    _12516 = _12515;
                                }
                                _14328 = _12516;
                            }
                            else
                            {
                                _14328 = _20312.zzz;
                            }
                            vec3 _24094 = (((((((normalize(_14328 + vec3(0.001000000047497451305389404296875)) * min(length(_14328), 4.0)) * clamp(1.0 - min(0.25, _13440), 0.0, 1.0)) * clamp(1.0 - (((_11622 * 2.400000095367431640625) - _13440) * renderParams.densityContrast), 0.0, 1.0)) * _13168) * (0.75 + (_11276 * 0.25))) * (1.0 + (_13056.z * 0.5))) * renderParams.baseColorIntensity) + ((lightingData.sunColor.xyz * ((0.5 * _11276) * (1.0 - _13620))) * renderParams.sunColorIntensity);
                            vec3 _23773 = _24094 * volumeData.volumeColors._m0[_25082].xyz;
                            vec3 _16437 = (mix(_24094, _23773 * (dot(_24094.xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125)) / dot((_23773 + vec3(0.001000000047497451305389404296875)).xyz, vec3(0.2125000059604644775390625, 0.7153999805450439453125, 0.07209999859333038330078125))), vec3(0.5 * (1.0 - volumeData.volumeDensityParams._m0[_25082].z))) * mix(vec3(1.0), normalize(renderParams.colorTint + vec3(0.00999999977648258209228515625)) * 1.73199999332427978515625, vec3(clamp(0.5 + (_13440 * 6.0), 0.0, 1.0)))).xyz;
                            vec3 _21314 = mix(_16437, _16437 * _13166, vec3(0.60000002384185791015625)).xyz;
                            float _22661 = smoothstep(0.0, 0.20000000298023223876953125, _13440 + 0.300000011920928955078125) * (((clamp((renderParams.godrayFalloff - _17821) / renderParams.godrayFalloff, 0.0, 1.0) * _11622) * 6.0) * renderParams.godrayIntensity);
                            float _17657 = smoothstep(0.0, 0.20000000298023223876953125 / (renderParams.alphaScale * mix(0.5, 2.0, _17163.w)), _13440);
                            vec4 _22502 = vec4(((_21314 + ((_21314 * vec3(8.0, 4.0, 0.0)) * _16318)) * mix(1.0, 0.85000002384185791015625, clamp(_16320 * 20.0, 0.0, 1.0))) * _17657, _17657);
                            float _13170;
                            vec4 _16321;
                            float _17026;
                            float _17178;
                            _13170 = _16316;
                            _16321 = _17163;
                            _17178 = _17161;
                            _17026 = _13244 * 0.25;
                            float _11922;
                            vec4 _19917;
                            float _23567;
                            float _25060;
                            for (;;)
                            {
                                if (!(_17026 >= 1.0))
                                {
                                    break;
                                }
                                _23567 = _17178 + _22661;
                                _19917 = _16321 + (_22502 * (1.0 - _16321.w));
                                _11922 = _13170 + _11276;
                                _25060 = _17026 - 1.0;
                                _13170 = _11922;
                                _16321 = _19917;
                                _17178 = _23567;
                                _17026 = _25060;
                                continue;
                            }
                            _13171 = _13170 + (_11276 * _17026);
                            _16322 = _17178 + (_22661 * _17026);
                            _13638 = _16321 + (_22502 * ((1.0 - _16321.w) * _17026));
                            _10670 = (_17657 + _22661) > 0.0;
                            break;
                        }
                        _13171 = _16316;
                        _16322 = _17161;
                        _13638 = _17163;
                        _10670 = false;
                        break;
                    } while(false);
                    _20544[_17169] = _20544[_17169];
                    bool _21169;
                    if (_10670)
                    {
                        _21169 = !_13157;
                    }
                    else
                    {
                        _21169 = false;
                    }
                    vec3 _14401 = mix(_17023, _21812, bvec3(_21169));
                    if (_13638.w > 0.990999996662139892578125)
                    {
                        vec4 _23483 = _13638;
                        _23483.w = 1.0;
                        _13173 = _21812;
                        _16325 = _14401;
                        _17185 = _13171;
                        _17188 = _16322;
                        _17189 = _23483;
                        _16865 = true;
                        _7958_ladder_break = true;
                        break;
                    }
                    _13172 = _21169 ? true : _13157;
                    _16323 = _13171;
                    _17180 = _16322;
                    _17181 = _13638;
                    _17182 = _16318;
                    _17183 = _7689;
                    _17184 = _13620;
                    _14892 = _13160;
                    _18363 = _14401;
                    break;
                } while(false);
                if (_7958_ladder_break)
                {
                    break;
                }
                _8899 = _17169 + 1u;
                _13157 = _13172;
                _16316 = _16323;
                _17161 = _17180;
                _17163 = _17181;
                _17164 = _17182;
                _17165 = _17183;
                _17166 = _17184;
                _17168 = _14892;
                _17169 = _8899;
                _17023 = _18363;
                continue;
            }
            if (_16865)
            {
                _13175 = _13173;
                _16327 = _16325;
                _17192 = _17185;
                _12756 = _17188;
                _14229 = _17189;
                break;
            }
            _13174 = _13173;
            _16326 = _16325;
            _17190 = _17185;
            _17191 = _17188;
            _16483 = _17189;
        }
        else
        {
            _13174 = _13156;
            _16326 = _16315;
            _17190 = _17151;
            _17191 = _17153;
            _16483 = _17154;
        }
        _13175 = _13174;
        _16327 = _16326;
        _17192 = _17190;
        _12756 = _17191;
        _14229 = _16483;
        break;
    } while(false);
    float _23125 = pow(clamp(dot(normalize(_15861), lightingData.sunDirection.xyz), 0.0, 1.0), 4.0) * 0.25;
    float _19877 = clamp(_12756 - (_14229.w * 0.20000000298023223876953125), 0.0, 1.0);
    vec4 _19214 = mix(vec4(_14229.xyz * mix(1.0, 0.0, _19877), _14229.w + _19877), _14229, bvec4(renderParams.godrayIntensity == 0.0));
    vec3 _22768 = _19214.xyz * (vec3(1.0) + ((pow(lightingData.sunColor.xyz, vec3(2.0)) * (((_23125 + (pow(_23125, 50.0) * 8.0)) * mix(1.0, 0.0, pow(_14229.w, 0.5))) * _14229.w)) * (_17192 * renderParams.rimLightIntensity)));
    vec4 _23714 = _19214;
    _23714.x = _22768.x;
    _23714.y = _22768.y;
    _23714.z = _22768.z;
    float _7321 = _19214.w;
    if (_7321 < 9.9999997473787516355514526367188e-06)
    {
        discard;
    }
    float _13311 = screenData.logDepthFar - screenData.logDepthNear;
    float _9068 = (((log(dot(cameraData.viewDirection.xyz, _16327.xyz - cameraData.cameraPosition.xyz)) - screenData.logDepthNear) / _13311) * 2.0) - 1.0;
    float _11137 = (((log(dot(cameraData.viewDirection.xyz, _13175.xyz - cameraData.cameraPosition.xyz)) - screenData.logDepthNear) / _13311) * 2.0) - 1.0;
    vec4 _13176;
    vec4 _16328;
    vec4 _17193;
    _13176 = vec4(0.0);
    _16328 = vec4(0.0);
    _17193 = vec4(0.0);
    int _10763;
    vec4 _20077;
    vec4 _22374;
    vec4 _24741;
    int _17027 = 0;
    for (;;)
    {
        if (!(_17027 < 4))
        {
            break;
        }
        _10763 = _17027 + 1;
        float _3840 = 0.25 * float(_10763);
        float _6948 = mix(_9068, _11137, _3840);
        float _12308 = -log(1.0 - clamp(_7321 * _3840, 9.9999997473787516355514526367188e-06, 0.99989998340606689453125));
        float _22961 = _6948 * _6948;
        float _14216 = _22961 * _22961;
        _24741 = _13176 + vec4(_12308, 0.0, 0.0, 0.0);
        _20077 = _16328 + vec4(vec2(_6948, _22961) * _12308, 0.0, 0.0);
        _22374 = _17193 + (vec4(_22961 * _6948, _14216, _14216 * _6948, _14216 * _22961) * _12308);
        _13176 = _24741;
        _16328 = _20077;
        _17193 = _22374;
        _17027 = _10763;
        continue;
    }
    _3711 = _13176;
    _3338 = _16328;
    _3339 = _17193;
    _3340 = _23714;
    _3341 = vec4(_9068, _11137, 0.0, 0.0);
    _3342 = _7321;
}