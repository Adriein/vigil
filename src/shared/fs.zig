const std: type = @import("std");

const Dir: type = std.fs.Dir;
const File: type = std.fs.File;

pub fn isDir(entry: Dir.Entry) bool {
    return entry.kind == File.Kind.directory;
}

pub fn isSymLink(entry: Dir.Entry) bool {
    return entry.kind == File.Kind.sym_link;
}
