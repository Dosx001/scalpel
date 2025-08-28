const std = @import("std");

const posix = std.posix;

const Msg = struct {
    status: bool,
    data: []const u8,
};

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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var buf: [1024]u8 = undefined;
    while (true) {
        const client_fd = posix.accept(fd, null, null, 0) catch |e| {
            std.log.err("Server accept failed: {}", .{e});
            continue;
        };
        defer posix.close(client_fd);
        var len = posix.read(client_fd, &buf) catch |e| {
            std.log.err("Client read failed: {}", .{e});
            continue;
        };
        _ = posix.write(
            client_fd,
            try handshake(&buf),
        ) catch |e| {
            std.log.err("Client write failed: {}", .{e});
            continue;
        };
        while (true) {
            len = posix.read(client_fd, &buf) catch |e| {
                std.log.err("Client read failed: {}", .{e});
                break;
            };
            const json = decode(&buf, allocator) catch break;
            defer json.deinit();
            std.debug.print("data: {s}\n", .{json.value.data});
            try message(&buf, client_fd, "pong");
            std.time.sleep(std.time.ns_per_ms * 500);
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

fn decode(buf: []u8, allocator: std.mem.Allocator) !std.json.Parsed(Msg) {
    var len: usize = (buf[1] & 0x7F);
    var index: usize =
        switch (len) {
            126 => blk: {
                len = (@as(u16, buf[2]) << 8) | buf[3];
                break :blk 4;
            },
            127 => blk: {
                len = 0;
                for (2..10) |i| {
                    len = (len << 8) | buf[i];
                }
                break :blk 10;
            },
            else => 2,
        };
    const key = buf[index .. index + 4];
    index += 4;
    const payload = buf[index .. index + len];
    for (payload, 0..) |*b, i| {
        b.* = b.* ^ key[i % 4];
    }
    return std.json.parseFromSlice(
        Msg,
        allocator,
        payload,
        .{},
    ) catch |e| {
        std.log.err("JSON parse failed: {}", .{e});
        return e;
    };
}

fn message(buf: []u8, fd: c_int, msg: []const u8) !void {
    if (msg.len < 126) {
        const slice = std.fmt.bufPrint(
            buf,
            "00{s}",
            .{msg},
        ) catch |e| {
            std.log.err("Message format failed: {}", .{e});
            return e;
        };
        buf[0] = 0x81;
        buf[1] = @intCast(msg.len);
        _ = posix.write(fd, slice) catch |e| {
            std.log.err("Server write failed: {}", .{e});
            return e;
        };
        return;
    }
    const slice = std.fmt.bufPrint(
        buf,
        "0000{s}",
        .{msg},
    ) catch |e| {
        std.log.err("Message format failed: {}", .{e});
        return e;
    };
    buf[0] = 0x81;
    buf[1] = 0x7E;
    buf[2] = @intCast((msg.len >> 8) & 0xFF);
    buf[3] = @intCast(msg.len & 0xFF);
    _ = posix.write(fd, slice) catch |e| {
        std.log.err("Server write failed: {}", .{e});
        return e;
    };
}
