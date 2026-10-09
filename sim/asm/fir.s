# 16-tap FIR, RV32I: y[n] = sum_k h[k] * x[n-k], n = 15..63, software multiply.
# x[i] = ((i * 13) & 31) - 16 at 0x200 (64 words). h[k] = k - 8 at 0x300 (16 words).
# y at 0x400 (49 words). Result: mem[0x100] = sum of y = 0xFFFFFC70.
        .include "common.inc"
        .text
        .globl _start
_start:
        li   x3, 1
        li   x20, 0x200              # x
        li   x21, 0x300              # h
        li   x22, 0x400              # y
        li   x5, 0                   # fill x
        li   x6, 64
fill_x:
        slli x7, x5, 3               # i*13 = i*8 + i*4 + i
        slli x8, x5, 2
        add  x7, x7, x8
        add  x7, x7, x5
        andi x7, x7, 31
        addi x7, x7, -16
        slli x8, x5, 2
        add  x8, x8, x20
        sw   x7, 0(x8)
        addi x5, x5, 1
        bne  x5, x6, fill_x
        li   x5, 0                   # fill h
        li   x6, 16
fill_h:
        addi x7, x5, -8
        slli x8, x5, 2
        add  x8, x8, x21
        sw   x7, 0(x8)
        addi x5, x5, 1
        bne  x5, x6, fill_h

        li   x23, 15                 # n
        li   x24, 64
        li   x27, 0                  # checksum
loop_n:
        li   x25, 0                  # acc
        li   x26, 0                  # k
loop_k:
        slli x7, x26, 2
        add  x7, x7, x21
        lw   x10, 0(x7)              # h[k]
        sub  x8, x23, x26
        slli x8, x8, 2
        add  x8, x8, x20
        lw   x11, 0(x8)              # x[n-k]
        jal  x1, mul
        add  x25, x25, x10
        addi x26, x26, 1
        li   x7, 16
        bne  x26, x7, loop_k
        addi x7, x23, -15
        slli x7, x7, 2
        add  x7, x7, x22
        sw   x25, 0(x7)              # y[n-15]
        add  x27, x27, x25
        addi x23, x23, 1
        bne  x23, x24, loop_n

        li   x7, 0x100
        sw   x27, 0(x7)
        li   x3, 2
        li   x13, 0xFFFFFC70
        bne  x27, x13, fail
        PASS

# x10 = x10 * x11 (low 32 bits; correct for signed operands). Clobbers x12, x13.
mul:
        li   x12, 0
mul_loop:
        beq  x11, x0, mul_done
        andi x13, x11, 1
        beq  x13, x0, mul_skip
        add  x12, x12, x10
mul_skip:
        slli x10, x10, 1
        srli x11, x11, 1
        jal  x0, mul_loop
mul_done:
        addi x10, x12, 0
        jalr x0, 0(x1)

        FAIL_HANDLER
