const std = @import("std");
const dns_checker = @import("dns_checker");
const dns = @import("dns");

pub fn main() !void {
    const filename = "urls.txt";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    var allocator = gpa.allocator();

    const urls = try dns_checker.urlsInFile(allocator, filename);
    defer {
        for (urls) |u| allocator.free(u);
        allocator.free(urls);
    }

    for (urls) |url| {
        std.debug.print("Found URL: {s}\n", .{url});

        const domain = dns_checker.domainFromUrl(allocator, url) catch |err| {
            std.debug.print("  Domain error: {s}\n", .{@errorName(err)});
            continue;
        };
        defer allocator.free(domain);

        std.debug.print("  Domain: {s}\n", .{domain});

        var addresses = dns.helpers.getAddressList(domain, 80, allocator) catch |err| {
            std.debug.print("  DNS error: {s}\n", .{@errorName(err)});
            continue;
        };
        defer addresses.deinit();

        for (addresses.addrs) |address| {
            // Render the address in human‑readable form (e.g. 93.184.216.34:80 or [2606:2800:...]:80).
            var buf: [128]u8 = undefined;
            // Use {f} to invoke Address.format and avoid ambiguous placeholder.
            const rendered = try std.fmt.bufPrint(&buf, "{f}", .{address});
            std.debug.print("    {s}\n", .{rendered});
        }
    }
}
