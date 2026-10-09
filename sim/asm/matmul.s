# 8x8 signed matrix multiply, RV32IM: C = A * B, C[i][j] = sum_k A[i][k] * B[k][j].
# Data: LCG x = x * 1103515245 + 12345 (seed 1), value = ((x >> 16) & 31) - 16.
# The first 64 values fill A (row-major), the next 64 fill B.
# A at 0x200, B at 0x300, C at 0x400 (64 words each).
# Result: mem[0x100] = checksum c = rotl(c, 1) ^ C[i][j] over C in row-major order = 0xD5B51F45.
        .include "common.inc"
        .text
        .globl _start
_start:
        li   x3, 1
        li   x20, 0x200              # A
        li   x21, 0x300              # B
        li   x22, 0x400              # C
        li   x5, 1                   # LCG state
        li   x6, 1103515245          # LCG multiplier
        li   x7, 12345               # LCG increment
        li   x8, 0x200               # fill pointer: A, then B
        li   x9, 0x400               # end of B
fill:
        mul  x5, x5, x6
        add  x5, x5, x7
        srli x10, x5, 16
        andi x10, x10, 31
        addi x10, x10, -16
        sw   x10, 0(x8)
        addi x8, x8, 4
        bne  x8, x9, fill

        li   x23, 0                  # i
        li   x26, 8
loop_i:
        li   x24, 0                  # j
loop_j:
        li   x27, 0                  # acc
        li   x25, 0                  # k
        slli x11, x23, 5             # &A[i][0] = A + i*32
        add  x11, x11, x20
        slli x12, x24, 2             # &B[0][j] = B + j*4
        add  x12, x12, x21
loop_k:
        lw   x13, 0(x11)             # A[i][k]
        lw   x14, 0(x12)             # B[k][j]
        mul  x15, x13, x14
        add  x27, x27, x15
        addi x11, x11, 4             # next column of A
        addi x12, x12, 32            # next row of B
        addi x25, x25, 1
        bne  x25, x26, loop_k
        slli x16, x23, 5             # &C[i][j] = C + i*32 + j*4
        slli x17, x24, 2
        add  x16, x16, x17
        add  x16, x16, x22
        sw   x27, 0(x16)
        addi x24, x24, 1
        bne  x24, x26, loop_j
        addi x23, x23, 1
        bne  x23, x26, loop_i

        li   x3, 2                   # checksum over C
        li   x8, 0x400
        li   x9, 0x500
        li   x28, 0
check:
        lw   x10, 0(x8)
        slli x29, x28, 1
        srli x28, x28, 31
        or   x28, x28, x29
        xor  x28, x28, x10
        addi x8, x8, 4
        bne  x8, x9, check
        li   x7, 0x100
        sw   x28, 0(x7)
        li   x13, 0xD5B51F45
        bne  x28, x13, fail
        PASS

        FAIL_HANDLER
