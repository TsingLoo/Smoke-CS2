using UnityEngine;

public class SmokeVolumeShadowProxy : MonoBehaviour
{
    [Header("References")]
    public Transform smokeVolumeTransform;
    public Material shadowProxyMaterial;
    
    public int myVolumeIndex = 0;
    
    private MeshRenderer meshRenderer;
    private MeshFilter meshFilter;
    private MaterialPropertyBlock propertyBlock;
    private static Mesh _cachedCubeMesh;
    
    void OnEnable()
    {
        CreateProxyMesh();
        
        if (propertyBlock == null)
            propertyBlock = new MaterialPropertyBlock();
    }

    public void SetVolumeIndex(int i)
    {
        if (meshRenderer != null && propertyBlock != null)
        {
            meshRenderer.GetPropertyBlock(propertyBlock);
            this.myVolumeIndex = i;
            propertyBlock.SetInt("_MyVolumeIndex", i);
            meshRenderer.SetPropertyBlock(propertyBlock);
        }
    }

    void CreateProxyMesh()
    {
        meshFilter = gameObject.AddComponent<MeshFilter>();
        meshRenderer = gameObject.AddComponent<MeshRenderer>();
        
        if (_cachedCubeMesh == null)
        {
            GameObject tempCube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            _cachedCubeMesh = tempCube.GetComponent<MeshFilter>().sharedMesh;
            DestroyImmediate(tempCube);
        }
        
        meshFilter.sharedMesh = _cachedCubeMesh;
        
        meshRenderer.material = shadowProxyMaterial;
        meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.ShadowsOnly;
        meshRenderer.receiveShadows = false;
        
        if (smokeVolumeTransform != null)
        {
            transform.position = smokeVolumeTransform.position;
            transform.rotation = smokeVolumeTransform.rotation;
            transform.localScale = new Vector3(
                SmokeVolumeManager.GRID_WORLD_SIZE,
                SmokeVolumeManager.GRID_WORLD_SIZE,
                SmokeVolumeManager.GRID_WORLD_SIZE
            );
        }
    }
    
    void Update()
    {
        if (smokeVolumeTransform != null)
        {
            transform.position = smokeVolumeTransform.position;
            transform.rotation = smokeVolumeTransform.rotation;
        }
    }
    
#if UNITY_EDITOR
    // 可选：在Scene视图中显示索引
    void OnDrawGizmosSelected()
    {
        UnityEditor.Handles.Label(
            transform.position, 
            $"Volume Index: {myVolumeIndex}"
        );
    }
#endif
}