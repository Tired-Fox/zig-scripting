using StoryTree.Engine;

namespace Scripts
{
    public class Entry: Behavior
    {
        void Awake() {
            Native.Log("[Entry] Awake");
        }

        void Update(float dt) {
            Native.Log($"[Entry] Update dt={dt}");
        }

        void Destroy() {
            Native.Log($"[Entry] Destroy");
        }
    }
}
