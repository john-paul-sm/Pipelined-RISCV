# Change log

Record of changes Claude made in this repo, with the reason and how each change was verified.

## 1. Valid bit in the pipeline registers

**Why:** count retired instructions (instructions that complete WB) so the benchmarks can
report IPC. Without it, a bubble and a real instruction that writes nothing (store,
branch) look identical in WB.

| File | Change | Lines added |
|---|---|---|
| `rtl/if_id_register.sv` | Ports `valid_in`, `valid_out`. `reset \|\| flush` → 0, `stall` → hold, else load | 5 |
| `rtl/id_ex_register.sv` | Same | 5 |
| `rtl/ex_mem_register.sv` | Same | 5 |
| `rtl/mem_wb_register.sv` | Same | 5 |
| `rtl/riscv_core.sv` | Wires `id_valid`, `ex_valid`, `mem_valid`, `wb_valid`; connections below | 12 |

Connections in `riscv_core.sv`:

| Instance | `valid_in` | `valid_out` |
|---|---|---|
| `u_if_id` | `1'b1` | `id_valid` |
| `u_id_ex` | `id_valid` | `ex_valid` |
| `u_ex_mem` | `ex_valid` | `mem_valid` |
| `u_mem_wb` | `mem_valid` | `wb_valid` |

**Effect on behavior:** none. No logic reads the valid wires. Synthesis removes them, so
area, timing and power do not change.

**Verification (Claude's sandbox, your RTL):**

| Test | Result |
|---|---|
| Lint, `riscv_top` | Clean |
| `tb_riscv_top` | 8/8 passed, 0 errors |
| `isa_rv32i`, `crc32`, `hanoi`, `fir` | All pass (tohost = 1), cycle counts unchanged |
| Cycle accounting | cycles = retired + 2 × redirects + stalls + 2 (pipeline fill) for all 4 programs |

## 2. README for the test programs

**Why:** a short description of each program in `sim/`.

| File | Change | Lines added |
|---|---|---|
| `sim/README.md` | New file: tohost pass/fail convention, one table row per program (what it does, equation, expected result) | 15 |

**Effect on behavior:** none (documentation only).

**Verification:** expected results match the values each program checks (all 4 pass in
simulation).

## 3. Benchmark testbench

**Why:** run any test program on your machine and report cycles, retired instructions
and IPC (uses the valid bit from change 1).

| File | Change | Lines added |
|---|---|---|
| `sim/tb_bench.sv` | New testbench: loads the program given by `+prog=<file>`, stops on the tohost store (or after 500,000 cycles), checks tohost = 1, prints cycles, retired, IPC, stalls, redirects | 92 |

**Effect on behavior:** none (testbench only).

**Verification (Claude's sandbox, your RTL):**

| Program | Result | Cycles | Retired | IPC |
|---|---|---|---|---|
| `isa_rv32i` | 0 errors | 262 | 236 | 0.901 |
| `crc32` | 0 errors | 5,194 | 3,478 | 0.670 |
| `hanoi` | 0 errors | 10,741 | 7,926 | 0.738 |
| `fir` | 0 errors | 143,356 | 107,478 | 0.750 |
| Deliberately broken `isa_rv32i` (test 20) | `$error`: tohost = 0x29 (= test 20 failed) | | | |

## 4. Testbenches moved to `tb/`

**Why:** the repo rule is RTL in `rtl/`, testbenches in `tb/`. `sim/` now holds only the
test programs (`.hex`, `asm/`) and their README.

| File | Change |
|---|---|
| `sim/tb_bench.sv` → `tb/tb_bench.sv` | Moved, content unchanged |
| `sim/tb_riscv_top.sv` → `tb/tb_riscv_top.sv` | Moved, content unchanged |
| `sim/tb_register_file.sv` → `tb/tb_register_file.sv` | Moved, content unchanged |
| `sim/tb_program_counter.sv` → `tb/tb_program_counter.sv` | Moved, content unchanged |
| `sim/tb_immediate_generator.sv` → `tb/tb_immediate_generator.sv` | Moved, content unchanged |

**Effect on behavior:** none. The testbenches use paths relative to the repo root
(`sim/<program>.hex`), so they still work when Verilator runs from the repo root.

New build command:

```
verilator --binary -j 0 -Irtl rtl/riscv_ref.sv tb/tb_bench.sv --top-module tb_bench
./obj_dir/Vtb_bench +prog=sim/<program>.hex
```

**Verification (Claude's sandbox, your RTL):**

| Test | Result |
|---|---|
| `tb/tb_bench.sv`, all 4 programs | 0 errors, IPC 0.901 / 0.670 / 0.738 / 0.750 (unchanged) |
| `tb/tb_riscv_top.sv` | 0 errors, but only with `sim/prog_hazards.hex` present (see below) |

**Open issue:** `tb_riscv_top.sv` loads `sim/prog_hazards.hex`. That file is no longer in
the repo, so `tb_riscv_top` fails until the file is restored or the testbench is changed.
