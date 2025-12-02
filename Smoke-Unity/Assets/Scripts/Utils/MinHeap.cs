using System;

class MinHeap<T> where T : IComparable<T>
{
    private T[] elements;
    private int count;
    public MinHeap(int capacity) { elements = new T[capacity]; }
    public int Count => count;
    public void Push(T item)
    {
        if (count == elements.Length) Array.Resize(ref elements, count * 2);
        elements[count] = item;
        HeapifyUp(count);
        count++;
    }
    public T Pop()
    {
        T first = elements[0];
        count--;
        elements[0] = elements[count];
        HeapifyDown(0);
        return first;
    }
    void HeapifyUp(int index)
    {
        while (index > 0)
        {
            int parent = (index - 1) / 2;
            if (elements[index].CompareTo(elements[parent]) >= 0) break;
            Swap(index, parent);
            index = parent;
        }
    }
    void HeapifyDown(int index)
    {
        while (true)
        {
            int left = index * 2 + 1;
            if (left >= count) break;
            int right = left + 1;
            int smallest = left;
            if (right < count && elements[right].CompareTo(elements[left]) < 0) smallest = right;
            if (elements[index].CompareTo(elements[smallest]) <= 0) break;
            Swap(index, smallest);
            index = smallest;
        }
    }
    void Swap(int a, int b) { T temp = elements[a]; elements[a] = elements[b]; elements[b] = temp; }
}