using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

enum VoxelStatus
{
    Empty,
    Solid,
    Smoked
}

public class VoxelWorld : MonoBehaviour
{
    [SerializeField] private Transform VoxelOrigin;
    [SerializeField] private Vector3 WorldSize;
    [SerializeField] private float VoxelLength;

    [SerializeField] private LayerMask SolidLayerMask;

    private float CollisionEpsilon = 0.001f;
    
    [Header("Compute")]
    [SerializeField] private ComputeShader smokeSimulatorCS;
    
    //Compute Shader Input
    [SerializeField] private Texture3D staticWorldTexture; 
    
    //Compute Shader Output
    [SerializeField] private RenderTexture smokeDensityTexture;
    
    #region DEBUG
    [Header("Debug")]
    [SerializeField] private bool EnableGizmo;

    [SerializeField] private bool ShowSolidVoxels;
    [SerializeField] private bool ShowEmptyVoxels;
    [SerializeField] private bool ShowSmokedVoxels;
    #endregion
    
    private Vector3Int VoxelChildCount => new Vector3Int(
        Mathf.FloorToInt(WorldSize.x / VoxelLength),
        Mathf.FloorToInt(WorldSize.y / VoxelLength),
        Mathf.FloorToInt(WorldSize.z / VoxelLength)
    );

    private Vector3 VoxelFullExtents => new Vector3(VoxelLength, VoxelLength, VoxelLength);
    private Vector3 VoxelHalfEntents => new Vector3(VoxelLength * 0.5f, VoxelLength * 0.5f, VoxelLength * 0.5f);
    
    private float VoxelHalfLength => VoxelLength / 2;

    private int VoxelTotalCount => VoxelChildCount.x * VoxelChildCount.y * VoxelChildCount.z;
    
    private VoxelStatus[] VoxelStatusArray;

    private void Start()
    {
        VoxelStatusArray =  new VoxelStatus[VoxelTotalCount];
        VoxelizeScene();
    }

    private void VoxelizeScene()
    {
        bool originalSetting = Physics.queriesHitBackfaces;
        Physics.queriesHitBackfaces = true;
        Debug.Log($"Voxelizing scene with {VoxelTotalCount} voxels...");
        float shrinkAmount = VoxelLength * CollisionEpsilon;
        //shrunk size for checking
        Vector3 shrunkenHalfExtents = new Vector3(
            VoxelHalfEntents.x - shrinkAmount,
            VoxelHalfEntents.y,
            VoxelHalfEntents.z - shrinkAmount
        );
        
        for (int k = 0; k < VoxelChildCount.z; k++) { // Z (depth)
            for (int j = 0; j < VoxelChildCount.y; j++) { // Y (vertical)
                for (int i = 0; i < VoxelChildCount.x; i++) { // X (horizontal)
                    
                    // 1. Get the center position of this voxel
                    Vector3 voxelCenter = GetWorldPos(i, j, k);

                    // 2. Check for solid objects at this position
                    // We use CheckBox to see if a box of our voxel's size overlaps
                    // with any colliders on the SolidLayerMask.
                    bool isSolid = Physics.CheckBox(
                        voxelCenter,
                        shrunkenHalfExtents , // The "radius" of the box
                        Quaternion.identity, // No rotation
                        SolidLayerMask // Only check for layers we've defined as "Solid"
                    );

                    // if (isSolid)
                    // {
                    //     Debug.Log($"VoxelCenter: {voxelCenter} VoxelIndex: {VoxelChildCount.x}-{VoxelChildCount.y}-{VoxelChildCount.z}");
                    // }

                    // 3. Get the 1D index for our 3D (i,j,k) coordinate
                    int index = Get1DIndex(i, j, k);

                    // 4. Store the result
                    if (isSolid) {
                        VoxelStatusArray[index] = VoxelStatus.Solid;
                    } else {
                        VoxelStatusArray[index] = VoxelStatus.Empty;
                    }
                }
            }
        }
        Debug.Log("Voxelization complete!");
        Physics.queriesHitBackfaces = originalSetting;

        CreateGpuResources();
    }
    
    private int Get1DIndex(int i, int j, int k)
    {
        // This is the standard "flatten 3D array" formula
        // Z is the slowest-moving dimension, then Y, then X is fastest.
        return i + (j * VoxelChildCount.x) + (k * VoxelChildCount.x * VoxelChildCount.y);
    }
    
    private Vector3Int WorldToVoxelCoords(Vector3 worldPos)
    {
        Vector3 localPos = worldPos - VoxelOrigin.position;
        return new Vector3Int(
            Mathf.FloorToInt(localPos.x / VoxelLength),
            Mathf.FloorToInt(localPos.y / VoxelLength),
            Mathf.FloorToInt(localPos.z / VoxelLength)
        );
    }
    
