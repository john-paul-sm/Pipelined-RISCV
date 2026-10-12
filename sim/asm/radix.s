# Base conversion, RV32I: 64 unsigned 32-bit numbers, each converted to digits in a base from
# 2 to 33, software divide. (radix_m.s uses the DIVU and REMU instructions.)
# while (n != 0) { digit = n % base; n = n / base; }  Digits come out least significant first.
# Data: xorshift32 from seed 0x87654321 (x ^= x << 13; x ^= x >> 17; x ^= x << 5).
# For each number: n = next value, base = 2 + (next value & 31). The divisor is a runtime value.
# Checks: 639 digits (test 2); checksum c = rotl(c, 1) ^ digit over all digits = 0x237B1E5C
# (test 3). Result: mem[0x100] = checksum, mem[0x104] = digits.
        .include "common.inc"
        .text
        .globl _start
_start:
        li   x3, 1
        li   x21, 64                 # numbers
        li   x22, 0x87654321         # xorshift state
        li   x23, 0                  # i
        li   x24, 0                  # digits
        li   x28, 0                  # checksum
number:
        jal  x1, xorshift
        mv   x25, x22                # n
        jal  x1, xorshift
        andi x26, x22, 31
        addi x26, x26, 2             # base
digit:
        beq  x25, x0, number_done
        mv   x10, x25
        mv   x11, x26
        jal  x1, divu                # x10 = n / base, x12 = n % base
        mv   x25, x10
        slli x29, x28, 1             # c = rotl(c, 1) ^ digit
        srli x28, x28, 31
        or   x28, x28, x29
        xor  x28, x28, x12
        addi x24, x24, 1
        jal  x0, digit
number_done:
        addi x23, x23, 1
        bne  x23, x21, number

        li   x7, 0x100
        sw   x28, 0(x7)
        sw   x24, 4(x7)
        li   x3, 2                   # test 2: digits
        li   x8, 639
        bne  x24, x8, fail
        li   x3, 3                   # test 3: checksum
        li   x8, 0x237B1E5C
        bne  x28, x8, fail
        PASS

# x22 = xorshift32(x22). Clobbers x6.
xorshift:
        slli x6, x22, 13
        xor  x22, x22, x6
        srli x6, x22, 17
        xor  x22, x22, x6
        slli x6, x22, 5
        xor  x22, x22, x6
        jalr x0, 0(x1)

# Unsigned restoring division, 1 quotient bit per iteration (x11 != 0).
# x10 = x10 / x11, x12 = x10 % x11. Clobbers x13, x14, x15.
divu:
        li   x12, 0                  # remainder
        li   x13, 32                 # bits left
divu_loop:
        srli x15, x12, 31            # bit shifted out of the remainder
        srli x14, x10, 31            # next dividend bit
        slli x12, x12, 1
        or   x12, x12, x14
        slli x10, x10, 1             # quotient bits enter at bit 0
        bne  x15, x0, divu_subtract  # remainder >= 2^32 > divisor
        bltu x12, x11, divu_next
divu_subtract:
        sub  x12, x12, x11
        ori  x10, x10, 1
divu_next:
        addi x13, x13, -1
        bne  x13, x0, divu_loop
        jalr x0, 0(x1)

        FAIL_HANDLER
