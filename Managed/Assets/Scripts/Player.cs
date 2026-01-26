using StoryTree.Engine;

public class Player: Behavior
{
    public string Name = "Hero";
    public int Health = 100;

    void Awake() {
        Debug.Log($"[Player] Awake Name={Name}, Health={Health}");
    }

    void Update(float dt) {
        Debug.Log($"[Player] Update dt={dt}");
    }

    void Destroy() {
        Debug.Log($"[Player] Destroy");
    }
}
