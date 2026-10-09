# Bubble sort of 32 signed words at 0x200, ascending, with early exit when a pass makes no swap.
# Data: xorshift32 from seed 0x12345678 (x ^= x << 13; x ^= x >> 17; x ^= x << 5).
# Checks: every a[i] <= a[i+1] (test 2); rolling checksum c = rotl(c, 1) ^ a[i] over the
# sorted array = 0xbf477393 (test 3). Result: mem[0x100] = checksum. Data-dependent swap branch.
        .include "common.inc"
        .text
        .globl _start
_start:
        li   x3, 1
        li   x10, 0x200              # array base
        li   x11, 32                 # n
        li   x12, 0x12345678         # xorshift state
        li   x13, 0                  # i
fill:
        slli x14, x12, 13
        xor  x12, x12, x14
        srli x14, x12, 17
        xor  x12, x12, x14
        slli x14, x12, 5
        xor  x12, x12, x14
        slli x15, x13, 2
        add  x15, x15, x10
        sw   x12, 0(x15)
        addi x13, x13, 1
        bne  x13, x11, fill

        addi x16, x11, -1            # last = n - 1
outer:
        li   x17, 0                  # swapped = 0
        li   x13, 0                  # i
        mv   x15, x10                # p = &a[0]
inner:
        lw   x18, 0(x15)             # a[i]
        lw   x19, 4(x15)             # a[i+1]
        bge  x19, x18, no_swap       # data-dependent branch
        sw   x19, 0(x15)
        sw   x18, 4(x15)
        li   x17, 1
no_swap:
        addi x15, x15, 4
        addi x13, x13, 1
        bne  x13, x16, inner
        addi x16, x16, -1            # largest element is now in place
        beq  x17, x0, sorted         # no swap in this pass: done
        bne  x16, x0, outer
sorted:
        li   x3, 2                   # test 2: ascending order
        li   x13, 1
        mv   x15, x10
check:
        lw   x18, 0(x15)
        lw   x19, 4(x15)
        blt  x19, x18, fail
        addi x15, x15, 4
        addi x13, x13, 1
        bne  x13, x11, check

        li   x20, 0                  # checksum
        li   x13, 0
        mv   x15, x10
sum:
        slli x21, x20, 1             # rotl(c, 1)
        srli x22, x20, 31
        or   x20, x21, x22
        lw   x18, 0(x15)
        xor  x20, x20, x18
        addi x15, x15, 4
        addi x13, x13, 1
        bne  x13, x11, sum

        li   x21, 0x100
        sw   x20, 0(x21)
        li   x3, 3                   # test 3: checksum
        li   x22, 0xbf477393
        bne  x20, x22, fail
        PASS
        FAIL_HANDLER
