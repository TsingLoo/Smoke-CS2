Shader "Smoke/ShadowProxy"
{
    Properties
    {
        _ShadowDensityThreshold("Shadow Density Threshold", Float) = 0.1
        _MaxShadowSteps("Max Shadow Steps", Integer) = 16
        
        _DetailNoiseTex("Detail Noise Texture", 3D) = "white" {}
        _DetailNoiseSpeed("Detail Noise Speed", Float) = 0.1
        _DetailNoiseUVWScale("Detail Noise UVW Scale", Float) = 1.0
        _DetailNoiseStrength("Detail Noise Strength", Float) = 0.3
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_shadowcaster
            #pragma target 4.5
            
            #define LerpWhiteTo(color, amount) lerp(float3(1,1,1), color, amount)
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Assets/Shaders/Include/Utils.hlsl"
            #include "Assets/Shaders/Include/Defines.hlsl"
            
            StructuredBuffer<SmokeVolume> _SmokeVolumes;
            int _SmokeCount;
            int _MyVolumeIndex;
            
            Texture3D _SmokeTex3D;
            SamplerState sampler_SmokeTex3D;
            
            Texture3D _DetailNoiseTex;
            SamplerState sampler_DetailNoiseTex;
            
            float _VolumeSize;
            float _ShadowDensityThreshold;
            uint _MaxShadowSteps;
            
            float _DetailNoiseSpeed;
            float _DetailNoiseUVWScale;
            float _DetailNoiseStrength;
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
            };
            
            float4 GetShadowPositionHClip(Attributes input, out float3 lightDirWS)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    lightDirWS = normalize(_LightPosition - positionWS);
                #else
                    lightDirWS = _MainLightPosition.xyz;
                #endif
                
                float4 positionCS = TransformWorldToHClip(
                    ApplyShadowBias(positionWS, normalWS, lightDirWS)
                );
                
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                
                return positionCS;
            }
            
            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = GetShadowPositionHClip(input, output.lightDir);
                return output;
            }
            
            half4 ShadowPassFragment(Varyings input) : SV_Target
            {
                float3 lightDir = input.lightDir;
                float time = _Time.y;
                
                bool hasShadow = false;
                
                if (_MyVolumeIndex >= 0 && _MyVolumeIndex < _SmokeCount)
                {
                    SmokeVolume smoke = _SmokeVolumes[_MyVolumeIndex];
                    
                    float3 rayOrigin = input.positionWS;
                    float3 rayDir = -lightDir;  // 反向追踪
                    
                    float tMin, tMax;
                    if (AABBIntersect(
                        smoke.aabbMin,
                        smoke.aabbMax,
                        rayOrigin,
                        rayDir,
                        tMin,
                        tMax
                    ))
                    {
                        if (tMin < 0.0) tMin = 0.0;
                        
                        float3 startPos = rayOrigin + rayDir * tMin;
                        float maxTraverseDist = tMax - tMin;
                        
                        if (TraverseVoxelsWithNoise(
                            _SmokeTex3D,
                            sampler_SmokeTex3D,
                            _DetailNoiseTex,
                            sampler_DetailNoiseTex,
                            startPos,
                            rayDir,
                            maxTraverseDist,
                            smoke.position,
                            smoke.volumeIndex,
                            _VolumeSize,
                            VOLUME_RESOLUTION,
                            _MaxShadowSteps,
                            time,
                            _DetailNoiseSpeed,
                            _DetailNoiseUVWScale,
                            _DetailNoiseStrength,
                            _ShadowDensityThreshold
                        ))
                        {
                            hasShadow = true;
                        }
                    }
                }
                
                if (!hasShadow)
                    discard;
                
                return 0;
            }
            ENDHLSL
        }
    }
}