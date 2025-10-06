const std = @import("std");

pub const MonoDomain = opaque {};
pub const MonoThread = opaque {};
pub const MonoAssembly = opaque {};
pub const MonoImage = opaque {};
pub const MonoClass = opaque {};
pub const MonoMethod = opaque {};
pub const MonoObject = opaque {};
pub const MonoString = opaque {};
pub const MonoArray = opaque {};

/// Initialize the mono c# jit which returns the root domain
pub extern fn mono_jit_init_version(root_domain_name: [*]const u8, runtime_version: [*]const u8) ?*MonoDomain;
/// Get the main domain (created with mono_jit_init_version)
pub extern fn mono_get_root_domain() callconv(.c) *MonoDomain;
/// Get the current domain
pub extern fn mono_domain_get() ?*MonoDomain;
/// Create a new child domain from the current root domain
pub extern fn mono_domain_create_appdomain(name: [*:0]const u8, config: ?[*:0]const u8) callconv(.c) ?*MonoDomain;
/// Makes the passed domain the active one for subsequent operations (assembly load, class lookup, etc)
pub extern fn mono_domain_set(domain: *MonoDomain, force: c_int) callconv(.c) c_int;
/// Attaches the current native thread to the passed domain so managed code can be run
pub extern fn mono_thread_attach(domain: *MonoDomain) callconv(.c) *MonoThread;
/// Unloads the domain and all assemblies loaded inside it
pub extern fn mono_domain_unload(domain: *MonoDomain) callconv(.c) void;

pub extern fn mono_set_dirs(lib_dir: [*:0]const u8, etc_dir: [*:0]const u8) callconv(.c) void;
pub extern fn mono_config_parse(filename: ?[*:0]const u8) callconv(.c) void;

pub extern fn mono_domain_assembly_open(domain: *MonoDomain, name: [*]const u8) ?*MonoAssembly;
pub extern fn mono_assembly_get_image(assembly: *MonoAssembly) ?*MonoImage;

pub extern fn mono_class_from_name(image: *MonoImage, name_space: [*]const u8, name: [*]const u8) ?*MonoClass;
pub extern fn mono_class_get_method_from_name(klass: *MonoClass, name: [*]const u8, param_count: c_int) ?*MonoMethod;

pub extern fn mono_string_new(domain: *MonoDomain, text: [*]const u8) ?*MonoString;
pub extern fn mono_string_to_utf8(s: *MonoString) ?[*]const u8;
pub extern fn mono_array_new(domain: *MonoDomain, eclass: *MonoClass, n: usize) ?*MonoArray;

pub extern fn mono_free(ptr: ?*anyopaque) void;

pub extern fn mono_runtime_invoke(method: *MonoMethod, obj: ?*MonoObject, params: [*]?*anyopaque, exc: ?*?*MonoObject) ?*MonoObject;

// internal call registration:
pub extern fn mono_add_internal_call(name: [*]const u8, method: *const anyopaque) void;

// boxing/unboxing (handy for ints/floats):
pub extern fn mono_value_box(domain: *MonoDomain, klass: *MonoClass, val: *const anyopaque) *MonoObject;
pub extern fn mono_object_unbox(obj: *MonoObject) *anyopaque;

// helpers to fetch common classes:
pub extern fn mono_get_string_class() *MonoClass;
pub extern fn mono_get_int32_class() *MonoClass;
