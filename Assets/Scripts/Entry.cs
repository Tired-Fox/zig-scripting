using StoryTree;
using StoryTree.Engine;

namespace Scripts
{
    public class Entry: Behavior
    {
        void Awake() {
            Debug.Log("[Entry] Awake");
        }

        void Update(float dt) {
            Debug.Log($"[Entry] Update dt={dt}");
        }

        void Destroy() {
            Debug.Log($"[Entry] Destroy");
        }
    }
}
