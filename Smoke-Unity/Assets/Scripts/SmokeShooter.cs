using UnityEngine;

public class SmokeShooter : MonoBehaviour
{
    [Header("Settings")]
    public float maxDistance = 100f;
    
    public float holeRadius = 1.5f;
    
    public float holeDuration = 3.0f;
    
    public LayerMask hitLayers = -1;

    [Header("Debug Gizmos")]
    public bool showDebugGizmos = true;
    public Color hitColor = Color.red;
    public Color missColor = Color.yellow;

    private Camera _cam;
    
    // for debugging
    private Vector3 _lastFireOrigin;
    private Vector3 _lastFireEndPoint;
    private bool _didHitSomething;

    void Start()
    {
        _cam = GetComponent<Camera>();
        if (_cam == null) _cam = Camera.main;
    }

    void Update()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Fire();
        }
    }

    void Fire()
    {

        Ray ray = _cam.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0));

        Vector3 startPos = ray.origin;
        Vector3 direction = ray.direction;
        float finalDistance = maxDistance;
        
        _lastFireOrigin = startPos;

        if (Physics.Raycast(ray, out RaycastHit hit, maxDistance, hitLayers))
        {
            finalDistance = hit.distance;
            _didHitSomething = true;
            _lastFireEndPoint = hit.point;
        }
        else
        {
            finalDistance = maxDistance;
            _didHitSomething = false;
            _lastFireEndPoint = startPos + direction * maxDistance;
        }
        
        SmokeHoleManager.Instance?.AddBulletHole(
            startPos,
            direction,
            finalDistance,
            holeRadius,
            holeDuration
        );
    }


    private void OnDrawGizmosSelected()
    {
        if (!showDebugGizmos) return;
        
        if (_lastFireOrigin == Vector3.zero && _lastFireEndPoint == Vector3.zero) return;
        
        Gizmos.color = _didHitSomething ? hitColor : missColor;
        
        Gizmos.DrawLine(_lastFireOrigin, _lastFireEndPoint);
        
        Gizmos.DrawSphere(_lastFireEndPoint, 0.2f);
        
        Gizmos.color = Color.blue;
        Gizmos.DrawSphere(_lastFireOrigin, 0.05f);
    }
}