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
            return e;
        };
        _ = posix.write(
            client_fd,
            try handshake(&buf),
        ) catch |e| {
            std.log.err("Client write failed: {}", .{e});
            return;
        };
        while (true) {
            len = posix.read(client_fd, &buf) catch |e| {
                std.log.err("Client read failed: {}", .{e});
                return;
            };
            std.debug.print("client: {s}\n", .{buf[0..len]});
            // _ = posix.write(client_fd, &buf) catch |e| {
            //     std.log.err("Client write failed: {}", .{e});
            //     return;
            // };
            std.time.sleep(std.time.ns_per_ms * 100);
        }
    }
}

fn handshake(buf: []u8) ![]const u8 {
    const header = "Sec-WebSocket-Key: ";
    var it = std.mem.splitScalar(u8, buf, '\n');
    var key: []const u8 = undefined;
    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, header)) {
            key = std.mem.trim(u8, line[header.len..], "\r");
            break;
        }
    } else return error.NotFound;
    var sha: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    std.crypto.hash.Sha1.hash(
        std.fmt.bufPrint(buf, "{s}258EAFA5-E914-47DA-95CA-C5AB0DC85B11", .{key}) catch |e| {
            std.log.err("Client write failed: {}", .{e});
            return e;
        },
        &sha,
        .{},
    );
    const encoder = std.base64.Base64Encoder.init(std.base64.standard_alphabet_chars, '=');
    var b64: [32]u8 = undefined;
    return std.fmt.bufPrint(
        buf,
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n",
        .{encoder.encode(&b64, &sha)},
    ) catch |e| {
        std.log.err("Client write failed: {}", .{e});
        return e;
    };
}
