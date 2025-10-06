using StoryTree.Engine;

namespace Scripts
{
    public class Player
    {
        public string Name = "Hero";
        public int Health = 100;

        public void Update()
        {
            Native.Log($"[Player] {Name} updating... dt={Native.DeltaTime()}");
        }
    }
}
