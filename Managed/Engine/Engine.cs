using System;
using System.Text;
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

        namespace Native {
            /**
             * <summary>
             * API to interact with the native system
             * </summary>
             */
            public static unsafe class Interop {
                private static Functions* funcs;

                /**
                 * <summary>
                 * Initialize the table of native interop functions
                 * </summary>
                 */
                public static void Initialize(IntPtr table, int size)
                {
                    if (table == IntPtr.Zero) throw new ArgumentNullException(nameof(table));
                    if (size != sizeof(Functions))
                        throw new ArgumentException($"Host table size mismatch. Expected {sizeof(Functions)}, got {size}");
                    funcs = (Functions*)table;
                }

                /**
                 * <summary>
                 * Log a message to Stderr
                 * </summary>
                 */
                [MethodImpl(MethodImplOptions.AggressiveInlining)]
                public static void Log(string msg)
                {
                    if (funcs == null) ThrowNotInit();
                    fixed (byte* p = Encoding.UTF8.GetBytes(msg))
                    {
                        funcs->log(p, msg.Length);
                    }
                }

                private static void ThrowNotInit() =>
                    throw new InvalidOperationException("Native.Interop.Functions not initialized.");

                private struct Functions {
                    #pragma warning disable 0649

                    // Typed unmanaged function pointers
                    public delegate* unmanaged<byte*, int, void> log;
                };
            }
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
