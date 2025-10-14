const std = @import("std");

const hostfxr = @cImport({
    @cInclude("hostfxr.h");
});

const HostFxr_Handle = ?*anyopaque;

const TAG = @import("builtin").os.tag;

const char_t = if (TAG == .windows) u16 else u8;

const hostfxr_initialize_for_runtime_config_fn = fn (
    runtime_config_path: [*:0]const char_t,
    parameters: ?*anyopaque,
    host_context_handle: *?*anyopaque,
) callconv(.c) c_int;

const hostfxr_get_runtime_delegate_fn = fn (
    host_context_handle: ?*anyopaque,
    delegate_type: c_int,
    out_delegate: *?*anyopaque,
) callconv(.c) c_int;

const hostfxr_close_fn = fn (host_context_handle: ?*anyopaque) callconv(.c) c_int;

const load_assembly_and_get_function_pointer_fn = fn (
    assembly_path: [*:0]const char_t,
    type_name: [*:0]const char_t,
    method_name: [*:0]const char_t,
    delegate_type_name: ?[*:0]const char_t, // null for [UnmanagedCallersOnly]
    reserved: ?*anyopaque,
    out_fn: *?*anyopaque,
) callconv(.c) c_int;

fn toCharT(alloc: std.mem.Allocator, s: []const u8) ![:0]const char_t {
    if (TAG == .windows) {
        const w = try std.unicode.utf8ToUtf16LeAllocZ(alloc, s);
        return @ptrCast(w);
    } else {
        return try std.mem.concat(alloc, u8, &.{ s, &[_]u8{0} });
    }
}

