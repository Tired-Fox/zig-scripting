using StoryTree.Engine;

namespace Scripts
{
    public static class Entry
    {
        public static int Tick(string who, int x)
        {
            Native.Log($"[Entry] Tick from {who}, x={x}, dt={Native.DeltaTime()}");
            return x * 2;
        }
    }
}
