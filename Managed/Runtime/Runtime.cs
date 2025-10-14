using System;
using System.Buffers;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.Loader;
using System.Text;
using System.Text.Json;

public sealed class Scope : AssemblyLoadContext
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate IntPtr LoadFromPathDelegate(IntPtr scopeId, IntPtr pathUtf8Z);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate IntPtr LoadFromBytesDelegate(IntPtr scopeId, IntPtr bytes, int length);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate IntPtr GetClassDelegate(IntPtr scopeId, IntPtr typeNameUtf8Z); // returns type handle
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate IntPtr NewObjectDelegate(IntPtr scopeId, IntPtr typeNameUtf8Z); // returns object handle

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void DestroyClassDelegate(IntPtr scopeId, IntPtr target); // returns type handle
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void DestroyObjectDelegate(IntPtr scopeId, IntPtr target); // returns object handle

    public readonly string BaseDir;

    public Scope(string baseDir) : base(isCollectible: true)
    {
        BaseDir = baseDir;
        Resolving += (_, name) =>
        {
            var candidate = Path.Combine(BaseDir, name.Name + ".dll");
            if (File.Exists(candidate))
                return LoadFromAssemblyPath(candidate);
            return null;
        };
    }

    static string ReadUtf8Z(IntPtr p)
    {
        if (p == IntPtr.Zero) return string.Empty;
        return Marshal.PtrToStringUTF8(p)!;
    }

    public static IntPtr LoadFromFile(IntPtr scope, IntPtr path)
    {
        var self = Host.Ref<Scope>(scope);
        var p = ReadUtf8Z(path);
        var asm = self.LoadFromAssemblyPath(p);
        return Host.Pin(asm);
    }

    public Assembly LoadFromBytes(IntPtr scope, IntPtr bytes, int length)
    {
        unsafe
        {
            var self = Host.Ref<Scope>(scope);
            var span = new ReadOnlySpan<byte>((void*)bytes, length);
            using var ms = new MemoryStream(span.ToArray());
            return LoadFromStream(ms);
        }
    }

    public static IntPtr GetClass(IntPtr scope, IntPtr typeNameUtf8Z)
    {
        var self = Host.Ref<Scope>(scope);
        var tn = ReadUtf8Z(typeNameUtf8Z);
        var t = ResolveTypeInContext(self, tn) ?? throw new TypeLoadException($"Type not found: {tn}");
        return Host.Pin(t);
    }

    public static IntPtr NewObject(IntPtr scope, IntPtr klass)
    {
        var self = Host.Ref<Scope>(scope);
        var t = Host.Ref<Type>(klass);
        var obj = Activator.CreateInstance(t) ?? throw new MissingMethodException($"No default ctor for {t.FullName}");
        return Host.Pin(obj);
    }

    public static void DestroyClass(IntPtr target) => Host.Unpin(target);
    public static void DestroyObject(IntPtr target) => Host.Unpin(target);

    public static Type? ResolveTypeInContext(Scope scope, string fullOrShort)
    {
        // 1) Try Type.GetType (works for assembly-qualified names)
        var t = Type.GetType(fullOrShort, throwOnError: false, ignoreCase: false);
        if (t != null) return t;

        // 2) Search loaded assemblies first
        foreach (var asm in scope.Assemblies)
        {
            try {
                return asm.GetType(fullOrShort, throwOnError: false, ignoreCase: false);
            } catch {}
        }

        // 3) Probe all types of all assemblies (fallback)
        foreach (var asm in scope.Assemblies)
        {
            try {
                return asm.GetTypes().FirstOrDefault(x => string.Equals(x.FullName, fullOrShort, StringComparison.Ordinal));
            } catch {}
        }
        return null;
    }
}

public static class Host
{
    // ---------- Delegates (unmanaged stubs will match these) ----------
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate ulong CreateScopeDelegate(); // returns scope id

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void DestroyScopeDelegate(ulong scopeId);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void DestroyDelegate(IntPtr handle);  // frees any object/type/assembly handle

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate int IsAssignableFromDelegate(IntPtr baseTypeUtf8Z, IntPtr targetTypeUtf8Z); // 1/0

    // Call instance method on object handle; args are JSON; returns UTF-8 JSON (CoTaskMem) and writes byte length
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate IntPtr CallMethodJsonDelegate(IntPtr objectHandle, IntPtr methodNameUtf8Z, IntPtr jsonArgsUtf8Z, out int outLen);

    // Call static method by type name; args are JSON; returns UTF-8 JSON (CoTaskMem) and writes byte length
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate IntPtr CallStaticJsonDelegate(IntPtr scopeId, IntPtr typeNameUtf8Z, IntPtr methodNameUtf8Z, IntPtr jsonArgsUtf8Z, out int outLen);

    // Free CoTaskMem returned by this API
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void FreeMemoryDelegate(IntPtr ptr);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate uint PingDelegate();
    public static uint Ping() => 1;

