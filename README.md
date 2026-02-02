# dns-checker

Small, fast DNS checker that reads URLs from `urls.txt`, extracts domains, and resolves them in parallel.
Each URL is processed on a worker thread, and the resolved IP addresses are printed to stdout.

## Requirements

- Zig 0.15.x (tested with 0.15.2)

## Build & Run

```sh
# build
zig build

# run
zig build run
```

## Usage

- Put one URL per line in `urls.txt`.
- The tool extracts the domain from each URL and resolves it using DNS.
- Results are printed to stdout, one URL at a time.

Example input:

```txt
https://example.com
http://openai.com
```

Example output:

```txt
Starting DNS checks with 8 threads...
Found URL: https://example.com
  Domain: example.com
    93.184.216.34
All DNS checks complete.
```

### Modes

- `-Drelease` builds in ReleaseSafe mode
- `-Ddebug` builds in Debug mode
- `-Dstrip` strips debug symbols from binaries
- `-Dvalgrind` uses a baseline CPU feature set for Valgrind compatibility

#### Valgrind Example

```sh
zig build -Dvalgrind

valgrind --tool=massif --pages-as-heap=yes --stacks=yes ./zig-out/bin/dns_checker
ms_print massif.out.<pid>
```

## Notes

- DNS lookups currently resolve against port 80.
- The number of worker threads defaults to the CPU count.
