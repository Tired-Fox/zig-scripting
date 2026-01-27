using System;
using System.Runtime.CompilerServices;

namespace StoryTree {
    /**
        *  <summary>
        *  Debug Utilities
        *  </summary>
        */
    public class Debug
    {
        /**
            * <summary>
            * Log a message to the hosts loggin system
            * </summary>
            * <param name="message">The message to log; usually a formatted string</param>
            */
        [MethodImplAttribute(MethodImplOptions.InternalCall)]
        public extern static void Log(string message);
    }
}