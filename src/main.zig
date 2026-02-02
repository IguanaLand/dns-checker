const std = @import("std");
const dns_checker = @import("dns_checker");
const dns = @import("dns");

fn workerTask(
    allocator: std.mem.Allocator,
    domain: []const u8,
    results: []bool,
    index: usize,
    wg: *std.Thread.WaitGroup,
) void {
    defer wg.finish();

    std.debug.print("Checking domain: {s}\n", .{domain});

    var addresses = dns.helpers.getAddressList(domain, 80, allocator) catch |err| {
        std.debug.print("  DNS error: {s}\n", .{@errorName(err)});
        return;
    };
    defer addresses.deinit();

    if (addresses.addrs.len == 0) {
        std.debug.print("  No addresses found\n", .{});
        return;
    }

    results[index] = true;

    for (addresses.addrs) |address| {
        var buf: [128]u8 = undefined;
        const rendered = std.fmt.bufPrint(&buf, "{f}", .{address}) catch |err| {
            std.debug.print("    Address format error: {s}\n", .{@errorName(err)});
            continue;
        };
        std.debug.print("    {s}\n", .{rendered});
    }
}

fn writeLines(filename: []const u8, lines: []const []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
    defer file.close();

    var buf: [4096]u8 = undefined;
    var writer = file.writer(&buf);
    for (lines) |line| {
        try writer.interface.writeAll(line);
        try writer.interface.writeByte('\n');
    }
}

pub fn main() !void {
    const filename = "urls.txt";
    const invalid_domain_index = std.math.maxInt(usize);

    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const urls = try dns_checker.urlsInFile(allocator, filename);
    defer {
        for (urls) |u| allocator.free(u);
        allocator.free(urls);
    }

    var domain_index: std.StringHashMapUnmanaged(usize) = .{};
    defer domain_index.deinit(allocator);

    var domains: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (domains.items) |d| allocator.free(d);
        domains.deinit(allocator);
    }

    var url_domain_indices: std.ArrayListUnmanaged(usize) = .{};
    errdefer url_domain_indices.deinit(allocator);
    try url_domain_indices.ensureTotalCapacity(allocator, urls.len);

    for (urls) |url| {
        const domain = dns_checker.domainFromUrl(allocator, url) catch |err| {
            std.debug.print("Domain error for {s}: {s}\n", .{ url, @errorName(err) });
            url_domain_indices.appendAssumeCapacity(invalid_domain_index);
            continue;
        };

        if (domain_index.get(domain)) |idx| {
            allocator.free(domain);
            url_domain_indices.appendAssumeCapacity(idx);
            continue;
        }

        const idx = domains.items.len;
        try domains.append(allocator, domain);
        try domain_index.put(allocator, domain, idx);
        url_domain_indices.appendAssumeCapacity(idx);
    }

    const cpu_count = try std.Thread.getCpuCount();
    // const cpu_count = 1;

    std.debug.print("Starting DNS checks with {d} threads...\n", .{cpu_count});

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .stack_size = 128 * 1024, .n_jobs = cpu_count });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    const domain_reachable = try allocator.alloc(bool, domains.items.len);
    defer allocator.free(domain_reachable);
    @memset(domain_reachable, false);

    for (domains.items, 0..) |domain, idx| {
        wg.start();
        pool.spawn(workerTask, .{ allocator, domain, domain_reachable, idx, &wg }) catch |err| {
            wg.finish();
            return err;
        };
    }

    wg.wait();

    var valid_urls: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer valid_urls.deinit(allocator);

    var invalid_urls: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer invalid_urls.deinit(allocator);

    for (urls, 0..) |url, i| {
        const idx = url_domain_indices.items[i];
        if (idx == invalid_domain_index) {
            try invalid_urls.append(allocator, url);
            continue;
        }

        if (domain_reachable[idx]) {
            try valid_urls.append(allocator, url);
        } else {
            try invalid_urls.append(allocator, url);
        }
    }

    try writeLines("valid_urls.txt", valid_urls.items);
    try writeLines("invalid_urls.txt", invalid_urls.items);

    for (domains.items) |d| allocator.free(d);
    domains.deinit(allocator);
    url_domain_indices.deinit(allocator);
    valid_urls.deinit(allocator);
    invalid_urls.deinit(allocator);

    std.debug.print("All DNS checks complete.\n", .{});
}
