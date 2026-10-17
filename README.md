# Pipelined RISC-V Processor

5-stage in-order RV32IM core in SystemVerilog: IF → ID → EX → MEM → WB.
Runs at 90 MHz on a PYNQ-Z2 FPGA board and closes at 93.96 MHz in SKY130 synthesis
(pre-layout).

## Features

- RV32I integer instructions: arithmetic, logic, shifts, compares, loads and stores
  (byte, halfword, word), branches, `jal`/`jalr`, `lui`, `auipc`.
- RV32M (multiply/divide): one shared iterative radix-2 unit (`mul_div_unit`). Every M
  instruction stays in EX for 37 cycles (32 bits).
- Full forwarding from EX/MEM and MEM/WB, and a write-first register file.
- 1-cycle load-use stall (hazard detection unit).
- Branches and jumps resolve in EX. Predict-not-taken, 2-cycle penalty on a taken branch.
- Synchronous reset.

## Next Additions

I'm planning to add these next features to push this project further and to also expand my learning in other areas:

- L1 instruction and data caches: direct-mapped and blocking. The data cache is
  write-back and write-allocate. Both sit in front of a main-memory model with a
  configurable access latency, so the miss cost can be measured on each benchmark.
- AXI4-Lite SoC integration: the core gets an AXI4-Lite master port for
  memory-mapped peripherals.  Data RAM stays on the core's direct port, so RAM loads and stores
  add no stall cycle
- Post-synthesis results: Take the chip to PnR using LibreLane

## Results

| Metric | Value |
|---|---|
| SKY130 Fmax (`sky130_fd_sc_hd`, typical corner, pre-layout) | **93.96 MHz** |
| Cell area | 87,901 µm² |
| Power (estimate, activity 0.1) | 8.67 mW at 93.9 MHz |
| FPGA (PYNQ-Z2, Zynq-7020) | **90 MHz**, timing met, programs pass on the board |
| IPC (RV32I programs) | 0.67–0.75 |
| M extension speedup | `fir` 2.93×, `matmul` 3.52× |

Full results, the iterative vs. single-cycle M comparison, and the timing fix for
high-fanout nets: [`docs/results.md`](docs/results.md).

## Repository layout

| Folder | Contents |
|---|---|
| `rtl/` | RTL modules. `riscv_core` = pipeline (synthesis boundary), `riscv_top` = core + memories for simulation, `fpga_top` = PYNQ-Z2 wrapper, `riscv_ref` = package with opcodes, funct3 and ALU operation names |
| `tb/` | One self-checking testbench per module (`tb_<module>.sv`), `tb_bench` for full programs, `tb_fpga_top` for the FPGA wrapper |
| `sim/` | Test programs: assembly in `asm/`, hex files in `hex/`. See [`sim/README.md`](sim/README.md) |
| `synth/` | Yosys synthesis scripts, OpenSTA scripts, SDC constraints |
| `fpga/` | PYNQ-Z2 pin constraints |
| `docs/` | More detailed Results |

## Verification

- **Unit testbenches:** directed, self-checking SystemVerilog. Each test compares the
  output with an expected value in the testbench and prints `=== N passed, M errors ===`.
  Some use exhaustive or random checks against a reference model (`mul_div_unit`: 4,225
  checks).
- **Programs:** every program in `sim/` checks its own result and stores the pass/fail code
  to the tohost address `0x7FC` (`1` = pass). `tb_bench` runs one program on `riscv_top`
  and reports pass/fail, cycles, IPC, stall cycles and redirects.
- **FPGA:** `fpga_top` watches the same tohost store and shows the result on the LEDs.

## To Run:

To run this program, I used Verilator for linting/compiling, Yosys for synthesis, OpenSTA for timing analysis. I also used Xilinx Vivado for synthesizing and implementing it on my PYNQ Z2 Fpga.

Simulate one program:

```
verilator --binary -j 0 -Irtl rtl/riscv_ref.sv tb/tb_bench.sv --top-module tb_bench
./obj_dir/Vtb_bench +prog=sim/hex/crc32.hex
```

Synthesis and timing (SKY130):

```
yosys -m slang -s synth/synth_core.ys | tee build/synth.log
sta synth/sta_core.tcl | tee build/sta.log
```
