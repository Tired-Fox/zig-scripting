const std = @import("std");
const bootstrap = @import("bootstrap.zig");

const HostFxr = bootstrap.HostFxr;

pub const Host = struct {
    var CreateScope: ?*const fn(baseDir: ?[*:0]const u8, out: **Scope) callconv(.c) i32 = null;
    var Destroy: ?*const fn(handle: *anyopaque) callconv(.c) i32 = null;
    var Free: ?*const fn(handle: *anyopaque) callconv(.c) i32 = null;
    var Ping: ?*const fn(out: *u32) callconv(.c) i32 = null;

    pub fn ping() !bool {
        if (Ping) |clbk| {
            var result: u32 = 0;
            if (clbk(&result) != 0) return error.PingFailed;
            return result == 1;
        }
        return error.MethodNotBound;
    }

    /// Create a new scope to load scripts into
    ///
    /// `baseDir` defaults to the same directory as the dll that loaded this method.
    /// e.g. if the dll is `<exe_dir>/runtime/runtime.dll` then the default dir is
    /// `<exe_dir>/runtime`.
    ///
    /// Any custom `baseDir` passed in must be an absolute path. This will act as a prefix
    /// for any dll that is loaded by path.
    pub fn createScope(baseDir: ?[:0]const u8) !*Scope {
        if (CreateScope) |clbk| {
            var scope: *Scope = undefined;
            if (clbk(if (baseDir) |b| b.ptr else null, &scope) != 0) return error.CreateScope;
            return scope;
        }
        return error.MethodNotBound;
    }

    pub fn destroy(self: *const @This()) void {
        if (Host.Destroy) |clbk| {
            _ = clbk(@ptrCast(@constCast(self)));
        }
    }

    pub fn free(handle: [*:0]const u8) !void {
        if (Free) |clbk| {
            if (clbk(@ptrCast(handle)) != 0) return error.Free;
            return;
        }
        return error.MethodNotBound;
    }
};

pub const Class = opaque {
    pub const VTable = struct {
        var IsAssignableFrom: ?*const fn(baseType: *Class, targetType: *const Class, out: *i32) callconv(.c) i32 = null;
        var New: ?*const fn(self: *Class, out: **Object) callconv(.c) i32 = null;
        var GetMethod: ?*const fn(self: *Class, name: [*:0]const u8, param_count: u32, out: *?*Method) callconv(.c) i32 = null;
    };

    pub fn new(self: *@This()) !*Object {
        if (VTable.New) |clbk| {
            var result: *Object = undefined;
            if (clbk(self, &result) != 0) return error.ClassNewObject;
            return result;
        }
        return error.MethodNotBound;
    }

    pub fn getMethod(self: *@This(), name: [:0]const u8, count: u32) !?*Method {
        if (VTable.GetMethod) |clbk| {
            var result: ?*Method = null;
            if (clbk(self, name.ptr, count, &result) != 0) return error.GetMethod;
            return result;
        }
        return error.MethodNotBound;
    }

    pub fn destroy(self: *const @This()) void {
        if (Host.Destroy) |clbk| {
            _ = clbk(@ptrCast(@constCast(self)));
        }
    }
};

pub const Assembly = opaque {
    pub const VTable = struct {
        var GetClass: ?*const fn(self: *const Assembly, type_name: [*:0]const u8, out: *?*Class) callconv(.c) i32 = null;
    };

    pub fn getClass(self: *const @This(), type_name: [:0]const u8) !?*Class {
        if (VTable.GetClass) |clbk| {
            var class: ?*Class = null;
            if (clbk(self, type_name.ptr, &class) != 0) return error.GetClass;
            return class;
        }
        return error.MethodNotBound;
    }
};

pub const Object = opaque {
    pub const VTable = struct {
    };

    pub fn destroy(self: *const @This()) void {
        if (Host.Destroy) |clbk| {
            _ = clbk(@ptrCast(@constCast(self)));
        }
    }
};

pub const Method = opaque {
    pub const VTable = struct {
        var RuntimeInvoke: ?*const fn(method: *Method, instance: ?*Object, argv: [*]?*anyopaque) callconv(.c) i32 = null;
    };

    pub fn runtimeInvoke(self: *@This(), instance: ?*Object, args: []?*anyopaque) !void {
        if (VTable.RuntimeInvoke) |clbk| {
            if (clbk(self, instance, args.ptr) != 0) return error.MethodRuntimeInvoke;
            return;
        }
        return error.MethodNotBound;
    }

    pub fn destroy(self: *const @This()) void {
        if (Host.Destroy) |clbk| {
            _ = clbk(@ptrCast(@constCast(self)));
        }
    }
};

