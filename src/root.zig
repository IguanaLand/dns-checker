const std = @import("std");

pub const max_file_size: usize = 10 * 1024 * 1024; // 10 MiB safety cap.

/// Parses `url` and returns the hostname (domain) portion.
/// The returned slice is allocated with `allocator`; caller must free it.
pub fn domainFromUrl(allocator: std.mem.Allocator, url: []const u8) ![]const u8 {
    const uri = try std.Uri.parse(url);

    // Extract host into a stack buffer first (Uri.getHost may return a borrowed slice).
    var buf: [std.Uri.host_name_max]u8 = undefined;
    const host = try uri.getHost(&buf);

    return try allocator.dupe(u8, host);
}

/// Reads `filename` and returns all tokens that parse as valid URLs.
/// Each returned string and the slice itself are allocated with `allocator`;
/// caller must free each entry and then free the slice.
pub fn urlsInFile(allocator: std.mem.Allocator, filename: []const u8) ![]const []const u8 {
    const file_data = try std.fs.cwd().readFileAlloc(allocator, filename, max_file_size);
    defer allocator.free(file_data);

    var urls = std.ArrayList([]const u8){};
    errdefer {
        for (urls.items) |u| allocator.free(u);
        urls.deinit(allocator);
    }

    var tokenizer = std.mem.tokenizeAny(u8, file_data, " \t\r\n\"'<>[](){}");
    while (tokenizer.next()) |raw_token| {
        const token = trimTrailingPunctuation(raw_token);
        if (token.len == 0) continue;

        if (std.Uri.parse(token) catch null) |_| {
            try urls.append(allocator, try allocator.dupe(u8, token));
        }
    }

    return try urls.toOwnedSlice(allocator);
}

/// Trims trailing punctuation characters commonly found after URLs in text.
fn trimTrailingPunctuation(bytes: []const u8) []const u8 {
    var end = bytes.len;
    while (end > 0) {
        const c = bytes[end - 1];
        switch (c) {
            '.', ',', ';', '!', '?', ')', ']', '}', '\'', '"' => end -= 1,
            else => break,
        }
    }
    return bytes[0..end];
}
