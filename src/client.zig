const std = @import("std");

const posix = std.posix;

pub fn main() void {
    const fd = posix.socket(
        posix.AF.UNIX,
        posix.SOCK.STREAM,
        0,
    ) catch |e| {
        std.log.err("socket failed: {}", .{e});
        return;
    };
    var addr: posix.sockaddr.un = undefined;
    addr.family = posix.AF.UNIX;
    const path = "/tmp/scalpel.sock";
    @memcpy(addr.path[0..path.len], path);
    posix.connect(fd, @ptrCast(&addr), @intCast(path.len + 2)) catch |e| {
        std.log.err("connect failed: {}", .{e});
        return;
    };
    defer posix.close(fd);
    _ = posix.send(fd,
        \\{"type":"window","payload":"http://www.google.com"}
    , 0) catch |e| {
        std.log.err("send failed: {}", .{e});
        return;
    };
}
