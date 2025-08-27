const std = @import("std");

const posix = std.posix;

pub fn init() !void {
    const fd = posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0) catch |e| {
        std.log.err("Server socket failed: {}", .{e});
        return;
    };
    defer posix.close(fd);
    posix.setsockopt(
        fd,
        posix.SOL.SOCKET,
        posix.SO.REUSEADDR,
        &std.mem.toBytes(@as(c_int, 1)),
    ) catch |e| {
        std.log.err("Server setsockopt failed: {}", .{e});
        return;
    };
    posix.setsockopt(
        fd,
        posix.SOL.SOCKET,
        posix.SO.REUSEPORT,
        &std.mem.toBytes(@as(c_int, 1)),
    ) catch |e| {
        std.log.err("Server setsockopt failed: {}", .{e});
        return;
    };
    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);
    posix.bind(fd, &addr.any, addr.getOsSockLen()) catch |e| {
        std.log.err("Server bind failed: {}", .{e});
        return;
    };
    posix.listen(fd, 10) catch |e| {
        std.log.err("Server listen failed: {}", .{e});
        return;
    };
    var buf: [1024]u8 = undefined;
    while (true) {
        const client_fd = posix.accept(fd, null, null, 0) catch |e| {
            std.log.err("Server accept failed: {}", .{e});
            return;
        };
        defer posix.close(client_fd);
        var len = posix.read(client_fd, &buf) catch |e| {
            std.log.err("Client read failed: {}", .{e});
            return;
        };
        std.debug.print("{s}\n", .{buf[0..len]});
        _ = posix.write(client_fd,
            \\\ HTTP/1.1 101 Switching Protocols\r
            \\\Upgrade: websocket\r
            \\\Connection: Upgrade\r
            \\\Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
            \\\\r\n
        ) catch |e| {
            std.log.err("Client write failed: {}", .{e});
            return;
        };
        while (true) {
            len = posix.read(client_fd, &buf) catch |e| {
                std.log.err("Client read failed: {}", .{e});
                return;
            };
            std.debug.print("{s}\n", .{buf[0..len]});
            _ = posix.write(client_fd, &buf) catch |e| {
                std.log.err("Client write failed: {}", .{e});
                return;
            };
            std.time.sleep(std.time.ns_per_ms * 100);
        }
    }
}
