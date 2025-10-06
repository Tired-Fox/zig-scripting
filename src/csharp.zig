const std = @import("std");
const m = @import("mono_bindings.zig");

fn native_log(s: *m.MonoString) callconv(.c) void {
    const c_str = m.mono_string_to_utf8(s);
    defer m.mono_free(@ptrCast(@constCast(c_str)));

    std.debug.print("[C#] {s}\n", .{ std.mem.sliceTo(@as([*:0]const u8, @ptrCast(@constCast(c_str))), 0) });
}


fn native_delta_time() callconv(.c) f32 {
    return 0.016; // ~60 FPS
}

fn runScriptsInChildDomain() !void {
    const root = m.mono_get_root_domain();

    const child = m.mono_domain_create_appdomain("ScriptsDomain", null) orelse return error.CreateDomain;
    _ = m.mono_domain_set(child, 0);
    _ = m.mono_thread_attach(child);

    const assembly = m.mono_domain_assembly_open(child, "Managed/Scripts.dll") orelse return error.OpenAssemblyFailed;
    const img = m.mono_assembly_get_image(assembly) orelse return error.NoImage;

    const klass = m.mono_class_from_name(img, "Scripts", "Entry") orelse return error.NoClass;
    const method = m.mono_class_get_method_from_name(klass, "Tick", 2) orelse return error.NoMethod;

    var args: [2]?*anyopaque = .{ null, null };
    const str = m.mono_string_new(child, "Zig -> c# via mono!") orelse return error.StringAlloc;
    args[0] = @ptrCast(str);
    var dt: c_int = 2;
    args[1] = @ptrCast(&dt);

    // Invoke
    var exec: ?*m.MonoObject = null;
    const ret_obj = m.mono_runtime_invoke(method, null, &args, &exec);
    if (exec != null) return error.ManagedException;

    const p = m.mono_object_unbox(@ptrCast(ret_obj));
    const result: c_int = @as(*c_int, @ptrCast(@alignCast(p))).*;
    std.debug.print("Managed Tick returned {d}\n", .{result});

    _ = m.mono_domain_set(root, 0);
    m.mono_domain_unload(child);
}


/// Load libraries and attach internal function calls available
/// to the root domain
fn register_internal() !void {
    m.mono_add_internal_call("StoryTree.Engine.Native::Log", @ptrCast(&native_log));
    m.mono_add_internal_call("StoryTree.Engine.Native::DeltaTime", @ptrCast(&native_delta_time));
}

pub fn main() !void {
    // Bootstrap
    // m.mono_set_dirs("mono/lib", "mono/etc");
    // m.mono_config_parse(null);

    const root = m.mono_jit_init_version("ZigGame", "v4.0.30319") orelse return error.MonoInitFailure;

    _ = m.mono_domain_assembly_open(root, "Managed/Engine.dll") orelse return error.OpenAssemblyFailed;
    try register_internal();

    try runScriptsInChildDomain();
}
