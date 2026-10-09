        .equ TOHOST, 0x7FC
        .macro PASS
        addi x31, x0, 1
        sw   x31, TOHOST(x0)
1:      jal  x0, 1b
        .endm
        .macro FAIL_HANDLER
fail:
        slli x31, x3, 1
        ori  x31, x31, 1
        sw   x31, TOHOST(x0)
2:      jal  x0, 2b
        .endm