    // ---------- State & handles ----------
    static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        AllowTrailingCommas = true
    };

    // ---------- helpers ----------
    static unsafe string ReadUtf8Z(IntPtr p)
    {
        if (p == IntPtr.Zero) return string.Empty;
        return Marshal.PtrToStringUTF8(p)!;
    }

    static IntPtr AllocUtf8(string s, out int len)
    {
        // allocate CoTaskMem UTF-8 (host must call FreeMemory)
        var bytes = Encoding.UTF8.GetBytes(s);
        len = bytes.Length;
        var dst = Marshal.AllocCoTaskMem(len + 1);
        Marshal.Copy(bytes, 0, dst, len);
        Marshal.WriteByte(dst, len, 0);
        return dst;
    }

    public static IntPtr Pin(object obj) => GCHandle.ToIntPtr(GCHandle.Alloc(obj, GCHandleType.Normal));
    public static T Ref<T>(IntPtr target) => (T)GCHandle.FromIntPtr(target).Target;
    public static void Unpin(IntPtr id) => GCHandle.FromIntPtr(id).Free();

    static object? InvokeWithJson(object? targetOrNull, Type declaringType, string methodName, string jsonArgs)
    {
        // Interpret args JSON as array: [ ... ]
        object[] args = Array.Empty<object>();
        if (!string.IsNullOrWhiteSpace(jsonArgs))
        {
            using var doc = JsonDocument.Parse(jsonArgs);
            if (doc.RootElement.ValueKind == JsonValueKind.Array)
                args = doc.RootElement.EnumerateArray().Select(e => (object)e.Clone()).ToArray();
            else if (doc.RootElement.ValueKind != JsonValueKind.Undefined && doc.RootElement.ValueKind != JsonValueKind.Null)
                args = new object[] { doc.RootElement.Clone() };
        }

        // Find method candidates: instance or static depending on targetOrNull
        var flags = BindingFlags.Public | BindingFlags.NonPublic | (targetOrNull is null ? BindingFlags.Static : BindingFlags.Instance);
        var cands = declaringType.GetMethods(flags).Where(m => m.Name == methodName);

        foreach (var m in cands)
        {
            var ps = m.GetParameters();
            if (ps.Length != args.Length) continue;

            var callArgs = new object?[ps.Length];
            bool ok = true;

            for (int i = 0; i < ps.Length && ok; i++)
            {
                var ptype = ps[i].ParameterType;

                // If we kept JsonElement clones, materialize to the exact parameter type
                if (args[i] is JsonElement je)
                {
                    try
                    {
                        // deserialize directly to the param type
                        callArgs[i] = JsonSerializer.Deserialize(je.GetRawText(), ptype, JsonOpts);
                    }
                    catch
                    {
                        ok = false;
                    }
                }
                else
                {
                    // last-ditch convertible
                    try { callArgs[i] = Convert.ChangeType(args[i], ptype); }
                    catch { ok = false; }
                }
            }

            if (!ok) continue;

            return m.Invoke(targetOrNull, callArgs);
        }

        throw new MissingMethodException($"No compatible overload for {declaringType.FullName}.{methodName} with {args.Length} args.");
    }

    // ---------- Exported (via managed delegates) ----------
    public static IntPtr CreateScope()
    {
        // Use current assembly directory for probing by default
        var baseDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)!;
        return Pin(new Scope(baseDir));
    }

    public static void DestroyScope(IntPtr scope)
    {
        var handle = GCHandle.FromIntPtr(scope);

        var target = (Scope)handle.Target;
        target.Unload();
        handle.Free();

        GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
    }

    public static void Destroy(IntPtr handle) => Unpin(handle);

    public static int IsAssignableFrom(IntPtr baseKlass, IntPtr targetKlass)
    {
        var baseType = Ref<Type>(baseKlass);
        var targetType = Ref<Type>(targetKlass);
        return baseType.IsAssignableFrom(targetType) ? 1 : 0;
    }

    public static IntPtr CallMethodJson(IntPtr objectHandle, IntPtr methodNameUtf8Z, IntPtr jsonArgsUtf8Z, out int outLen)
    {
        var obj = Ref<object>(objectHandle);
        var method = ReadUtf8Z(methodNameUtf8Z);
        var json = ReadUtf8Z(jsonArgsUtf8Z);
        var result = InvokeWithJson(obj, obj.GetType(), method, json);
        var payload = JsonSerializer.Serialize(result, JsonOpts);
        return AllocUtf8(payload, out outLen);
    }

    public static IntPtr CallStaticJson(IntPtr scopeHandle, IntPtr typeNameUtf8Z, IntPtr methodNameUtf8Z, IntPtr jsonArgsUtf8Z, out int outLen)
    {
        var scope = Ref<Scope>(scopeHandle);
        var tn = ReadUtf8Z(typeNameUtf8Z);
        var t = Scope.ResolveTypeInContext(scope, tn) ?? throw new TypeLoadException($"Type not found: {tn}");
        var method = ReadUtf8Z(methodNameUtf8Z);
        var json = ReadUtf8Z(jsonArgsUtf8Z);
        var result = InvokeWithJson(null, t, method, json);
        var payload = JsonSerializer.Serialize(result, JsonOpts);
        return AllocUtf8(payload, out outLen);
    }

    public static void FreeMemory(IntPtr ptr)
    {
        if (ptr != IntPtr.Zero) Marshal.FreeCoTaskMem(ptr);
    }
}
