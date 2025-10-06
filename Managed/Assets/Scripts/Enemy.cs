using StoryTree.Engine;

namespace Scripts
{
    public class Enemy
    {
        public string Kind = "Slime";
        public int Health = 30;

        public void Update()
        {
            Native.Log($"[Enemy] {Kind} slithers… dt={Native.DeltaTime()}");
        }
    }
}

