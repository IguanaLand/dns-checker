const std = @import("std");
const dns_checker = @import("dns_checker");
const dns = @import("dns");

fn workerTask(url: []const u8, wg: *std.Thread.WaitGroup) void {
    defer wg.finish();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Found URL: {s}\n", .{url});

    const domain = dns_checker.domainFromUrl(allocator, url) catch |err| {
        std.debug.print("  Domain error: {s}\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(domain);

    std.debug.print("  Domain: {s}\n", .{domain});

    var addresses = dns.helpers.getAddressList(domain, 80, allocator) catch |err| {
        std.debug.print("  DNS error: {s}\n", .{@errorName(err)});
        return;
    };
    defer addresses.deinit();

    for (addresses.addrs) |address| {
        var buf: [128]u8 = undefined;
        const rendered = std.fmt.bufPrint(&buf, "{f}", .{address}) catch |err| {
            std.debug.print("    Address format error: {s}\n", .{@errorName(err)});
            continue;
        };
        std.debug.print("    {s}\n", .{rendered});
    }
}

pub fn main() !void {
    const filename = "urls.txt";

    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const urls = try dns_checker.urlsInFile(allocator, filename);
    defer {
        for (urls) |u| allocator.free(u);
        allocator.free(urls);
    }

    const cpu_count = try std.Thread.getCpuCount();
    // const cpu_count = 1;

    std.debug.print("Starting DNS checks with {d} threads...\n", .{cpu_count});

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .stack_size = 128 * 1024, .n_jobs = cpu_count });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    for (urls) |url| {
        wg.start();
        pool.spawn(workerTask, .{ url, &wg }) catch |err| {
            wg.finish();
            return err;
        };
    }

    wg.wait();

    std.debug.print("All DNS checks complete.\n", .{});
}
