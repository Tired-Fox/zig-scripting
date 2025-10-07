const std = @import("std");

extern fn mono_jit_init_version(root_domain_name: [*:0]const u8, runtime_version: [*:0]const u8) ?*Domain;
/// Initialize the mono c# jit which returns the root domain
pub fn jitInitVersion(root_domain_name: [:0]const u8, runtime_version: [:0]const u8) ?*Domain {
    return mono_jit_init_version(root_domain_name.ptr, runtime_version.ptr);
}

extern fn mono_get_root_domain() callconv(.c) *Domain;
/// Get the main domain (created with mono_jit_init_version)
pub fn getRootDomain() *Domain {
    return mono_get_root_domain();
}

extern fn mono_set_dirs(lib_dir: [*:0]const u8, etc_dir: [*:0]const u8) callconv(.c) void;
pub fn setDirs(lib_dirs: [:0]const u8, etc_dir: [:0]const u8) void {
    mono_set_dirs(lib_dirs.ptr, etc_dir.ptr);
}

extern fn mono_config_parse(filename: ?[*:0]const u8) callconv(.c) void;
pub fn configParse(filename: [:0]const u8) void {
    mono_config_parse(filename.ptr);
}

extern fn mono_free(ptr: ?*anyopaque) void;
pub fn free(ptr: ?*anyopaque) void {
    mono_free(ptr);
}

extern fn mono_add_internal_call(name: [*:0]const u8, method: *const anyopaque) void;
// internal call registration
pub fn addInternalCall(name: [:0]const u8, method: *const anyopaque) void {
    mono_add_internal_call(name.ptr, method);
}

// helpers to fetch common classes:

extern fn mono_get_string_class() *Class;
pub fn getStringClass() *Class {
    return mono_get_string_class();
}

extern fn mono_get_int32_class() *Class;
pub fn getInt32Class() *Class {
    return mono_get_int32_class();
}

pub const Domain = opaque {
    extern fn mono_domain_get() ?*Domain;
    extern fn mono_domain_create_appdomain(name: [*:0]const u8, config: ?[*:0]const u8) callconv(.c) ?*Domain;
    extern fn mono_domain_set(domain: *Domain, force: c_int) callconv(.c) c_int;
    extern fn mono_domain_unload(domain: *Domain) callconv(.c) void;
    extern fn mono_domain_assembly_open(domain: *Domain, name: [*:0]const u8) callconv(.c) ?*Assembly;
    extern fn mono_string_new(domain: *Domain, text: [*:0]const u8) callconv(.c) ?*String;
    extern fn mono_array_new(domain: *Domain, class: *Class, n: usize) callconv(.c) ?*Array;
    extern fn mono_object_new(domain: *Domain, class: *Class) callconv(.c) ?*Object;
    extern fn mono_value_box(domain: *Domain, class: *Class, val: *const anyopaque) callconv(.c) *Object;

    /// Create a new child domain from the current root domain
    pub fn createAppDomain(_: *Domain, name: [:0]const u8, config: ?[:0]const u8) ?*Domain {
        return mono_domain_create_appdomain(name.ptr, if (config) |c| c.ptr else null);
    }

    /// Get the current domain
    pub fn get() ?*Domain {
        return mono_domain_get();
    }

    /// Makes the passed domain the active one for subsequent operations (assembly load, class lookup, etc)
    pub fn set(self: *Domain, force: bool) c_int {
        return mono_domain_set(self, @intFromBool(force));
    }

    /// Unloads the domain and all assemblies loaded inside it
    pub fn unload(self: *Domain) void {
        mono_domain_unload(self);
    }

    pub fn openAssembly(self: *Domain, name: [:0]const u8) ?*Assembly {
        return mono_domain_assembly_open(self, name.ptr);
    }

    pub fn newString(self: *Domain, text: [:0]const u8) ?*String {
        return mono_string_new(self, text.ptr);
    }

    pub fn newArray(self: *Domain, eclass: *Class, n: usize) ?*Array {
        return mono_array_new(self, eclass, n);
    }

    pub fn newObject(self: *Domain, class: *Class) ?*Object{
        return mono_object_new(self, class);
    }

    pub fn box(self: *Domain, klass: *Class, val: anytype) *Object {
        return mono_value_box(self, klass, @ptrCast(val));
    }
};

pub const Thread = opaque {
    extern fn mono_thread_attach(domain: *Domain) callconv(.c) *Thread;

    /// Attaches the current native thread to the passed domain so managed code can be run
    pub fn attach(domain: *Domain) *Thread {
        return mono_thread_attach(domain);
    }
};

pub const Assembly = opaque {
    extern fn mono_assembly_get_image(assembly: *Assembly) callconv(.c) ?*Image;
    extern fn mono_assembly_get_name(assembly: *Assembly) callconv(.c) *AssemblyName;

    pub fn getImage(self: *Assembly) ?*Image {
        return mono_assembly_get_image(self);
    }

    pub fn getName(self: *Assembly) *AssemblyName {
        return mono_assembly_get_name(self);
    }
};

pub const AssemblyName = opaque {
    extern fn mono_assembly_name_get_name(aname: *AssemblyName) callconv(.c) [*:0]const u8;

    pub fn getName(self: *AssemblyName) [:0]const u8 {
        return std.mem.sliceTo(mono_assembly_name_get_name(self), 0);
    }
};