    private Vector3 GetWorldPos(int i, int j, int k)
    {
        // Start at the origin, move over by (i) voxels, up by (j) voxels, etc.
        // We add VoxelHalfSize to get the CENTER of the voxel, not its corner.
        return VoxelOrigin.position + new Vector3(i * VoxelLength, j * VoxelLength, k * VoxelLength) + VoxelHalfEntents;
    }

    void CreateGpuResources()
    {
        Vector3Int dim = VoxelChildCount;
        staticWorldTexture = new Texture3D(dim.x, dim.y, dim.z, TextureFormat.R8, false);
        
        byte[] textureData = new byte[VoxelTotalCount];
        for (int i = 0; i < VoxelTotalCount; i++)
        {
            // 把 VoxelStatus (enum) 转换成 byte
            textureData[i] = (byte)VoxelStatusArray[i];
        }
        
        staticWorldTexture.SetPixelData(textureData, 0);
        staticWorldTexture.Apply(false, true);
        
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor();
        
        descriptor.width = dim.x;
        descriptor.height = dim.y;
        descriptor.volumeDepth = dim.z; 
        descriptor.dimension = TextureDimension.Tex3D;
        descriptor.enableRandomWrite = true;
        descriptor.depthBufferBits = 0;
        descriptor.msaaSamples = 1;
        
        descriptor.graphicsFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.R16_SFloat;
        smokeDensityTexture = new RenderTexture(descriptor);
        smokeDensityTexture.Create();
        
        Shader.SetGlobalTexture("_GlobalStaticWorld", staticWorldTexture);
        Shader.SetGlobalTexture("_GlobalSmokeDensity", smokeDensityTexture);
    }
    
    public void RunSmokeSimulation(Vector3 worldPos)
    {
        int kernel = smokeSimulatorCS.FindKernel("SimulateSmoke");
        
        smokeSimulatorCS.SetTexture(kernel, "_StaticWorld", staticWorldTexture);
        smokeSimulatorCS.SetTexture(kernel, "_SmokeDensityWrite", smokeDensityTexture);
        
        smokeSimulatorCS.SetInts("_Dimensions", new int[] { VoxelChildCount.x, VoxelChildCount.y, VoxelChildCount.z });
        
        //Convert the smoke grenade world position to 
        Vector3Int originCoords = WorldToVoxelCoords(worldPos);
        smokeSimulatorCS.SetInts("_SmokeOrigin", new int[] { originCoords.x, originCoords.y, originCoords.z });
        
        int groupSizeX = Mathf.CeilToInt(VoxelChildCount.x / 8.0f);
        int groupSizeY = Mathf.CeilToInt(VoxelChildCount.y / 8.0f);
        int groupSizeZ = Mathf.CeilToInt(VoxelChildCount.z / 8.0f);
        
        smokeSimulatorCS.Dispatch(kernel, groupSizeX, groupSizeY, groupSizeZ);
        
        Debug.Log($"Compute Shader 已运行。栅格坐标: {originCoords}");
    }

    private void OnDrawGizmos()
    {
        // Don't try to draw if the array hasn't been created yet
        if (VoxelStatusArray == null)
        {
            // Instead, draw a big box showing the total world size
            if (VoxelOrigin != null) {
                Gizmos.color = Color.yellow;
                Gizmos.DrawWireCube(VoxelOrigin.position + WorldSize / 2f, WorldSize);
            }
            return;
        }

        if (!EnableGizmo)
        {
            return;
        }

        // Loop through all voxels and draw them
        for (int k = 0; k < VoxelChildCount.z; k++) {
            for (int j = 0; j < VoxelChildCount.y; j++) {
                for (int i = 0; i < VoxelChildCount.x; i++) {
                    
                    int index = Get1DIndex(i, j, k);
                    if (index >= VoxelStatusArray.Length)
                    {
                        return;
                    }

                    VoxelStatus status = VoxelStatusArray[index];

                    // Set gizmo color based on status
                    switch (status)
                    {
                        case VoxelStatus.Empty:
                            if(!ShowEmptyVoxels) continue;
                            Gizmos.color = new Color(0, 0, 1, 0.1f); // Blue (faint)
                            break;
                        case VoxelStatus.Solid:
                            if(!ShowSolidVoxels) continue;
                            Gizmos.color = new Color(1, 0, 0, 0.5f); // Red (solid)
                            break;
                        case VoxelStatus.Smoked:
                            if(!ShowSolidVoxels) continue;
                            Gizmos.color = new Color(0.5f, 0.5f, 0.5f, 0.8f); // Gray
                            break;
                    }

                    // Get the position and draw the wire cube
                    Vector3 pos = GetWorldPos(i, j, k);
                    Gizmos.DrawWireCube(pos, new Vector3(VoxelLength, VoxelLength, VoxelLength));
                }
            }
        }
    }
}

