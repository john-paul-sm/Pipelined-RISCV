# Test programs

Each `.hex` file is one program, loaded into instruction memory through `riscv_top`'s
`IMEM_FILE` parameter. Sources are in `asm/`. Every program checks its own result and
ends with a store to the **tohost** address `0x7FC`: `1` = pass, `(test number × 2) + 1` =
fail. Then it loops forever (`jal x0, .`).

| Program | What it does | Expected result |
|---|---|---|
| `isa_rv32i.hex` | Runs every RV32I instruction (except FENCE, ECALL, EBREAK) with known operands and compares each result: all 6 branch types taken and not taken, byte/half loads and stores, `jal`/`jalr` link values, writes to `x0`. | tohost = 1 |
| `crc32.hex` | CRC-32 of the 64 bytes `0x00`–`0x3F`, one bit at a time: `crc = (crc >> 1) ^ (0xEDB88320 if crc[0] else 0)`. One data-dependent branch per bit. | mem[0x100] = `0x100ECE8C` |
| `hanoi.hex` | Recursive Tower of Hanoi with 8 discs (2⁸ − 1 = 255 moves). Each move updates `checksum = checksum × 31 + (from << 2 \| to)`. Stresses calls, returns and the stack. | mem[0x100] = 255, mem[0x104] = `0x8330943C` |
| `fir.hex` | 16-tap FIR filter: `y[n] = Σ h[k] · x[n−k]`, k = 0…15, for n = 15…63. RV32I has no multiply instruction, so it uses a shift-and-add multiply routine. Baseline for the M extension. | mem[0x100] = Σ y = `0xFFFFFC70` |

`asm/common.inc` holds the pass/fail macros shared by all four programs.
