const std = @import("std");
const mono = @import("mono.zig");

fn nativeLog(s: *mono.String) callconv(.c) void {
    const c_str = s.toUtf8();
    defer mono.free(@ptrCast(c_str));

    if (c_str) |str| {
        std.debug.print("[C#] {s}\n", .{ str });
    }
}

const TypeDef = struct {
    assembly: [:0]const u8,
    namespace: [:0]const u8,
    class: [:0]const u8,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.assembly);
        allocator.free(self.namespace);
        allocator.free(self.class);
    }
};

fn indexTypes(allocator: std.mem.Allocator, assembly: *mono.Assembly, base: *mono.Class) ![]TypeDef {
    const img = assembly.getImage() orelse return error.NoImage;
    const asm_name = assembly.getName().getName();

    const tdef = img.getTableInfo(mono.MONO_TABLE_TYPEDEF);
    const rows: usize = @intCast(tdef.getRows());

    var types: std.ArrayList(TypeDef) = .empty;
    defer types.deinit(allocator);
    errdefer for (types.items) |item| item.deinit(allocator);

    for (0..rows) |i| {
        var cols: [mono.MONO_TYPEDEF_SIZE]u32 = undefined;
        tdef.metadataDecodeRow(@intCast(i), &cols);

        const ns = img.metadataStringHeap(cols[mono.MONO_TYPEDEF_NAMESPACE]);
        const name = img.metadataStringHeap(cols[mono.MONO_TYPEDEF_NAME]);

        if (name.len > 0 and name[0] == '<') continue;

        const klass = img.classFromName(ns, name);
        if (klass == null) continue;

        if (klass.?.isSubclassOf(base)) {
            try types.append(allocator, .{
                .assembly = try allocator.dupeZ(u8, asm_name[0..]),
                .namespace = try allocator.dupeZ(u8, ns[0..]),
                .class = try allocator.dupeZ(u8, name[0..]),
            });
        }
    }

    return try types.toOwnedSlice(allocator);
}

fn runScriptsInChildDomain(allocator: std.mem.Allocator, base: *mono.Class) !void {
    const root = mono.getRootDomain();

    const child = root.createAppDomain("ScriptsDomain", null) orelse return error.CreateDomain;
    _ = child.set(false);
    _ = mono.Thread.attach(child);

    const assembly = child.openAssembly("Managed/Scripts.dll") orelse return error.OpenAssemblyFailed;
    const img = assembly.getImage() orelse return error.NoImage;

    const types = try indexTypes(allocator, assembly, base);
    defer {
        for (types) |t| t.deinit(allocator);
        allocator.free(types);
    }

    for (types) |t| {
        std.debug.print("{s}.{s}\n", .{ if (t.namespace.len == 0) "<GLOBAL>" else t.namespace, t.class });
        const klass = img.classFromName(t.namespace, t.class) orelse return error.NoClass;

        const instance = child.newObject(klass) orelse continue;
        const h = mono.GC.new(instance, false);

        instance.runtimeInit();

        if (klass.getMethodFromName("Awake", 0)) |method| {
            var exc: ?*mono.Object = null;
            _ = method.runtimeInvoke(instance, &.{}, &exc);
        }

        if (klass.getMethodFromName("Update", 1)) |method| {
            var exc: ?*mono.Object = null;

            var args: [1]?*anyopaque = .{ null };

            var dt: f32 = 0.016;
            args[0] = @ptrCast(&dt);

            _ = method.runtimeInvoke(instance, &args, &exc);
        }

        if (klass.getMethodFromName("Destroy", 0)) |method| {
            var exc: ?*mono.Object = null;
            _ = method.runtimeInvoke(instance, &.{}, &exc);
        }

        mono.GC.free(h);
    }

    _ = root.set(false);
    child.unload();
}

/// Load libraries and attach internal function calls available
/// to the root domain
fn registerInternal() !void {
    mono.addInternalCall("StoryTree.Engine.Native::Log", @ptrCast(&nativeLog));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Bootstrap
    // m.mono_set_dirs("mono/lib", "mono/etc");
    // m.mono_config_parse(null);

    const root = mono.jitInitVersion("ZigGame", "v4.0.30319") orelse return error.MonoInitFailure;

    const engine = root.openAssembly("Managed/Engine.dll") orelse return error.OpenAssemblyFailed;
    const img = engine.getImage() orelse return error.NoImage;

    try registerInternal();

    const behavior = img.classFromName("StoryTree.Engine", "Behavior") orelse return error.NoClass;

    try runScriptsInChildDomain(allocator, behavior);
}