pub const Image = opaque {
    extern fn mono_class_from_name(image: *Image, namespace: [*:0]const u8, name: [*:0]const u8) callconv(.c) ?*Class;
    extern fn mono_image_get_table_info(image: *Image, table_id: c_int) callconv(.c) *TableInfo;
    extern fn mono_metadata_string_heap(image: *Image, index: u32) callconv(.c) [*:0]const u8; // NUL-terminated UTF-8

    pub fn classFromName(self: *Image, namespace: [:0]const u8, name: [:0]const u8) ?*Class {
        return mono_class_from_name(self, namespace.ptr, name.ptr);
    }

    pub fn getTableInfo(self: *Image, table_id: c_int) *TableInfo {
        return mono_image_get_table_info(self, table_id);
    }

    pub fn metadataStringHeap(self: *Image, index: u32) [:0]const u8 {
        return std.mem.sliceTo(mono_metadata_string_heap(self, index), 0);
    }
};

pub const MONO_TABLE_TYPEDEF: c_int = 0x02;

// Number of columns in the TypeDef table
pub const MONO_TYPEDEF_SIZE = 6;

// Column indices in the TypeDef table row
pub const MONO_TYPEDEF_FLAGS = 0; // TypeAttributes
pub const MONO_TYPEDEF_NAME = 1; // string heap index
pub const MONO_TYPEDEF_NAMESPACE = 2; // string heap index
pub const MONO_TYPEDEF_EXTENDS = 3; // TypeRef/TypeDef coded index
pub const MONO_TYPEDEF_FIELD_LIST = 4; // index into Field table
pub const MONO_TYPEDEF_METHOD_LIST = 5; // index into MethodDef table

pub const TableInfo = opaque {
    extern fn mono_table_info_get_rows(table: *TableInfo) callconv(.c) c_int;
    extern fn mono_metadata_decode_row(
        table: *const TableInfo,
        idx: c_int,
        // must point to an array of size MONO_TYPEDEF_SIZE
        res: [*]u32,
        res_size: c_int,
    ) callconv(.c) void;

    pub fn getRows(self: *TableInfo) c_int {
        return mono_table_info_get_rows(self);
    }

    pub fn metadataDecodeRow(self: *TableInfo, idx: c_int, res: []u32) void {
        mono_metadata_decode_row(self, idx, res.ptr, @intCast(res.len));
    }
};

pub const Class = opaque {
    extern fn mono_class_get_method_from_name(klass: *Class, name: [*:0]const u8, param_count: c_int) callconv(.c) ?*Method;
    extern fn mono_class_get_parent(klass: *Class) callconv(.c) ?*Class;
    extern fn mono_class_is_subclass_of(klass: *Class, parent: *Class) callconv(.c) bool;
    extern fn mono_class_is_assignable_from(iface: *Class, klass: *Class) callconv(.c) bool;

    pub fn getMethodFromName(self: *Class, name: [:0]const u8, param_count: u32) ?*Method {
        return mono_class_get_method_from_name(self, name.ptr, @intCast(param_count));
    }

    pub fn getParent(self: *Class) ?*Class {
        return mono_class_get_parent(self);
    }

    pub fn isSubclassOf(self: *Class, parent: *Class) bool {
        return mono_class_is_subclass_of(self, parent);
    }

    pub fn isAssignableFrom(self: *Class, target: *Class) bool {
        return mono_class_is_assignable_from(self, target);
    }
};

pub const Method = opaque {
    extern fn mono_runtime_invoke(method: *Method, obj: ?*Object, params: [*]?*anyopaque, exc: ?*?*Object) callconv(.c) ?*Object;

    pub fn runtimeInvoke(self: *Method, obj: ?*Object, params: []?*anyopaque, exc: ?*?*Object) ?*Object {
        return mono_runtime_invoke(self, obj, params.ptr, exc);
    }
};

pub const GC = opaque {
    extern fn mono_gchandle_new(obj: *Object, pinned: c_int) callconv(.c) u32;
    extern fn mono_gchandle_get_target(handle: u32) callconv(.c) ?*Object;
    extern fn mono_gchandle_free(handle: u32) callconv(.c) void;

    pub fn new(obj: *Object, pinned: bool) u32 {
        return mono_gchandle_new(obj, @intFromBool(pinned));
    }

    pub fn getTarget(handle: u32) ?*Object {
        return mono_gchandle_get_target(handle);
    }

    pub fn free(handle: u32) void {
        mono_gchandle_free(handle);
    }
};

pub const Object = opaque {
    extern fn mono_object_unbox(obj: *Object) callconv(.c) *anyopaque;
    extern fn mono_runtime_object_init(obj: *Object) callconv(.c) void;

    pub fn runtimeInit(self: *Object) void {
        mono_runtime_object_init(self);
    }

    pub fn unbox(self: *Object, T: type) *T {
        const p = mono_object_unbox(self);
        return @ptrCast(@alignCast(p));
    }
};

pub const String = opaque {
    extern fn mono_string_to_utf8(s: *String) callconv(.c) ?[*:0]u8;

    // Must call free on returned value
    pub fn toUtf8(self: *String) ?[:0]u8 {
        return std.mem.sliceTo(mono_string_to_utf8(self), 0);
    }
};

pub const Array = opaque {};
