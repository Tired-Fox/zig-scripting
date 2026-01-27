using System;

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
    }
}
