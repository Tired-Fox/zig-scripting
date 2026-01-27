set windows-shell := ["powershell", "-c"]

mod compile 'Assets'

mono:
    @just compile::all
    zig build run-mono

lua:
    zig build run-lua

list:
    @just --list --list-submodules