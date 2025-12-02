using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

[StructLayout(LayoutKind.Sequential)]
public struct BulletHoleData
{
    public Vector4 startPosAndIntensity; // xyz = Start Position, w = Intensity (1.0 -> 0.0)
    public Vector4 endPosAndRadius;      // xyz = End Position,   w = Radius
}


[ExecuteAlways]
public class SmokeHoleManager : MonoBehaviour
{
    public static SmokeHoleManager Instance;

    private void OnEnable() => Instance = this;
    
    public class ActiveHole
    {
        public Vector3 start;
        public Vector3 end;
        public float radius;
        public float maxDuration;
        public float timer;
    }

    private List<ActiveHole> activeHoles = new List<ActiveHole>();
    private const int MAX_HOLES = 32;
    
    public static BulletHoleData[] ShaderDataArray = new BulletHoleData[MAX_HOLES];
    public static int ActiveCount = 0;
    
    public static ComputeBuffer HoleBuffer;

    void Start()
    {
        if (HoleBuffer == null)
        {
            HoleBuffer = new ComputeBuffer(MAX_HOLES, Marshal.SizeOf(typeof(BulletHoleData)), ComputeBufferType.Structured);
        }
    }

    void Update()
    {
        // 1. 更新逻辑：衰减和移除
        for (int i = activeHoles.Count - 1; i >= 0; i--)
        {
            ActiveHole hole = activeHoles[i];
            hole.timer += Time.deltaTime;
            
            if (hole.timer >= hole.maxDuration)
            {
                activeHoles.RemoveAt(i);
            }
        }
        
        ActiveCount = Mathf.Min(activeHoles.Count, MAX_HOLES);
        for (int i = 0; i < MAX_HOLES; i++)
        {
            if (i < ActiveCount)
            {
                var h = activeHoles[i];
                float intensity = 1.0f - Mathf.Clamp01(h.timer / h.maxDuration);
                
                intensity = Mathf.SmoothStep(0, 1, intensity);

                ShaderDataArray[i].startPosAndIntensity = new Vector4(h.start.x, h.start.y, h.start.z, intensity);
                ShaderDataArray[i].endPosAndRadius = new Vector4(h.end.x, h.end.y, h.end.z, h.radius);
            }
            else
            {
                ShaderDataArray[i].startPosAndIntensity = Vector4.zero;
                ShaderDataArray[i].endPosAndRadius = Vector4.zero; 
            }
        }
        
        if (HoleBuffer != null)
        {
            HoleBuffer.SetData(ShaderDataArray);
        }
    }

    private void OnDestroy()
    {
        HoleBuffer?.Release();
        HoleBuffer = null;
    }
    
    public void AddBulletHole(Vector3 start, Vector3 direction, float distance, float radius = 0.5f, float duration = 2.0f)
    {
        if (activeHoles.Count >= MAX_HOLES) activeHoles.RemoveAt(0); // 移除最老的

        activeHoles.Add(new ActiveHole
        {
            start = start,
            end = start + direction * distance,
            radius = radius,
            maxDuration = duration,
            timer = 0f
        });
    }
}