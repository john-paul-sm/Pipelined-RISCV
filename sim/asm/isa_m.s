# M extension coverage. Self-checking: tohost = 1 on pass, (test number << 1) | 1 on fail.
# Test number is in x3 (gp). Tests 10-57: every M instruction, including divide by zero
# and signed overflow. Tests 100-112: pipeline hazards around the iterative mul_div_unit.
        .include "common.inc"

        .macro TRR num, op, v1, v2, exp
        li   x3, \num
        li   x10, \v1
        li   x11, \v2
        \op  x12, x10, x11
        li   x13, \exp
        bne  x12, x13, fail
        .endm

        .text
        .globl _start
_start:
        # --- every M instruction ---
        TRR 10, mul   , 0xFFFFFFF9, 0x00000003, 0xFFFFFFEB
        TRR 11, mul   , 0x00000007, 0xFFFFFFFD, 0xFFFFFFEB
        TRR 12, mul   , 0xFFFFFFF9, 0xFFFFFFFD, 0x00000015
        TRR 13, mul   , 0xFFFFCFC7, 0x00000000, 0x00000000
        TRR 14, mul   , 0x80000000, 0xFFFFFFFF, 0x80000000
        TRR 15, mul   , 0x12345678, 0x9ABCDEF0, 0x242D2080
        TRR 16, mulh  , 0xFFFFFFF9, 0x00000003, 0xFFFFFFFF
        TRR 17, mulh  , 0x00000007, 0xFFFFFFFD, 0xFFFFFFFF
        TRR 18, mulh  , 0xFFFFFFF9, 0xFFFFFFFD, 0x00000000
        TRR 19, mulh  , 0xFFFFCFC7, 0x00000000, 0x00000000
        TRR 20, mulh  , 0x80000000, 0xFFFFFFFF, 0x00000000
        TRR 21, mulh  , 0x12345678, 0x9ABCDEF0, 0xF8CC93D6
        TRR 22, mulhsu, 0xFFFFFFF9, 0x00000003, 0xFFFFFFFF
        TRR 23, mulhsu, 0x00000007, 0xFFFFFFFD, 0x00000006
        TRR 24, mulhsu, 0xFFFFFFF9, 0xFFFFFFFD, 0xFFFFFFF9
        TRR 25, mulhsu, 0xFFFFCFC7, 0x00000000, 0x00000000
        TRR 26, mulhsu, 0x80000000, 0xFFFFFFFF, 0x80000000
        TRR 27, mulhsu, 0x12345678, 0x9ABCDEF0, 0x0B00EA4E
        TRR 28, mulhu , 0xFFFFFFF9, 0x00000003, 0x00000002
        TRR 29, mulhu , 0x00000007, 0xFFFFFFFD, 0x00000006
        TRR 30, mulhu , 0xFFFFFFF9, 0xFFFFFFFD, 0xFFFFFFF6
        TRR 31, mulhu , 0xFFFFCFC7, 0x00000000, 0x00000000
        TRR 32, mulhu , 0x80000000, 0xFFFFFFFF, 0x7FFFFFFF
        TRR 33, mulhu , 0x12345678, 0x9ABCDEF0, 0x0B00EA4E
        TRR 34, div   , 0xFFFFFFF9, 0x00000003, 0xFFFFFFFE
        TRR 35, div   , 0x00000007, 0xFFFFFFFD, 0xFFFFFFFE
        TRR 36, div   , 0xFFFFFFF9, 0xFFFFFFFD, 0x00000002
        TRR 37, div   , 0xFFFFCFC7, 0x00000000, 0xFFFFFFFF
        TRR 38, div   , 0x80000000, 0xFFFFFFFF, 0x80000000
        TRR 39, div   , 0x12345678, 0x9ABCDEF0, 0x00000000
        TRR 40, divu  , 0xFFFFFFF9, 0x00000003, 0x55555553
        TRR 41, divu  , 0x00000007, 0xFFFFFFFD, 0x00000000
        TRR 42, divu  , 0xFFFFFFF9, 0xFFFFFFFD, 0x00000000
        TRR 43, divu  , 0xFFFFCFC7, 0x00000000, 0xFFFFFFFF
        TRR 44, divu  , 0x80000000, 0xFFFFFFFF, 0x00000000
        TRR 45, divu  , 0x12345678, 0x9ABCDEF0, 0x00000000
        TRR 46, rem   , 0xFFFFFFF9, 0x00000003, 0xFFFFFFFF
        TRR 47, rem   , 0x00000007, 0xFFFFFFFD, 0x00000001
        TRR 48, rem   , 0xFFFFFFF9, 0xFFFFFFFD, 0xFFFFFFFF
        TRR 49, rem   , 0xFFFFCFC7, 0x00000000, 0xFFFFCFC7
        TRR 50, rem   , 0x80000000, 0xFFFFFFFF, 0x00000000
        TRR 51, rem   , 0x12345678, 0x9ABCDEF0, 0x12345678
        TRR 52, remu  , 0xFFFFFFF9, 0x00000003, 0x00000000
        TRR 53, remu  , 0x00000007, 0xFFFFFFFD, 0x00000007
        TRR 54, remu  , 0xFFFFFFF9, 0xFFFFFFFD, 0xFFFFFFF9
        TRR 55, remu  , 0xFFFFCFC7, 0x00000000, 0xFFFFCFC7
        TRR 56, remu  , 0x80000000, 0xFFFFFFFF, 0x80000000
        TRR 57, remu  , 0x12345678, 0x9ABCDEF0, 0x12345678

        # --- operand forwarded from MEM (instruction directly before) ---
        li   x3, 100
        li   x11, 6
        li   x10, 7
        mul  x12, x10, x11
        li   x13, 42
        bne  x12, x13, fail
        # --- operand forwarded from WB (one instruction between) ---
        li   x3, 101
        li   x10, 9
        addi x0, x0, 0
        mul  x12, x10, x11
        li   x13, 54
        bne  x12, x13, fail
        # --- load-use into an M instruction ---
        li   x3, 102
        li   x14, 0x100
        li   x10, -100
        sw   x10, 0(x14)
        lw   x10, 0(x14)
        div  x12, x10, x11
        li   x13, -16
        bne  x12, x13, fail
        # --- M result forwarded to the next ALU instruction (from MEM) ---
        li   x3, 103
        li   x10, 5
        li   x11, 5
        mul  x12, x10, x11
        addi x12, x12, 1
        li   x13, 26
        bne  x12, x13, fail
        # --- M result forwarded with one instruction between (from WB) ---
        li   x3, 104
        mul  x12, x10, x11
        addi x0, x0, 0
        addi x12, x12, 2
        li   x13, 27
        bne  x12, x13, fail
        # --- M result to a branch ---
        li   x3, 105
        li   x13, 25
        mul  x12, x10, x11
        bne  x12, x13, fail
        # --- M result as store data and as store address ---
        li   x3, 106
        li   x10, 0x40
        li   x11, 4
        mul  x15, x10, x11
        mul  x16, x10, x11
        sw   x16, 0(x15)
        lw   x12, 0x100(x0)
        li   x13, 0x100
        bne  x12, x13, fail
        # --- back-to-back dependent M instructions ---
        li   x3, 107
        li   x10, 3
        mul  x12, x10, x10
        mul  x12, x12, x10
        mul  x12, x12, x10
        divu x12, x12, x10
        li   x13, 27
        bne  x12, x13, fail
        # --- M instruction that writes x0 ---
        li   x3, 108
        li   x10, 7
        mul  x0, x10, x10
        bne  x0, x0, fail
        addi x12, x0, 0
        bne  x12, x0, fail
        # --- M instructions on the wrong path of a taken branch ---
        li   x3, 109
        li   x12, 1
        beq  x0, x0, 1f
        mul  x12, x10, x10
        div  x12, x10, x10
1:      li   x13, 1
        bne  x12, x13, fail
        # --- M instruction on the wrong path of JAL ---
        li   x3, 110
        jal  x0, 1f
        mul  x12, x10, x10
1:      bne  x12, x13, fail
        # --- taken branch directly after an M instruction ---
        li   x3, 111
        mul  x12, x10, x10
        beq  x0, x0, 1f
        jal  x0, fail
1:      li   x13, 49
        bne  x12, x13, fail
        # --- normal R-type with funct7 = 0 is not decoded as M ---
        li   x3, 112
        li   x10, 7
        li   x11, 3
        add  x12, x10, x11
        sub  x14, x10, x11
        li   x13, 10
        bne  x12, x13, fail
        li   x13, 4
        bne  x14, x13, fail

        PASS

        FAIL_HANDLER
