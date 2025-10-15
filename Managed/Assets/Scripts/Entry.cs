using StoryTree.Engine;
using StoryTree.Engine.Native;

namespace Scripts
{
    public class Entry: Behavior
    {
        void Awake() {
            Interop.Log("[Entry] Awake");
        }

        void Update(float dt) {
            Interop.Log($"[Entry] Update dt={dt}");
        }

        void Destroy() {
            Interop.Log($"[Entry] Destroy");
        }
    }
}
