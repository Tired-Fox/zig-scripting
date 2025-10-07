using StoryTree.Engine;

public class Player: Behavior
{
    public string Name = "Hero";
    public int Health = 100;

    void Awake() {
        Native.Log($"[Player] Awake Name={Name}, Health={Health}");
    }

    void Update(float dt) {
        Native.Log($"[Player] Update dt={dt}");
    }

    void Destroy() {
        Native.Log($"[Player] Destroy");
    }
}
