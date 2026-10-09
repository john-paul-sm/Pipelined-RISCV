# Test programs

Each `.hex` file is one program, loaded into instruction memory through `riscv_top`'s
`IMEM_FILE` parameter. Sources are in `asm/` and every program checks its own result and
ends with a store to the **tohost** address `0x7FC`: `1` = pass, `(test number × 2) + 1` =
fail. Then it loops forever (`jal x0, .`).

| Program | What it does | Expected result |
|---|---|---|
| `isa_rv32i.hex` | Runs every RV32I instruction (except FENCE, ECALL, EBREAK) with known operands and compares each result: all 6 branch types taken and not taken, byte/half loads and stores, `jal`/`jalr` link values, writes to `x0`. | tohost = 1 |
| `crc32.hex` | CRC-32 of the 64 bytes `0x00`–`0x3F`, one bit at a time: `crc = (crc >> 1) ^ (0xEDB88320 if crc[0] else 0)`. One data-dependent branch per bit. | mem[0x100] = `0x100ECE8C` |
| `hanoi.hex` | Recursive Tower of Hanoi with 8 discs (2⁸ − 1 = 255 moves). Each move updates `checksum = checksum × 31 + (from << 2 \| to)`. Stresses calls, returns and the stack. | mem[0x100] = 255, mem[0x104] = `0x8330943C` |
| `fir.hex` | 16-tap FIR filter: `y[n] = Σ h[k] · x[n−k]`, k = 0…15, for n = 15…63. RV32I has no multiply instruction, so it uses a shift-and-add multiply routine. Baseline for the M extension. | mem[0x100] = Σ y = `0xFFFFFC70` |
| `bubble.hex` | Bubble sort of 32 signed words, ascending, stopping early when a pass makes no swap. The data comes from xorshift32 (seed `0x12345678`: `x ^= x << 13; x ^= x >> 17; x ^= x << 5`). Checks that the result is in order, then a checksum `c = rotl(c, 1) ^ a[i]` over the sorted array. One data-dependent branch per compare. | mem[0x100] = `0xBF477393` |
| `isa_m.hex` | Runs every M instruction (RV32IM) with signed, unsigned, divide-by-zero and signed-overflow operands. Then tests pipeline hazards around the iterative `mul_div_unit`: operands forwarded from MEM and WB, load-use into an M instruction, the M result forwarded to an ALU instruction, a branch and a store, back-to-back dependent M instructions, an M instruction that writes `x0`, and M instructions on the wrong path of a taken branch and `jal`. | tohost = 1 |
| `fir_m.hex` | `fir.hex` with each call to the software multiply replaced by one `mul` instruction. Same data and same result. Measures the M extension against `fir.hex`. | mem[0x100] = Σ y = `0xFFFFFC70` |
| `matmul.hex` | 8×8 signed matrix multiply `C = A × B` with the `mul` instruction (RV32IM): 512 multiply-accumulates. A and B come from an LCG (`x = x × 1103515245 + 12345`, seed 1, value = `((x >> 16) & 31) − 16`). Then a checksum `c = rotl(c, 1) ^ C[i][j]` over C, row-major. Each `mul` result goes directly into a dependent `add`. | mem[0x100] = `0xD5B51F45` |

`asm/common.inc` holds the pass/fail macros shared by all programs.
