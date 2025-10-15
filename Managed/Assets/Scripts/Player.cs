using StoryTree.Engine;
using StoryTree.Engine.Native;

public class Player: Behavior
{
    public string Name = "Hero";
    public int Health = 100;

    void Awake() {
        Interop.Log($"[Player] Awake Name={Name}, Health={Health}");
    }

    void Update(float dt) {
        Interop.Log($"[Player] Update dt={dt}");
    }

    void Destroy() {
        Interop.Log($"[Player] Destroy");
    }
}
