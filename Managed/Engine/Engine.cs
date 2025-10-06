using System;
using System.Runtime.CompilerServices;

namespace StoryTree {
    namespace Engine {
        public static class Native {
            // Implemented by Zig (registered via mono_add_internal_call).
            [MethodImpl(MethodImplOptions.InternalCall)]
            public static extern void Log(string msg);

            [MethodImpl(MethodImplOptions.InternalCall)]
            public static extern float DeltaTime();
        }

        public struct Vec2
        {
            public float X, Y;
            public Vec2(float x, float y) { X = x; Y = y; }
            public override string ToString() => $"({X},{Y})";
        }
    }
}
