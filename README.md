# dns-checker

Minimal DNS checker that reads URLs from `urls.txt`, extracts domains, and prints resolved IP addresses.

## Requirements

- Zig 0.15.x (tested with 0.15.2)

## Build & Run

```sh
# build
zig build

# run
zig build run
```

### Modes

- `-Drelease` builds in ReleaseSafe mode
- `-Ddebug` builds in Debug mode
- `-Dstrip` strips debug symbols from binaries

`urls.txt` should contain one URL per line. Output is printed to stdout.
