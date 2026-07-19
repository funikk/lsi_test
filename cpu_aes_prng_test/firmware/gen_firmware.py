#!/usr/bin/env python3
import subprocess
import sys
import struct
import os

def main():
    fw_dir = os.path.dirname(os.path.abspath(__file__))

    # GCC build command
    gcc_cmd = [
        "riscv64-unknown-elf-gcc",
        "-march=rv32i",
        "-mabi=ilp32",
        "-Os",
        "-fno-delete-null-pointer-checks",
        "-ffreestanding",
        "-nostdlib",
        "-T", os.path.join(fw_dir, "sections.lds"),
        os.path.join(fw_dir, "start.S"),
        os.path.join(fw_dir, "main.c"),
        "-o", os.path.join(fw_dir, "firmware.elf")
    ]

    print("[BUILD] Compiling C firmware with GCC:", " ".join(gcc_cmd))
    res = subprocess.run(gcc_cmd)
    if res.returncode != 0:
        print("[ERROR] GCC Compilation failed!")
        sys.exit(1)

    # Objcopy to binary
    objcopy_cmd = [
        "riscv64-unknown-elf-objcopy",
        "-O", "binary",
        os.path.join(fw_dir, "firmware.elf"),
        os.path.join(fw_dir, "firmware.bin")
    ]

    res = subprocess.run(objcopy_cmd)
    if res.returncode != 0:
        print("[ERROR] Objcopy failed!")
        sys.exit(1)

    # Read binary and write 32-bit hex words
    bin_path = os.path.join(fw_dir, "firmware.bin")
    hex_path = os.path.join(fw_dir, "firmware.hex")

    with open(bin_path, "rb") as f:
        data = f.read()

    # Pad data to multiple of 4 bytes
    while len(data) % 4 != 0:
        data += b'\x00'

    words = [struct.unpack("<I", data[i:i+4])[0] for i in range(0, len(data), 4)]

    with open(hex_path, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")

    print(f"[SUCCESS] C firmware compiled into firmware.hex ({len(words)} 32-bit words).")

if __name__ == "__main__":
    main()
