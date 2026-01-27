using System;

namespace StoryTree {
    namespace Engine {
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
