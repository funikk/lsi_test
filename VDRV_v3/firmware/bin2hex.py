#!/usr/bin/env python3
import sys
import struct

def bin2hex(bin_path, hex_path):
    with open(bin_path, "rb") as f:
        data = f.read()

    # Pad data to multiple of 4 bytes
    while len(data) % 4 != 0:
        data += b'\x00'

    words = [struct.unpack("<I", data[i:i+4])[0] for i in range(0, len(data), 4)]

    with open(hex_path, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")

    print(f"[SUCCESS] Converted {bin_path} -> {hex_path} ({len(words)} 32-bit words).")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 bin2hex.py <input.bin> <output.hex>")
        sys.exit(1)
    bin2hex(sys.argv[1], sys.argv[2])
