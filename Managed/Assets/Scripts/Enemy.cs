using StoryTree.Engine.Native;

namespace Scripts
{
    public class Enemy
    {
        public string Kind = "Slime";
        public int Health = 30;

        public void Update()
        {
            Interop.Log($"[Enemy] {Kind} slithers…");
        }
    }
}

