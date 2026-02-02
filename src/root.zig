const std = @import("std");

pub const max_file_size: usize = 10 * 1024 * 1024; // 10 MiB safety cap.

pub const UrlLists = struct {
    valid: []const []const u8,
    invalid: []const []const u8,
};

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
    const lists = try urlListsInFile(allocator, filename);
    freeUrlList(allocator, lists.invalid);
    return lists.valid;
}

/// Reads `filename` and returns tokens split into valid and invalid URL lists.
/// Each returned string and the slices themselves are allocated with `allocator`;
/// caller must free each entry and then free both slices.
pub fn urlListsInFile(allocator: std.mem.Allocator, filename: []const u8) !UrlLists {
    const file_data = try std.fs.cwd().readFileAlloc(allocator, filename, max_file_size);
    defer allocator.free(file_data);

    var valid_urls: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (valid_urls.items) |u| allocator.free(u);
        valid_urls.deinit(allocator);
    }

    var invalid_urls: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (invalid_urls.items) |u| allocator.free(u);
        invalid_urls.deinit(allocator);
    }

    var tokenizer = std.mem.tokenizeAny(u8, file_data, " \t\r\n\"'<>[](){}");
    while (tokenizer.next()) |raw_token| {
        const token = trimTrailingPunctuation(raw_token);
        if (token.len == 0) continue;

        if (std.Uri.parse(token) catch null) |_| {
            try valid_urls.append(allocator, try allocator.dupe(u8, token));
        } else {
            try invalid_urls.append(allocator, try allocator.dupe(u8, token));
        }
    }

    return .{
        .valid = try valid_urls.toOwnedSlice(allocator),
        .invalid = try invalid_urls.toOwnedSlice(allocator),
    };
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

fn freeUrlList(allocator: std.mem.Allocator, list: []const []const u8) void {
    for (list) |u| allocator.free(u);
    allocator.free(list);
}