pub const Scope = opaque {
    pub const VTable = struct {
        var LoadFromPath: ?*const fn(self: *Scope, path: [*:0]const u8, out: *?*Assembly) callconv(.c) i32 = null;
        var LoadFromBytes: ?*const fn(self: *Scope, bytes: [*]const u8, length: i32, out: *?*Assembly) callconv(.c) i32 = null;
        var Unload: ?*const fn(self: *Scope) callconv(.c) i32 = null;
    };

    pub fn loadFromPath(self: *@This(), path: [:0] const u8) !?*Assembly {
        if (VTable.LoadFromPath) |clbk| {
            var assembly: ?*Assembly = undefined;
            if (clbk(self, path.ptr, &assembly) != 0) return error.LoadFromPath;
            return assembly;
        }
        return error.MethodNotBound;
    }

    pub fn loadFromBytes(self: *@This(), bytes: []const u8) !*Assembly {
        if (VTable.LoadFromBytes) |clbk| {
            var assembly: ?*Assembly = undefined;
            if (clbk(self, bytes.ptr, @intCast(bytes.len), &assembly) != 0) return error.LoadFromBytes;
            return assembly;
        }
        return error.MethodNotBound;
    }

    pub fn unload(self: *@This()) !void {
        if (VTable.Unload) |clbk| {
            if (clbk(self) != 0) return error.UnloadScope;
            return;
        }
        return error.MethodNotBound;
    }
};

pub fn loadMethods(allocator: std.mem.Allocator, hostfxr: *HostFxr) !void {
    Host.Ping = @ptrCast(try hostfxr.getFunctionPointer(allocator, "Host", "Ping"));
    Host.CreateScope = @ptrCast(try hostfxr.getFunctionPointer(allocator, "Host", "CreateScope"));
    Host.Destroy = @ptrCast(try hostfxr.getFunctionPointer(allocator, "Host", "Destroy"));
    Host.Free = @ptrCast(try hostfxr.getFunctionPointer(allocator, "Host", "Free"));

    Scope.VTable.LoadFromPath = @ptrCast(try hostfxr.getFunctionPointer(allocator, "Scope", "LoadFromPath"));
    Scope.VTable.LoadFromBytes = @ptrCast(try hostfxr.getFunctionPointer(allocator, "Scope", "LoadFromBytes"));
    Scope.VTable.Unload = @ptrCast(try hostfxr.getFunctionPointer(allocator, "Scope", "Unload"));

    Assembly.VTable.GetClass = @ptrCast(try hostfxr.getFunctionPointer(allocator, "RuntimeAssembly", "GetClass"));

    Class.VTable.IsAssignableFrom = @ptrCast(try hostfxr.getFunctionPointer(allocator, "RuntimeClass", "IsAssignableFrom"));
    Class.VTable.New = @ptrCast(try hostfxr.getFunctionPointer(allocator, "RuntimeClass", "New"));
    Class.VTable.GetMethod = @ptrCast(try hostfxr.getFunctionPointer(allocator, "RuntimeClass", "GetMethod"));

    Method.VTable.RuntimeInvoke = @ptrCast(try hostfxr.getFunctionPointer(allocator, "RuntimeMethod", "RuntimeInvoke"));
}

fn log(bytes: [*]const u8, length: i32) void {
    std.debug.print("{s}\n", .{ bytes[0..@intCast(length)] });
}

const InteropFunctions = packed struct {
    log: *const fn(bytes: [*]const u8, length: i32) void = &log,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var fxr = try HostFxr.init(allocator, .{
        .version = "8.0.20",
        // Base path to host/fxr/..., pack/..., shared/... for the dotnet runtime
        .dotnet = "dotnet",
        .config = "runtime/Runtime.runtimeconfig.json",
        .dll = "runtime/Runtime.dll",
    });
    defer fxr.deinit(allocator);

    try loadMethods(allocator, &fxr);

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_dir = try std.fs.selfExeDirPath(&buf);

    const baseDir = try std.fs.path.joinZ(allocator, &.{ exe_dir, "managed" });
    defer allocator.free(baseDir);

    const root = try Host.createScope(baseDir);
    defer root.unload() catch {};

    const engine_asm = try root.loadFromPath("Engine") orelse return error.LoadEngineDll;

    const Interop = try engine_asm.getClass("StoryTree.Engine.Native.Interop") orelse return error.GetInteropClass;
    defer Interop.destroy();

    const functions = InteropFunctions{};
    if (try Interop.getMethod("Initialize", 2)) |method| {
        defer method.destroy();

        var size: i32 = @sizeOf(InteropFunctions);
        var args: [2]?*anyopaque = .{ @ptrCast(@constCast(&functions)), @ptrCast(&size) };
        try method.runtimeInvoke(null, &args);
    }

    const scripts_asm = try root.loadFromPath("Scripts") orelse return error.LoadScriptsDll;

    const player_cls = try scripts_asm.getClass("Player") orelse return error.GetPlayerClass;
    defer player_cls.destroy();

    const instance = try player_cls.new();
    defer instance.destroy();

    if (try player_cls.getMethod("Awake", 0)) |method| {
        defer method.destroy();

        _ = try method.runtimeInvoke(instance, &.{});
        std.debug.print("Found method 'Awake'\n",.{});
    }
}

