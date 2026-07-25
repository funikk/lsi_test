# Standalone Makefile for RISC-V Firmware

CROSS_COMPILE ?= riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
PYTHON  = python3

CFLAGS  = -march=rv32i -mabi=ilp32 -Os -fno-delete-null-pointer-checks -ffreestanding -nostdlib
LDFLAGS = -T sections.lds

SRCS_S = start.S
SRCS_C = main.c
ELF    = firmware.elf
BIN    = firmware.bin
HEX    = firmware.hex
DIS    = firmware.dis

.PHONY: all clean disassemble

all: $(HEX) $(DIS)

$(ELF): $(SRCS_S) $(SRCS_C) sections.lds
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS_S) $(SRCS_C) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(HEX): $(BIN) bin2hex.py
	$(PYTHON) bin2hex.py $< $@

disassemble: $(DIS)

$(DIS): $(ELF)
	$(OBJDUMP) -d $< > $@

clean:
	rm -f $(ELF) $(BIN) $(HEX) $(DIS)
