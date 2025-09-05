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
        \\{{"type":"window","payload":{{"url":"https://www.google.com/search?q=websocket","private":true}}}}
    ,
        .{},
    ) catch unreachable, 0) catch |e| {
        std.log.err("send window failed: {}", .{e});
        return;
    };
    len = posix.read(fd, &buf) catch |e| {
        std.log.err("read window failed: {}", .{e});
        return;
    };
    std.debug.print("{s}\n", .{buf[0..len]});
    const json = std.json.parseFromSlice(
        Msg,
        std.heap.page_allocator,
        buf[0..len],
        .{},
    ) catch |e| {
        std.log.err("parse window failed: {}", .{e});
        return;
    };
    _ = posix.send(fd, std.fmt.bufPrint(
        &buf,
        \\{{"type":"text","payload":{{"id":{d},"query":"h3"}}}}
    ,
        .{json.value.tabId},
    ) catch unreachable, 0) catch |e| {
        std.log.err("send text failed: {}", .{e});
        return;
    };
    len = posix.read(fd, &buf) catch |e| {
        std.log.err("read text failed: {}", .{e});
        return;
    };
    std.debug.print("{s}\n", .{buf[0..len]});
}
