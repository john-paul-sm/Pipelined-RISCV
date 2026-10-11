# RV32I coverage. Self-checking: tohost = 1 on pass, (test number << 1) | 1 on fail.
# Test number is in x3 (gp). Every RV32I instruction except FENCE, ECALL, EBREAK.
        .include "common.inc"

        .macro TRR num, op, v1, v2, exp
        li   x3, \num
        li   x10, \v1
        li   x11, \v2
        \op  x12, x10, x11
        li   x13, \exp
        bne  x12, x13, fail
        .endm

        .macro TRI num, op, v1, imm, exp
        li   x3, \num
        li   x10, \v1
        \op  x12, x10, \imm
        li   x13, \exp
        bne  x12, x13, fail
        .endm

        .text
        .globl _start
_start:
        # --- branch sanity: taken branches skip the jump to fail ---
        li   x3, 1
        beq  x0, x0, 1f
        jal  x0, fail
1:      li   x3, 2
        li   x10, -1
        li   x11, 1
        bne  x10, x11, 1f
        jal  x0, fail
1:      li   x3, 3
        blt  x10, x11, 1f          # -1 < 1 signed
        jal  x0, fail
1:      li   x3, 4
        bge  x11, x10, 1f          # 1 >= -1 signed
        jal  x0, fail
1:      li   x3, 5
        bltu x11, x10, 1f          # 1 < 0xFFFFFFFF unsigned
        jal  x0, fail
1:      li   x3, 6
        bgeu x10, x11, 1f          # 0xFFFFFFFF >= 1 unsigned
        jal  x0, fail
        # --- not-taken branches: the target is fail ---
1:      li   x3, 7
        beq  x10, x11, fail
        bne  x10, x10, fail
        blt  x11, x10, fail         # 1 < -1 false
        bge  x10, x11, fail         # -1 >= 1 false
        bltu x10, x11, fail         # 0xFFFFFFFF < 1 false
        bgeu x11, x10, fail         # 1 >= 0xFFFFFFFF false
        bge  x10, x10, 1f           # equal: taken
        jal  x0, fail
1:      bgeu x11, x11, 1f           # equal: taken
        jal  x0, fail
1:
        # --- register-register ---
        TRR 10, add,  0x7FFFFFFF, 1,          0x80000000
        TRR 11, sub,  0,          1,          0xFFFFFFFF
        TRR 12, sll,  1,          31,         0x80000000
        TRR 13, sll,  1,          33,         0x00000002    # only rs2[4:0] used
        TRR 14, slt,  -1,         1,          1
        TRR 15, slt,  1,          -1,         0
        TRR 16, sltu, -1,         1,          0
        TRR 17, sltu, 1,          -1,         1
        TRR 18, xor,  0xFF00FF00, 0x0FF00FF0, 0xF0F0F0F0
        TRR 19, srl,  0x80000000, 4,          0x08000000
        TRR 20, sra,  0x80000000, 4,          0xF8000000
        TRR 21, or,   0xFF00FF00, 0x0FF00FF0, 0xFFF0FFF0
        TRR 22, and,  0xFF00FF00, 0x0FF00FF0, 0x0F000F00
        # --- register-immediate ---
        TRI 30, addi,  5,          -6,   0xFFFFFFFF
        TRI 31, slti,  -5,         -4,   1
        TRI 32, sltiu, 5,          -1,   1                   # imm sign-extends to 0xFFFFFFFF
        TRI 33, xori,  0x00FF00FF, -1,   0xFF00FF00
        TRI 34, ori,   0x12340000, 0x7FF, 0x123407FF
        TRI 35, andi,  0x1234ABCD, 0x0F0, 0x000000C0
        TRI 36, slli,  3,          30,   0xC0000000
        TRI 37, srli,  0xF0000000, 28,   0x0000000F
        TRI 38, srai,  0xF0000000, 28,   0xFFFFFFFF
        # --- lui / auipc ---
        li   x3, 40
        lui  x12, 0xABCDE
        li   x13, 0xABCDE000
        bne  x12, x13, fail
        li   x3, 41
        auipc x10, 0
        auipc x11, 1                 # = (pc of first + 4) + 0x1000
        sub  x12, x11, x10
        li   x13, 0x1004
        bne  x12, x13, fail
        # --- stores and loads (byte lanes) ---
        li   x20, 0x600
        li   x3, 50
        li   x10, 0x8899AABB
        sw   x10, 0(x20)
        lw   x12, 0(x20)
        bne  x12, x10, fail
        li   x3, 51
        lb   x12, 0(x20)             # 0xBB
        li   x13, 0xFFFFFFBB
        bne  x12, x13, fail
        li   x3, 52
        lbu  x12, 3(x20)             # 0x88
        li   x13, 0x88
        bne  x12, x13, fail
        li   x3, 53
        lh   x12, 2(x20)             # 0x8899
        li   x13, 0xFFFF8899
        bne  x12, x13, fail
        li   x3, 54
        lhu  x12, 0(x20)             # 0xAABB
        li   x13, 0xAABB
        bne  x12, x13, fail
        li   x3, 55
        li   x10, 0x11
        sb   x10, 1(x20)             # word = 0x889911BB
        lw   x12, 0(x20)
        li   x13, 0x889911BB
        bne  x12, x13, fail
        li   x3, 56
        li   x10, 0x7766
        sh   x10, 2(x20)             # word = 0x776611BB
        lw   x12, 0(x20)
        li   x13, 0x776611BB
        bne  x12, x13, fail
        li   x3, 57
        li   x10, 0x7F
        sb   x10, 4(x20)             # next word, byte 0
        lb   x12, 4(x20)
        li   x13, 0x7F
        bne  x12, x13, fail
        # --- jal / jalr ---
        li   x3, 60
        jal  x1, 1f
2:      jal  x0, fail                # must be skipped
1:      la   x13, 2b                 # link must be the address after jal
        bne  x1, x13, fail
        li   x3, 61
        la   x10, 3f
        addi x10, x10, 1             # odd address: jalr clears bit 0
        jalr x5, 0(x10)
4:      jal  x0, fail
3:      la   x13, 4b
        bne  x5, x13, fail
        # --- x0 stays zero ---
        li   x3, 70
        addi x0, x0, 5
        bne  x0, x0, fail
        lui  x0, 0x12345
        bne  x0, x0, fail

        PASS
        FAIL_HANDLER
