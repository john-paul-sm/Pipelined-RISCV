# Results

5-stage in-order RV32IM core, SKY130 `sky130_fd_sc_hd` (typical corner), pre-layout.

## Summary

| Metric | RV32I | RV32IM (current) |
|---|---|---|
| Setup slack at 10 ns | +1.209 ns (met) | −0.393 ns |
| Achieved Fmax | **113.75 MHz** (8.79 ns) | **96.22 MHz** (10.39 ns) |
| Hold slack | +0.414 ns (met) | +0.390 ns (met) |
| Cell area | 0.0769 mm² (76,852 µm²) | **0.0879 mm²** (87,901 µm²) |
| Power (estimate) | 8.43 mW at 100 MHz | **9.21 mW** at 100 MHz |
| IPC (RV32I programs) | 0.67–0.90 | 0.67–0.90 |

## M extension: iterative vs. single-cycle

One shared radix-2 unit (`mul_div_unit`) executes all 8 RV32M instructions: shift-and-add
multiply, restoring division, one 33-bit adder, 32 iterations. Every M instruction stays in
EX for 37 cycles and stalls the front of the pipeline. The alternative puts a combinational
multiplier and divider in the ALU (1 cycle).

| Metric | RV32I | RV32IM, iterative unit | RV32IM, single-cycle ALU |
|---|---|---|---|
| `mul` / `div` latency | — (software) | 37 cycles | 1 cycle |
| Achieved Fmax | 113.75 MHz | **96.22 MHz** | 10.19 MHz |
| Cell area | 76,852 µm² | **87,901 µm² (+14.4%)** | 149,505 µm² (+94.5%) |
| Power (estimate) | 8.43 mW | **9.21 mW** | 10.8 mW |

Execution time = cycles × clock period:

| Program | RV32I | Iterative unit | Single-cycle ALU |
|---|---|---|---|
| `fir` / `fir_m` | 143,356 cycles, 1,260 µs | 41,400 cycles, **430 µs (2.93× faster)** | 13,176 cycles, 1,294 µs |
| `matmul_sw` / `matmul` | 130,845 cycles, 1,150 µs | 31,405 cycles, **326 µs (3.52× faster)** | 8,365 cycles, 821 µs |
| `crc32` (no multiply) | 46 µs | 54 µs | 510 µs |

- The single-cycle ALU needs 3–4× fewer cycles than the iterative unit, but its divider
  array (407 cells in series) sets a 98 ns clock period. It is slower on every program.
- The iterative unit makes multiply-heavy programs 2.9–3.5× faster. Programs without
  multiplies run about 18% slower because of the lower Fmax.
- RV32IM critical path: the unit's 33-bit ripple-carry adder (divide step: adder carry-out
  selects the restore mux), 10.26 ns. A parallel-prefix adder is the known fix.

## Timing: fixing high-fanout nets (RV32I)

| Synthesis | Setup slack at 10 ns | Achieved Fmax | Area |
|---|---|---|---|
| Unbuffered | −6.674 ns (violated) | 59.98 MHz | 74,413 µm² |
| Buffered (ABC `-D` + `-constr`) | **+1.209 ns (met)** | **113.75 MHz** | 76,852 µm² |

- Unbuffered: ~90% of the critical-path delay came from two weak cells driving
  high-fanout nets, not from logic depth.
- Buffering and cell resizing: **1.90× Fmax for +3.3% area**.
- New critical path: MEM/WB rd → forwarding compare → forwarding mux → ALU carry chain.

## Area (RV32I)

| Block | Share of cell area |
|---|---|
| Register file (storage + read muxes) | ~56% |
| PC + pipeline registers | ~13% |
| ALU, forwarding, control, adders | ~31% |

The register file dominates area. A latch-based or SRAM-macro register file is the
largest possible area saving.

## Power (estimate, RV32I)

100 MHz, typical corner, assumed switching activity 0.1 on every net (no simulation
activity), ideal clock (clock-tree power not included).

| Group | Power | Share |
|---|---|---|
| Sequential (flip-flops) | 7.25 mW | 86% |
| Combinational | 1.18 mW | 14% |
| **Total** | **8.43 mW** | |

91% of the total is internal (cell) power, mostly flip-flops switching on every clock
edge. Flip-flops per block:

| Block | Flip-flops |
|---|---|
| Register file | 1,024 |
| ID/EX | 167 |
| EX/MEM | 108 |
| MEM/WB | 104 |
| IF/ID | 64 |
| PC | 32 |

Flip-flops dominate power and the register file holds 68% of them, so it is the main
power target: clock gating, or a latch/SRAM register file.

## Performance

Predict-not-taken, 2-cycle branch penalty, 1-cycle load-use stall.

| Program | Stresses | Cycles | IPC |
|---|---|---|---|
| `isa_rv32i` | All RV32I instructions | 262 | 0.901 |
| `crc32` | Data-dependent branches | 5,194 | 0.670 |
| `hanoi` | Recursive calls / returns | 10,741 | 0.738 |
| `fir` | Software multiply (M baseline) | 143,356 | 0.750 |
| `bubble` | Load-use stalls, data-dependent branches | 6,513 | 0.685 |
| `matmul_sw` | Software multiply (M baseline) | 130,845 | 0.727 |

M programs: report cycles, not IPC. Each M instruction retires 1 instruction in 37 cycles.

| Program | Stresses | Cycles |
|---|---|---|
| `isa_m` | All M instructions, M hazards | 2,648 |
| `fir_m` | `mul` in a dependent multiply-accumulate | 41,400 |
| `matmul` | `mul` in a dependent multiply-accumulate | 31,405 |

## Notes

- Full forwarding (EX/MEM, MEM/WB), write-first register file, synthesis boundary at the
  core's memory ports.
- Timing is pre-layout (no wire delay, ideal clock); post-layout would be slower.
- Test programs are self-checking; they were generated with AI assistance and verified
  in simulation.