fn dlopenHostFxrAbsolutePath(alloc: std.mem.Allocator, version: []const u8) !*anyopaque {
    // Compute ./dotnet/host/fxr/<ver>/hostfxr.(dll|so|dylib)
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_dir = try std.fs.selfExeDirPath(&buf);

    const libname = switch (TAG) {
        .windows => "hostfxr.dll",
        .macos => "libhostfxr.dylib",
        else => "libhostfxr.so",
    };

    const path = try std.fs.path.join(alloc, &.{ exe_dir, "dotnet", "host", "fxr", version, libname });
    defer alloc.free(path);

    return if (TAG == .windows) blk: {
        const Ext = struct {
            pub const DLL_DIRECTORY_COOKIE = *opaque {};
            pub const LOAD_LIBRARY_SEARCH_DEFAULT_DIRS: u32 = 0x00001000;
            extern "kernel32" fn SetDefaultDllDirectories(flags: u32) callconv(.winapi) std.os.windows.BOOL;
            extern "kernel32" fn AddDllDirectory(newDirectory: [*:0]const u16) callconv(.winapi) DLL_DIRECTORY_COOKIE;
            pub const LoadLibraryW = std.os.windows.LoadLibraryW;
        };

        _ = Ext.SetDefaultDllDirectories(Ext.LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
        // Add ./dotnet so transitive native deps resolve
        const dotnet_dir = try std.fs.path.join(alloc, &.{ exe_dir, "dotnet" });
        defer alloc.free(dotnet_dir);

        const dotnet_wide = try std.unicode.utf8ToUtf16LeAllocZ(alloc, dotnet_dir);
        defer alloc.free(dotnet_wide);

        _ = Ext.AddDllDirectory(dotnet_wide.ptr);

        const path_wide = try std.unicode.utf8ToUtf16LeAllocZ(alloc, path);
        defer alloc.free(path_wide);

        const h = try Ext.LoadLibraryW(path_wide.ptr);
        break :blk @ptrCast(h);
    } else blk: {
        const handle = std.c.dlopenZ(path.ptr, std.c.RTLD_LAZY | std.c.RTLD_LOCAL);
        if (handle == null) return error.HostFxrNotFound;
        break :blk handle;
    };
}

fn dlsym(handle: *anyopaque, name: [:0]const u8) ?*anyopaque {
    return if (TAG == .windows)
        @ptrCast(std.os.windows.kernel32.GetProcAddress(@ptrCast(@alignCast(handle)), name.ptr))
    else
        std.c.dlsym(handle, name.ptr);
}

const hostfxr_error_writer_fn = fn (msg: [*:0]const char_t) callconv(.c) void;
const hostfxr_set_error_writer_fn = fn (cb: ?*const hostfxr_error_writer_fn) callconv(.c) ?*const hostfxr_error_writer_fn;
fn writeHostfxrError(msg: [*:0]const char_t) callconv(.c) void {
    if (TAG == .windows) {
        const slice = std.mem.span(msg);
        const utf8 = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, slice) catch return;
        defer std.heap.page_allocator.free(utf8);
        std.debug.print("[hostfxr] {s}\n", .{utf8});
    } else {
        std.debug.print("[hostfxr] {s}\n", .{msg});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_dir = try std.fs.selfExeDirPath(&buf);

    const runtimeconfig_utf8 = try std.fs.path.join(allocator, &.{ exe_dir, "managed", "Runtime.runtimeconfig.json" });
    defer allocator.free(runtimeconfig_utf8);

    var fxr = try HostFxr.init(allocator, runtimeconfig_utf8);
    defer fxr.deinit();

    const assembly_path = try std.fs.path.join(allocator, &.{ exe_dir, "managed", "Runtime.dll" });
    defer allocator.free(assembly_path);

    const ping: *const fn () callconv(.c) u32 = @ptrCast(try fxr.load(
        allocator,
        assembly_path,
        "Runtime",
        "Host",
        "Ping",
    ));

    // 6) Call the managed function
    std.debug.print("Pong: {any}\n", .{ @call(.auto, ping, .{}) == 1 });

    // Done. You should see "[C#] Hello, world!" in stdout.
}

const HostFxr = struct {
    handle: *anyopaque,
    context: ?*anyopaque,

    close: *const hostfxr_close_fn,
    load_fn: *const load_assembly_and_get_function_pointer_fn,

    pub fn init(allocator: std.mem.Allocator, config: []const u8) !@This() {
        // 1) Load hostfxr from our fixed ./dotnet path
        const fxr_handle = try dlopenHostFxrAbsolutePath(allocator, "8.0.20");

        const set_error_writer: *const hostfxr_set_error_writer_fn = @ptrCast(dlsym(fxr_handle, "hostfxr_set_error_writer") orelse return error.NoSetErrorWriter);
        _ = set_error_writer(&writeHostfxrError);

        const init_fn: *const hostfxr_initialize_for_runtime_config_fn = @ptrCast(dlsym(fxr_handle, "hostfxr_initialize_for_runtime_config") orelse return error.SymbolMissing);
        const getRuntimeDelegate: *const hostfxr_get_runtime_delegate_fn = @ptrCast(dlsym(fxr_handle, "hostfxr_get_runtime_delegate") orelse return error.SymbolMissing);
        const close: *const hostfxr_close_fn = @ptrCast(dlsym(fxr_handle, "hostfxr_close") orelse return error.SymbolMissing);

        const runtimeconfig = try toCharT(allocator, config);
        defer allocator.free(runtimeconfig);

        // 3) Initialize runtime for our managed component
        var host_ctx: ?*anyopaque = null;
        const hr_init = init_fn(runtimeconfig.ptr, null, &host_ctx);
        if (hr_init != 0 or host_ctx == null) return error.InitRuntimeFailed;

        // 4) Get the "load_assembly_and_get_function_pointer" delegate
        var load_fn_any: ?*anyopaque = null;
        const hr_gd = getRuntimeDelegate(host_ctx, hostfxr.hdt_load_assembly_and_get_function_pointer, &load_fn_any);
        if (hr_gd != 0 or load_fn_any == null) return error.GetDelegateFailed;

        const load_fn: *const load_assembly_and_get_function_pointer_fn = @ptrCast(load_fn_any.?);

        return .{
            .handle = fxr_handle,
            .context = host_ctx,
            .close = close,
            .load_fn = load_fn,
        };
    }

    pub fn deinit(self: *@This()) void {
        _ = self.close(self.context);
    }

    pub fn load(
        self: *const @This(),
        allocator: std.mem.Allocator,
        assembly_path: []const u8,
        assembly_name: []const u8,
        /// Name of the class
        class: []const u8,
        /// Name of the method
        method: []const u8,
    ) !*anyopaque {
        const assembly_path_wide = try toCharT(allocator, assembly_path);
        defer allocator.free(assembly_path_wide);

        const type_name_utf8 = try std.fmt.allocPrint(allocator, "{s}, {s}", .{ class, assembly_name });
        defer allocator.free(type_name_utf8);
        const delegate_name_utf8 = try std.fmt.allocPrint(allocator, "{s}+{s}Delegate, {s}", .{ class, method, assembly_name });
        defer allocator.free(delegate_name_utf8);

        const type_name = try toCharT(allocator, type_name_utf8);
        defer allocator.free(type_name);
        const method_name = try toCharT(allocator, method);
        defer allocator.free(method_name);
        const delegate_name = try toCharT(allocator, delegate_name_utf8);
        defer allocator.free(delegate_name);

        var out_fn: ?*anyopaque = null;
        const hr_la = self.load_fn(
            assembly_path_wide.ptr,
            type_name.ptr,
            method_name.ptr,
            delegate_name.ptr,
            null,
            &out_fn,
        );

        if (hr_la != 0 or out_fn == null) return error.LoadFunctionFailed;

        return out_fn.?;
    }
};
