const std = @import("std");
const ws = @import("websocket.zig");

pub fn main() !void {
    ws.init() catch return;
}
