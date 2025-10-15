const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    try luaExe(b, target, optimize);
    try monoCSharpExe(b, target, optimize);
    try csharpExe(b, target, optimize);
}

pub fn luaExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    const lua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });

    const st_core_dep = b.dependency("storytree_core", .{
        .target = target,
        .optimize = optimize,
    });

    const lua_exe = b.addExecutable(.{
        .name = "zig_lua",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lua.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zlua", .module = lua_dep.module("zlua") },
                .{ .name = "storytree-core", .module = st_core_dep.module("storytree-core") },
            },
        }),
    });

    b.installArtifact(lua_exe);

    const run_lua_step = b.step("run-lua", "Run the lua scripting");
    const run_lua_cmd = b.addRunArtifact(lua_exe);
    run_lua_step.dependOn(&run_lua_cmd.step);
    run_lua_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_lua_cmd.addArgs(args);
    }
}

pub fn monoCSharpExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    const csharp_exe = b.addExecutable(.{
        .name = "zig_mono_csharp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/mono_csharp.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    b.installArtifact(csharp_exe);

    switch (@import("builtin").target.os.tag) {
        .windows => {
            csharp_exe.addLibraryPath(.{ .cwd_relative = "C:/Program Files/Mono/lib" });
            csharp_exe.linkSystemLibrary("mono-2.0-sgen");
        },
        .linux => {
            csharp_exe.linkSystemLibrary("mono-2.0");
            csharp_exe.linkSystemLibrary("pthread");
            csharp_exe.linkSystemLibrary("dl");
        },
        .macos => {
            csharp_exe.linkSystemLibrary("monosgen-2.0");
            csharp_exe.linkSystemLibrary("iconv");
            csharp_exe.linkSystemLibrary("pthread");
            csharp_exe.linkSystemLibrary("dl");
        },
        else => {
            csharp_exe.linkSystemLibrary("monosgen-2.0");
        }
    }

    const run_csharp_step = b.step("run-mono", "Run the mono csharp scripting");
    const run_csharp_cmd = b.addRunArtifact(csharp_exe);
    run_csharp_step.dependOn(&run_csharp_cmd.step);
    run_csharp_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_csharp_cmd.addArgs(args);
    }
}

pub fn csharpExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    const exe = b.addExecutable(.{
        .name = "zig_csharp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/csharp.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("dl");
        exe.linkSystemLibrary("pthread");
        exe.addRPath(.{ .cwd_relative = "$ORIGIN" }); // if you ship any of your own .so’s
    } else if (target.result.os.tag == .macos) {
        exe.addRPath(.{ .cwd_relative = "@loader_path" });
    } else if (target.result.os.tag == .windows) {
        // nothing special—LoadLibraryW is in kernel32
    }

    exe.addIncludePath(.{ .cwd_relative = "third_party/dotnet/include" });

    b.installArtifact(exe);

    const copy_managed = b.addInstallDirectory(.{
        .source_dir = .{ .cwd_relative = "Managed/Runtime/bin/Release/net8.0" },
        .install_dir = .bin,
        .install_subdir = "runtime",
    });
    const copy_runtime = b.addInstallDirectory(.{
        .source_dir = .{ .cwd_relative = "dotnet" },
        .install_dir = .bin,
        .install_subdir = "dotnet",
    });

    exe.step.dependOn(&copy_managed.step);
    exe.step.dependOn(&copy_runtime.step);

    const run_csharp_step = b.step("run-csharp", "Run the csharp scripting");
    const run_csharp_cmd = b.addRunArtifact(exe);
    run_csharp_step.dependOn(&run_csharp_cmd.step);
    run_csharp_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_csharp_cmd.addArgs(args);
    }
}
