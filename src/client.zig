const std = @import("std");

const posix = std.posix;

const Msg = struct {
    id: u32,
    tabId: u32,
};
const Payload = struct {
    type: []const u8,
    payload: []const u8,
};

pub fn main() void {
    const fd = posix.socket(
        posix.AF.INET,
        posix.SOCK.STREAM,
        0,
    ) catch |e| {
        std.log.err("socket failed: {}", .{e});
        return;
    };
    defer posix.close(fd);
    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);
    posix.connect(
        fd,
        &addr.any,
        addr.getOsSockLen(),
    ) catch |e| {
        std.log.err("connect failed: {}", .{e});
        return;
    };
    var buf: [1024]u8 = undefined;
    _ = posix.send(fd, "client", 0) catch |e| {
        std.log.err("send failed: {}", .{e});
        return;
    };
    var len = posix.read(fd, &buf) catch |e| {
        std.log.err("read failed: {}", .{e});
        return;
    };
    if (buf[0] == 0x0) {
        std.log.info("rejected", .{});
        return;
    }
    _ = posix.send(fd, std.fmt.bufPrint(
        &buf,
        \\{{"type":"text","payload":{{"id":{d},"query":"h1"}}}}
    ,
        .{284},
    ) catch unreachable, 0) catch |e| {
        std.log.err("send failed: {}", .{e});
        return;
    };
    len = posix.read(fd, &buf) catch |e| {
        std.log.err("read failed: {}", .{e});
        return;
    };
    std.log.info("read: {s}", .{buf[0..len]});
}
