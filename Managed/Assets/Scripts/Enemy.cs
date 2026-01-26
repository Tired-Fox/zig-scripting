using StoryTree.Engine;

namespace Scripts
{
    public enum EnemyType
    {
        Slime
    }

    public class Enemy
    {
        public EnemyType Kind = EnemyType.Slime;
        public int Health = 30;

        public void Update()
        {
            Debug.Log($"[Enemy] {Kind} slithers…");
        }
    }
}

