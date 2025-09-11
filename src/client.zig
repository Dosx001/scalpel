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

var fd: posix.socket_t = undefined;
var buf: [1024]u8 = undefined;

pub fn main() void {
    fd = posix.socket(
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
    _ = message("client", .{}) catch unreachable;
    if (buf[0] == 0x0) {
        std.log.info("rejected", .{});
        return;
    }
    const json = message_json(
        \\{{"type":"window","url":"https://www.google.com/search?q=websocket","private":true}}
    , .{}, Msg) catch unreachable;
    _ = message(
        \\{{"type":"text","id":{d},"query":"h1"}}
    , .{json.value.tabId}) catch unreachable;
    _ = message(
        \\{{"type":"click","id":{d},"query":"h3"}}
    , .{json.value.tabId}) catch unreachable;
}

fn message_json(
    comptime fmt: []const u8,
    args: anytype,
    comptime T: type,
) !std.json.Parsed(T) {
    const len = try message(fmt, args);
    return try std.json.parseFromSlice(
        T,
        std.heap.page_allocator,
        buf[0..len],
        .{},
    );
}

fn message(
    comptime fmt: []const u8,
    args: anytype,
) !usize {
    _ = posix.send(
        fd,
        try std.fmt.bufPrint(&buf, fmt, args),
        0,
    ) catch |err| {
        std.log.err("send failed: {}", .{err});
        return err;
    };
    const len = try posix.read(fd, &buf);
    std.debug.print("{s}\n", .{buf[0..len]});
    return len;
}
