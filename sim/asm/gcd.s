# Euclid's GCD, RV32I: 32 pairs (a, b) of unsigned 32-bit numbers, software divide.
# gcd(a, b): while (b != 0) { t = a % b; a = b; b = t; }  (gcd_m.s uses the REMU instruction)
# Data: xorshift32 from seed 0x12345678 (x ^= x << 13; x ^= x >> 17; x ^= x << 5).
# Each pair takes the next two values, a first. Results g[i] at 0x200 (32 words).
# Checks: 599 remainder operations (test 2); checksum c = rotl(c, 1) ^ g[i] = 0x3BE5B733 (test 3).
# Result: mem[0x100] = checksum, mem[0x104] = remainder operations.
        .include "common.inc"
        .text
        .globl _start
_start:
        li   x3, 1
        li   x20, 0x200              # g
        li   x21, 32                 # pairs
        li   x22, 0x12345678         # xorshift state
        li   x23, 0                  # i
        li   x24, 0                  # remainder operations
pair:
        jal  x1, xorshift
        mv   x25, x22                # a
        jal  x1, xorshift
        mv   x26, x22                # b
euclid:
        beq  x26, x0, pair_done
        mv   x10, x25
        mv   x11, x26
        jal  x1, divu                # x12 = a % b
        mv   x25, x26
        mv   x26, x12
        addi x24, x24, 1
        jal  x0, euclid
pair_done:
        slli x5, x23, 2
        add  x5, x5, x20
        sw   x25, 0(x5)              # g[i]
        addi x23, x23, 1
        bne  x23, x21, pair

        li   x7, 0x100
        sw   x24, 4(x7)
        li   x3, 2                   # test 2: remainder operations
        li   x8, 599
        bne  x24, x8, fail

        li   x28, 0                  # checksum
        li   x23, 0
        mv   x5, x20
check:
        lw   x10, 0(x5)
        slli x29, x28, 1
        srli x28, x28, 31
        or   x28, x28, x29
        xor  x28, x28, x10
        addi x5, x5, 4
        addi x23, x23, 1
        bne  x23, x21, check
        sw   x28, 0(x7)
        li   x3, 3                   # test 3: checksum
        li   x8, 0x3BE5B733
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
