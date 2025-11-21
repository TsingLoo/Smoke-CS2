Shader "Unlit/SmokeMask"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        //string here could be the default value
        _SmokeTex3D ("Smoke 3D Texture", 3D) = "" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        //ZTest Always
        ZWrite Off
        Cull Off
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

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
            
            struct appdata
            {
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            StructuredBuffer<SmokeVolume> _SmokeVolumes;
            int _SmokeCount;
            Texture3D _SmokeTex3D;
            SamplerState sampler_SmokeTex3D;

            float _VolumeSize = 640.0;
            static const float _VoxelResolution = 32.0;
            static const float _AtlasSliceWidth = 34.0;
            static const float _AtlasTextureWidth = 542.0;
            static const uint _MaxDDASteps = 32;
            
            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4x4 _InvVP;
            float3 _CameraPosCS;
        
            bool TraverseVoxels(
                float3 startPos,
                float3 rayDir,
                float maxDist,
                float3 volumeCenter,
                int volumeIndex
            )
            {
                float halfVolumeSize = _VolumeSize * 0.5;
                float voxelSize = _VolumeSize / _VoxelResolution;
                float worldToVoxel = 1.0 / voxelSize;
                float voxelToUVW = 1.0 / _VoxelResolution;
                float maxVoxelIndex = _VoxelResolution - 1.0;
                float atlasUNorm = 1.0 / _AtlasTextureWidth;
                
                float3 localPos = (startPos - volumeCenter) + halfVolumeSize;
                
                float3 voxelPos = localPos * worldToVoxel;
                voxelPos = clamp(voxelPos, 0.0, maxVoxelIndex);
                
                // DDA Init
                int3 currentVoxel = int3(floor(voxelPos));
                int3 voxelStep = int3(sign(rayDir));
                
                float3 rayStepSize = abs(length(rayDir) / rayDir);
                
                float3 stepDir = float3(voxelStep);
                float3 tDelta = ((stepDir * (float3(currentVoxel) - voxelPos)) + (stepDir * 0.5) + 0.5) * rayStepSize;
                
                [loop]
                for (uint step = 0; step < _MaxDDASteps; step++)
                {
                    float3 voxelFloat = float3(currentVoxel);
                    float3 uvw = voxelFloat * voxelToUVW;
                    
                    // Check Bound
                    bool inBounds = all(uvw >= 0.0) && all(uvw <= 1.0);
                    if (!inBounds)
                        break;
                    
                    // currently using dumped CS2 data
                    float3 sampleUVW_local = float3(uvw.x, uvw.z, uvw.y);
                    
                    float adjustedU = ((_AtlasSliceWidth * float(volumeIndex)) + (sampleUVW_local.x * _VoxelResolution)) * atlasUNorm;
                    float3 sampleUVW = float3(adjustedU, sampleUVW_local.y, sampleUVW_local.z);
                    
                    float4 smokeData = _SmokeTex3D.SampleLevel(sampler_SmokeTex3D, sampleUVW, 0);
                    
                    if (any(smokeData.xyzw > 0.0))
                    {
                        return true;
                    }
                    
                    float distTraveled = length((voxelFloat * voxelSize) - localPos);
                    if (distTraveled > maxDist)
                    {
                        break;
                    }
                    
                    // DDA raymarching 
                    float3 mask = float3(
                        (tDelta.x <= tDelta.y && tDelta.x <= tDelta.z) ? 1.0 : 0.0,
                        (tDelta.y <= tDelta.x && tDelta.y <= tDelta.z) ? 1.0 : 0.0,
                        (tDelta.z <= tDelta.x && tDelta.z <= tDelta.y) ? 1.0 : 0.0
                    );
                    
                    tDelta += mask * rayStepSize;
                    currentVoxel += int3(mask) * voxelStep;
                }
                
                return false;
            }
            
            v2f vert (appdata input)
            {
                v2f output;
                float2 uv = float2((input.vertexID << 1) & 2, input.vertexID & 2);
                output.positionCS  = float4(uv * 2.0 - 1.0, 0.0, 1.0);
                output.uv = uv;

                #if UNITY_UV_STARTS_AT_TOP
                    output.uv.y = 1.0 - output.uv.y;
                #endif
                
                return output;
            }

            float4 frag (v2f input) : SV_Target
            {
                //return float4(1,1,1,1);
                float rawDepth = SampleSceneDepth(input.uv);

                
                // #if defined(UNITY_REVERSED_Z)
                //     rawDepth = 1.0 - rawDepth;
                // #endif
                //return float4(rawDepth,rawDepth,rawDepth, 1);
                //  if (rawDepth <= 0.0001 || rawDepth >= 0.9999)
                //  {
                //      // Invalid Depth
                //      return float4(1, 0, 0, 1);  // 红色警告
                //  }
                // return float4(rawDepth,rawDepth,rawDepth, 1);
                
                float4 ndc = float4(
                    input.uv.x * 2.0 - 1.0,
                    (1.0 - input.uv.y) * 2.0 - 1.0,
                    rawDepth,
                    1.0
                );
                
                float4 worldPos = mul(_InvVP, ndc);
                float3 worldPosition = worldPos.xyz / worldPos.w;

                float3 cameraPos = _CameraPosCS;
                float3 rayDir = normalize(worldPosition - cameraPos);
                float maxDist = length(worldPosition - cameraPos);

                //return float4(maxDist / 20.0, 0, 0, 1);
                
                uint smokeMask = 0;
                // iterate through smokes
                for (int i = 0; i < _SmokeCount; i++)
                {
                    SmokeVolume smoke = _SmokeVolumes[i];
                    if (smoke.volumeIndex < 0) continue;

                    float3 invDir = 1.0 / (rayDir + 0.0001);
                    float3 t0 = (smoke.aabbMin - cameraPos) * invDir;
                    float3 t1 = (smoke.aabbMax - cameraPos) * invDir;
                    
                    float3 tNear = min(t0, t1);
                    float3 tFar = max(t0, t1);
                    
                    float tMin = max(max(tNear.x, tNear.y), tNear.z);
                    float tMax = min(min(tFar.x, tFar.y), tFar.z);


                    //return float4(1,1,0,1);   
                    
                    // no intersection
                    if (tMin > tMax || tMax < 0.0) 
                        continue;

                    //return float4(1,1,0,1);   
                    
                    float rayStart = max(0.0, tMin);
                    
                    // maxDist is the distance from camera to the object in the scene
                    // exceed means is behind the object
                    if (rayStart >= maxDist) 
                        continue;
                    
                    //return float4(1,1,0,1);   
                    
                    //return float4(1,1,0,1);   
                    // the position hit the AABB box
                    
                    float3 startPos = cameraPos + rayDir * rayStart;
                    float maxTraverseDist = min(tMax, maxDist) - rayStart;

                                                                
                    //return float4(1,1,0,1);  
                    
                    if (TraverseVoxels(
                        startPos,
                        rayDir,
                        maxTraverseDist,
                        smoke.position,
                        smoke.volumeIndex
                    ))
                    {
                        return float4(0,1,1,1);
                        smokeMask |= (1u << i);
                    }
                }
                
                if (smokeMask == 0)
                    discard;  // this fragment is not in smoke


                //return float4(1,1,1,1);
                return float4(float(smokeMask), 0, 0, 1);
            }
            ENDHLSL
        }
    }
}
