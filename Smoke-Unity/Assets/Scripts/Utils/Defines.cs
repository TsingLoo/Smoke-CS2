using System.Runtime.InteropServices;
using UnityEngine;

[StructLayout(LayoutKind.Sequential)]
public unsafe struct Matrix16x4
{
    public fixed float data[64];

    public Vector4 this[int index]
    {
        get
        {
            if (index < 0 || index >= 16) return Vector4.zero;
            fixed (float* ptr = data)
            {
                return *(Vector4*)(ptr + index * 4);
            }
        }
        set
        {
            if (index < 0 || index >= 16) return;
            fixed (float* ptr = data)
            {
                *(Vector4*)(ptr + index * 4) = value;
            }
        }
    }
}


[StructLayout(LayoutKind.Sequential)]
public unsafe struct Array5x4
{
    public fixed float data[20];

    public Vector4 this[int index]
    {
        get
        {
            if (index < 0 || index >= 5) return Vector4.zero;
            fixed (float* ptr = data) return *(Vector4*)(ptr + index * 4);
        }
        set
        {
            if (index < 0 || index >= 5) return;
            fixed (float* ptr = data) *(Vector4*)(ptr + index * 4) = value;
        }
    }
}

[StructLayout(LayoutKind.Sequential)]
public unsafe struct Array2x4
{
    public fixed float data[8];

    public Vector4 this[int index]
    {
        get
        {
            if (index < 0 || index >= 2) return Vector4.zero;
            fixed (float* ptr = data) return *(Vector4*)(ptr + index * 4);
        }
        set
        {
            if (index < 0 || index >= 2) return;
            fixed (float* ptr = data) *(Vector4*)(ptr + index * 4) = value;
        }
    }
}