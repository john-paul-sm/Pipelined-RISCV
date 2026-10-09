# Recursive Tower of Hanoi, 8 discs, pegs 1 -> 3 via 2.
# Each move: checksum = checksum * 31 + ((from << 2) | to), moves++.
# Result: mem[0x100] = 255 moves, mem[0x104] = checksum 0x8330943C.
# Stress: deep call/return through jal/jalr, stack loads/stores.
        .include "common.inc"
        .text
        .globl _start
_start:
        li   x2, 0x7F0               # sp (below tohost)
        li   x8, 0                   # s0 = checksum
        li   x9, 0                   # s1 = moves
        li   x10, 8                  # n
        li   x11, 1                  # from
        li   x12, 3                  # to
        li   x13, 2                  # via
        jal  x1, hanoi
        li   x20, 0x100
        sw   x9, 0(x20)
        sw   x8, 4(x20)
        li   x3, 1
        li   x14, 255
        bne  x9, x14, fail
        li   x3, 2
        li   x14, 0x8330943C
        bne  x8, x14, fail
        PASS

# hanoi(n=x10, from=x11, to=x12, via=x13)
hanoi:
        beq  x10, x0, hanoi_ret
        addi x2, x2, -20
        sw   x1, 0(x2)
        sw   x10, 4(x2)
        sw   x11, 8(x2)
        sw   x12, 12(x2)
        sw   x13, 16(x2)
        addi x10, x10, -1            # hanoi(n-1, from, via, to)
        addi x14, x12, 0
        addi x12, x13, 0
        addi x13, x14, 0
        jal  x1, hanoi
        lw   x11, 8(x2)              # move(from, to)
        lw   x12, 12(x2)
        slli x14, x8, 5
        sub  x8, x14, x8             # checksum * 31
        slli x14, x11, 2
        or   x14, x14, x12
        add  x8, x8, x14
        addi x9, x9, 1
        lw   x10, 4(x2)              # hanoi(n-1, via, to, from)
        addi x10, x10, -1
        lw   x11, 16(x2)
        lw   x12, 12(x2)
        lw   x13, 8(x2)
        jal  x1, hanoi
        lw   x1, 0(x2)
        addi x2, x2, 20
hanoi_ret:
        jalr x0, 0(x1)

        FAIL_HANDLER
