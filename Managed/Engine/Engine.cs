using System;
using System.Runtime.CompilerServices;

namespace StoryTree {
    namespace Engine {
        /**
         * <summary>
         * Basic behavior that all components inherit
         * </summary>
         */
        public abstract class Behavior {
            // Engine managed state
            internal IntPtr nativeId = default;
        }


        /**
         * <summary>
         * API to interact with the native system
         * </summary>
         */
        public static class Native {
            // Implemented by Zig (registered via mono_add_internal_call).

            /**
             * <summary>
             * Log a message to Stderr
             * </summary>
             */
            [MethodImpl(MethodImplOptions.InternalCall)]
            public static extern void Log(string msg);
        }

        /**
         * <summary>
         * A 2d vector of float values
         * </summary>
         */
        public struct Vec2
        {
            /**
             * <summary>The first value in the vector</summary>
             */
            public float X;
            /**
             * <summary>The second value in the vector</summary>
             */
            public float Y;

            /**
             * <summary>Initialize the vector</summary>
             */
            public Vec2(float x, float y) { X = x; Y = y; }

            /**
             * <summary>Stringify the vector</summary>
             */
            public override string ToString() => $"({X},{Y})";
        }
    }
}
