Shader "URP/VolumePreview"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("3D Texture", 3D) = "white" {}
        _Alpha ("Alpha Multiplier", Range(0, 10)) = 1.0
        _StepSize ("Step Size", Range(0.001, 0.1)) = 0.01
        _Threshold ("Threshold", Range(0, 1)) = 0.1
        _MaxSteps ("Max Steps", Range(32, 512)) = 128
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent" 
            "RenderType" = "Transparent" 
        }

        Pass
        {
            Name "VolumeRaymarching"
            
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Front  // 渲染背面，这样可以看到体积内部

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 positionOS : TEXCOORD1;  // 对象空间位置 [0,1] 范围
            };

            TEXTURE3D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float _Alpha;
                float _StepSize;
                float _Threshold;
                float _MaxSteps;
            CBUFFER_END

            // 计算射线与AABB [0,1]^3 的交点
            // 返回 (tNear, tFar)，如果没有交点则 tNear > tFar
            float2 RayBoxIntersection(float3 rayOrigin, float3 rayDir, float3 boxMin, float3 boxMax)
            {
                float3 invDir = 1.0 / rayDir;
                
                float3 t0 = (boxMin - rayOrigin) * invDir;
                float3 t1 = (boxMax - rayOrigin) * invDir;
                
                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);
                
                float tNear = max(max(tMin.x, tMin.y), tMin.z);
                float tFar = min(min(tMax.x, tMax.y), tMax.z);
                
                return float2(tNear, tFar);
            }

            Varyings vert (Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // 将本地坐标 [-0.5, 0.5] 映射到 [0, 1] 用于 UVW 采样
                output.positionOS = input.positionOS.xyz + 0.5;
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                // 获取相机在对象空间的位置，映射到 [0,1] 范围
                float3 cameraWS = GetCameraPositionWS();
                float3 cameraOS = TransformWorldToObject(cameraWS) + 0.5;
                
                // 计算射线方向（从相机指向当前片元，即从前向后）
                float3 rayDir = normalize(input.positionOS - cameraOS);
                
                // 计算射线与 [0,1] AABB 的交点
                float2 tHit = RayBoxIntersection(cameraOS, rayDir, float3(0,0,0), float3(1,1,1));
                
                // 如果没有有效交点，丢弃
                if (tHit.x > tHit.y) discard;
                
                // 确保 tNear 不小于0（相机在盒子外时从表面开始）
                float tNear = max(tHit.x, 0.0);
                float tFar = tHit.y;
                
                // 射线起点
                float3 rayStart = cameraOS + rayDir * tNear;
                
                // 初始化累积颜色
                float4 acc = float4(0, 0, 0, 0);
                
                // 计算步数
                float rayLength = tFar - tNear;
                int steps = (int)min(rayLength / _StepSize, _MaxSteps);
                
                float3 p = rayStart;
                
                // Raymarching 循环
                for (int s = 0; s < steps; s++)
                {
                    // 采样 3D 纹理
                    float4 col = SAMPLE_TEXTURE3D_LOD(_MainTex, sampler_MainTex, p, 0);

                    if (col.a > _Threshold)
                    {
                        float density = col.a * _Alpha * _StepSize;
                        float4 src = float4(col.rgb * density, density);
                        
                        // 标准 Front-to-Back 混合
                        acc = acc + src * (1.0 - acc.a);
                    }

                    // 步进
                    p += rayDir * _StepSize;

                    // 提前退出优化
                    if (acc.a >= 0.95) break;
                }

                // 如果累积透明度太低，可以选择丢弃
                if (acc.a < 0.001) discard;

                return acc;
            }
            ENDHLSL
        }
    }
    
    FallBack Off
}
