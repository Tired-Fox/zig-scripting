const std = @import("std");
const zig_script = @import("zig_script");

const st_core = @import("storytree-core");

const Window = st_core.window.Window;
const WindowOptions = st_core.window.Options;
const EventLoop = st_core.event.EventLoop;

const zlua = @import("zlua");
const Lua = zlua.Lua;

const LuaEventLoop = struct {
    event_loop: *EventLoop,

    pub fn createWindow(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);
        const options = try lua.toStruct(WindowOptions, null, true, 2);

        const win = try self.event_loop.createWindow(options);

        try newUserdata(lua, LuaWindow{ .window = win });
        return 1;
    }

    pub fn isActive(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);
        lua.pushBoolean(self.event_loop.isActive());
        return 1;
    }

    pub fn wait(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);
        try self.event_loop.wait();
        return 0;
    }

    pub fn poll(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);
        try self.event_loop.poll();
        return 0;
    }

    pub fn pop(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);

        const event = self.event_loop.pop();

        if (event) |e| {
            lua.newTable();
            _ = lua.pushString(@tagName(e));
            lua.setField(-2, "type");

            switch (e) {
                .theme => |theme| {
                    _ = lua.pushString(@tagName(theme));
                    lua.setField(-2, "payload");
                },
                .window => |window| {
                    lua.newTable();
                    _ = lua.pushString(@tagName(window.event));
                    lua.setField(-2, "type");

                    try newUserdata(lua, LuaWindow{ .window = window.target });
                    lua.setField(-2, "target");

                    switch (window.event) {
                        .close => lua.pushNil(),
                        .resize => |v| try lua.pushAny(v),
                        .focused => |v| try lua.pushAny(v),
                        .key_input => |v| try lua.pushAny(v),
                        .mouse_input => |v| try lua.pushAny(v),
                        .mouse_move => |v| try lua.pushAny(v),
                        .mouse_scroll => |v| try lua.pushAny(v),
                        .menu => |v| try lua.pushAny(v),
                        .system_tray => |v| try lua.pushAny(v),
                        .thumb => |v| try lua.pushAny(v),
                    }
                    lua.setField(-2, "event");

                    lua.setField(-2, "payload");
                }
            }
        } else {
            lua.pushNil();
        }

        return 1;
    }

    pub fn closeWindow(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);
        const id = try lua.toInteger(2);
        self.event_loop.closeWindow(@intCast(id));
        return 0;
    }
};

const LuaWindow = struct {
    window: *Window,

    pub fn show(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);
        self.window.show();
        return 0;
    }

    pub fn id(lua: *Lua) !i32 {
        const self = try lua.toUserdata(@This(), 1);
        lua.pushInteger(@intCast(self.window.id()));
        return 1;
    }
};

fn newUserdata(lua: *Lua, value: anytype) !void {
    const T = @TypeOf(value);
    const Info = @typeInfo(T).@"struct";

    const el = lua.newUserdata(T, Info.fields.len);
    el.* = value;

    var name: []const u8 = @typeName(T);
    if (std.mem.containsAtLeast(u8, name, 1, ".")) {
        var it = std.mem.splitBackwardsScalar(u8, name, '.');
        name = it.next().?;
    }
    var value_name: [256:0]u8 = std.mem.zeroes([256:0]u8);
    @memcpy(value_name[0..name.len], name);

    if (lua.newMetatable(&value_name)) {
        // Duplicate metatable and add __index function
        lua.pushValue(-1);
        lua.setField(-2, "__index");

        inline for(Info.decls) |decl| {
            // Add helloworld function
            lua.pushFunction(zlua.wrap(@field(T, decl.name)));
            lua.setField(-2, decl.name);
        }
    } else |_| {}

    // Assign metatable to the userdata
    lua.setMetatable(-2);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var lua = try zlua.Lua.init(allocator);
    defer lua.deinit();

    const event_loop = try EventLoop.init(allocator);
    defer event_loop.deinit();

    try newUserdata(lua, LuaEventLoop{ .event_loop = event_loop });
    lua.setGlobal("EventLoop");

    lua.openLibs();
    try lua.doFile("windowing.lua");
}
