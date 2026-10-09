# Bitwise CRC-32 (reflected, poly 0xEDB88320) of 64 bytes 0x00..0x3F at 0x200.
# Result: mem[0x100] = 0x100ECE8C (= zlib.crc32). Data-dependent branch per bit.
        .include "common.inc"
        .text
        .globl _start
_start:
        li   x3, 1
        li   x10, 0x200              # buffer
        li   x11, 0                  # i
        li   x12, 64
fill:
        add  x13, x10, x11
        sb   x11, 0(x13)
        addi x11, x11, 1
        bne  x11, x12, fill

        li   x14, -1                 # crc = 0xFFFFFFFF
        li   x15, 0xEDB88320         # polynomial
        li   x11, 0
byte_loop:
        add  x13, x10, x11
        lbu  x16, 0(x13)
        xor  x14, x14, x16
        li   x17, 8
bit_loop:
        andi x18, x14, 1
        srli x14, x14, 1
        beq  x18, x0, no_xor         # data-dependent branch
        xor  x14, x14, x15
no_xor:
        addi x17, x17, -1
        bne  x17, x0, bit_loop
        addi x11, x11, 1
        bne  x11, x12, byte_loop
        xori x14, x14, -1            # final xor

        li   x20, 0x100
        sw   x14, 0(x20)
        li   x3, 2
        li   x13, 0x100ECE8C
        bne  x14, x13, fail
        PASS
        FAIL_HANDLER
