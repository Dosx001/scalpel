const std = @import("std");

const posix = std.posix;

var fd: std.posix.socket_t = undefined;
var client: std.posix.socket_t = undefined;

const path = "/tmp/scalpel.sock";

pub fn init() !void {
    fd = posix.socket(
        posix.AF.UNIX,
        posix.SOCK.STREAM,
        0,
    ) catch |e| {
        std.log.err("Server socket failed: {}", .{e});
        return e;
    };
    var addr: posix.sockaddr.un = undefined;
    addr.family = posix.AF.UNIX;
    @memcpy(addr.path[0..path.len], path);
    posix.bind(
        fd,
        @ptrCast(&addr),
        @intCast(path.len + 2),
    ) catch |e| {
        std.log.err("Server bind failed: {}", .{e});
        return e;
    };
    posix.listen(fd, 1) catch |e| {
        std.log.err("Server listen failed: {}", .{e});
        return e;
    };
}

pub fn close() void {
    posix.close(client);
}

pub fn unlink() void {
    posix.unlink(path) catch |e|
        std.log.err("unlink failed: {}", .{e});
}

pub fn accept() !void {
    client = posix.accept(fd, null, null, 0) catch |e| {
        std.log.err("Server accept failed: {}", .{e});
        return e;
    };
}

pub fn read(buf: []u8) !usize {
    return posix.read(
        client,
        buf,
    ) catch |e| {
        std.log.err("Server read failed: {}", .{e});
        return e;
    };
}

pub fn write(msg: []const u8) !void {
    posix.write(
        client,
        msg,
    ) catch |e| {
        std.log.err("Server write failed: {}", .{e});
        return e;
    };
}
