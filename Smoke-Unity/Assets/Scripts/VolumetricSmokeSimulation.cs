using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VolumetricSmokeSimulation : MonoBehaviour
{
    static Vector3Int[] allDirs = {
        new Vector3Int(1,0,0), new Vector3Int(-1,0,0),
        new Vector3Int(0,0,1), new Vector3Int(0,0,-1),
        new Vector3Int(0,1,0), new Vector3Int(0,-1,0) 
    };
    
    [Header("Target Shape")]
    public Vector3 preferredSize = new Vector3(0.7f, 1.0f, 0.6f); 
    public float roundness = 4.0f;

    [Header("Budget & Grid")]
    public int voxelBudget = 10000; 
    public float gridWorldSize = 12.0f; 

    [Header("Physics")]
    public LayerMask obstacleMask;
    [Range(0.1f, 0.9f)] public float collisionShrink = 0.5f;
    [Range(0.8f, 0.99f)] public float traceShrink = 0.95f; 

    [Header("Gravity Control")]
    public float gravityBias = 10.0f;

    public float upwardLimit = 10.0f;

    [Header("Density Control")]
    public AnimationCurve densityFalloff = new AnimationCurve(
        new Keyframe(0f, 1f),
        new Keyframe(1f, 0f)
    );
    
    // ===== Internal States =====
    private const int GRID_RES = 32;
    private float voxelSize;
    private int mySlotIndex = -1;
    private byte[] densityBuffer;
    private bool[,,] visited;
    private List<SmokeNode> filledVoxels = new List<SmokeNode>();
    private float startWorldY;

    struct SmokeNode : IComparable<SmokeNode>
    {
        public Vector3Int pos;
        public float priority;
        public float shapeCost;

        public int CompareTo(SmokeNode other)
        {
            return priority.CompareTo(other.priority);
        }
    }

    void Start()
    {
        if (SmokeVolumeManager.Instance == null) return;
        mySlotIndex = SmokeVolumeManager.Instance.AllocateSmokeSlot();
        if (mySlotIndex == -1) return;

        voxelSize = gridWorldSize / GRID_RES;
        densityBuffer = new byte[GRID_RES * GRID_RES * GRID_RES];
        visited = new bool[GRID_RES, GRID_RES, GRID_RES];

        startWorldY = transform.position.y;

        StartCoroutine(SimulatePriorityFill());
    }

    void Update()
    {
        if (mySlotIndex != -1)
        {
            SmokeVolumeManager.Instance.UpdateSmokeMetadata(
                mySlotIndex, transform.position, Vector3.one * gridWorldSize, Color.white, 1.0f
            );
        }
    }

    void OnDisable()
    {
        if (mySlotIndex != -1 && SmokeVolumeManager.Instance != null)
            SmokeVolumeManager.Instance.ReleaseSmokeSlot(mySlotIndex);
    }
    
    IEnumerator SimulatePriorityFill()
    {
        MinHeap<SmokeNode> pQueue = new MinHeap<SmokeNode>(2048);

        int center = GRID_RES / 2;
        Vector3Int startPos = new Vector3Int(center, center, center);
        
        float startShapeCost = CalculateShapeCost(startPos);
        float startTotalCost = CalculateTotalCost(startPos, startShapeCost);

        pQueue.Push(new SmokeNode { 
            pos = startPos, 
            priority = startTotalCost, 
            shapeCost = startShapeCost 
        });
        
        visited[center, center, center] = true;
        filledVoxels.Clear();
        
        int processedPerFrame = 0;
        float maxShapeCostReached = 0f;

        while (pQueue.Count > 0 && filledVoxels.Count < voxelBudget)
        {
            SmokeNode current = pQueue.Pop();
            filledVoxels.Add(current);
            
            if (current.shapeCost > maxShapeCostReached) 
                maxShapeCostReached = current.shapeCost;
            
            for (int i = 0; i < allDirs.Length; i++)
            {
                Vector3Int neighbor = current.pos + allDirs[i];

                //check if this neighbour is valid
                if (!IsIndexValid(neighbor) || visited[neighbor.x, neighbor.y, neighbor.z])
                    continue;

                //check if the neighbour is too high
                if (!CheckUpwardLimit(neighbor))
                {
                    visited[neighbor.x, neighbor.y, neighbor.z] = true;
                    continue;
                }

                //collision detection
                if (CheckCollision(neighbor) || !CheckConnectivity(current.pos, neighbor))
                {
                    visited[neighbor.x, neighbor.y, neighbor.z] = true;
                    continue;
                }
                
                float neighborShapeCost = CalculateShapeCost(neighbor);
                float neighborTotalCost = CalculateTotalCost(neighbor, neighborShapeCost);

                visited[neighbor.x, neighbor.y, neighbor.z] = true;
                
                pQueue.Push(new SmokeNode { 
                    pos = neighbor, 
                    priority = neighborTotalCost,
                    shapeCost = neighborShapeCost
                });
            }

            processedPerFrame++;
            if (processedPerFrame > 1000)
            {
                processedPerFrame = 0;
                ApplyDensity(maxShapeCostReached);
                yield return null;
            }
        }

        ApplyDensity(maxShapeCostReached);
    }

    //the cost increase when given position is more far away from origin
    float CalculateShapeCost(Vector3Int gridPos)
    {
        float halfRes = GRID_RES / 2f;
        float ox = (gridPos.x - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oy = (gridPos.y - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oz = (gridPos.z - halfRes) * voxelSize + (voxelSize * 0.5f);

        float nx = Mathf.Abs(ox) / (preferredSize.x * 0.5f);
        float ny = Mathf.Abs(oy) / (preferredSize.y * 0.5f);
        float nz = Mathf.Abs(oz) / (preferredSize.z * 0.5f);

        //roundness
        float distPow = Mathf.Pow(nx, roundness) + Mathf.Pow(ny, roundness) + Mathf.Pow(nz, roundness);
        return Mathf.Pow(distPow, 1.0f / roundness);
    }

    float CalculateTotalCost(Vector3Int gridPos, float shapeCost)
    {
        float normalizedY = (gridPos.y - (GRID_RES / 2f)) / (GRID_RES / 2f); //from -1 to 1
        float gravityPenalty = normalizedY * gravityBias;
        
        return shapeCost + gravityPenalty;
    }
    
    bool CheckUpwardLimit(Vector3Int gridPos)
    {
        Vector3 worldPos = GridToWorld(gridPos);
        float heightAboveStart = worldPos.y - startWorldY;
        
        return heightAboveStart <= upwardLimit;
    }
    
    
    void ApplyDensity(float maxCost)
    {
        float range = Mathf.Max(maxCost, 0.01f);

        foreach (var node in filledVoxels)
        {
            float t = Mathf.Clamp01(node.shapeCost / range);
            float density = densityFalloff.Evaluate(t);

            int idx = node.pos.x + (node.pos.y * GRID_RES) + (node.pos.z * GRID_RES * GRID_RES);
            densityBuffer[idx] = (byte)(density * 255);
        }

        if (mySlotIndex != -1)
            SmokeVolumeManager.Instance.UploadDensityData(mySlotIndex, densityBuffer);
    }
    
    
    bool IsIndexValid(Vector3Int p) => 
        p.x >= 0 && p.x < GRID_RES && p.y >= 0 && p.y < GRID_RES && p.z >= 0 && p.z < GRID_RES;

    Vector3 GridToWorld(Vector3Int p)
    {
        float halfRes = GRID_RES / 2f;
        float ox = (p.x - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oy = (p.y - halfRes) * voxelSize + (voxelSize * 0.5f);
        float oz = (p.z - halfRes) * voxelSize + (voxelSize * 0.5f);
        return transform.position + new Vector3(ox, oy, oz);
    }

    bool CheckConnectivity(Vector3Int from, Vector3Int to)
    {
        Vector3 start = GridToWorld(from);
        Vector3 end = GridToWorld(to);
        Vector3 dir = end - start;
        Vector3 halfExtents = Vector3.one * (voxelSize * 0.5f) * traceShrink;
        return !Physics.BoxCast(start, halfExtents, dir.normalized, out _, Quaternion.identity, dir.magnitude, obstacleMask);
    }

    bool CheckCollision(Vector3Int p)
    {
        Vector3 center = GridToWorld(p);
        Vector3 halfExtents = Vector3.one * (voxelSize * 0.5f) * collisionShrink;
        return Physics.CheckBox(center, halfExtents, Quaternion.identity, obstacleMask);
    }
    
    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.cyan;
        Gizmos.DrawWireCube(transform.position, preferredSize);
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireCube(transform.position, Vector3.one * gridWorldSize);
        
        // 绘制向上限制线
        Gizmos.color = Color.red;
        float limitY = (Application.isPlaying ? startWorldY : transform.position.y) + upwardLimit;
        Vector3 limitCenter = new Vector3(transform.position.x, limitY, transform.position.z);
        Gizmos.DrawWireCube(limitCenter, new Vector3(gridWorldSize, 0.1f, gridWorldSize));

        if (Application.isPlaying && densityBuffer != null)
        {
            float halfRes = GRID_RES / 2f;
            for (int x=0; x<GRID_RES; x++) for (int y=0; y<GRID_RES; y++) for (int z=0; z<GRID_RES; z++)
            {
                int idx = x + y*GRID_RES + z*GRID_RES*GRID_RES;
                if (densityBuffer[idx] > 10)
                {
                    Gizmos.color = new Color(0,1,0, densityBuffer[idx]/255f);
                    float ox = (x - halfRes) * voxelSize + (voxelSize * 0.5f);
                    float oy = (y - halfRes) * voxelSize + (voxelSize * 0.5f);
                    float oz = (z - halfRes) * voxelSize + (voxelSize * 0.5f);
                    Gizmos.DrawCube(transform.position + new Vector3(ox, oy, oz), Vector3.one * voxelSize * 0.9f);
                }
            }
        }
    }
}