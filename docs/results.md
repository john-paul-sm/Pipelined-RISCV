# Results

5-stage in-order RV32IM core, SKY130 `sky130_fd_sc_hd` (typical corner), pre-layout.

## Summary

| Metric | RV32I (old SDC) | RV32IM (current) |
|---|---|---|
| Setup slack | +1.209 ns at 10 ns (met) | +0.007 ns at 10.65 ns (met) |
| Achieved Fmax | **113.75 MHz** (8.79 ns) | **93.96 MHz** (10.64 ns) |
| Hold slack | +0.414 ns (met) | +0.140 ns (met) |
| Cell area | 0.0769 mm² (76,852 µm²) | **0.0879 mm²** (87,901 µm²) |
| Power (estimate) | 8.43 mW at 100 MHz | **8.67 mW** at 93.9 MHz |
| FPGA (PYNQ-Z2, Zynq-7020) | — | **90 MHz** (timing met, programs pass on the board) |
| IPC (RV32I programs) | 0.67–0.75 | 0.67–0.75 |

Current SDC (`synth/riscv_core.sdc`): 10.65 ns clock, 0.25 ns clock uncertainty, 2.0 ns
input/output delay, `buf_2` input drive, 0.030 pF output load, max transition 1.5 ns,
max fanout 20. Design-rule check: 0 max-transition and 0 max-capacitance violations;
32 max-fanout violations (fanout 32), all register-file write enables. **Old SDC**:
10.0–10.4 ns clock, no clock uncertainty, 0.0175 pF load, no design-rule limits.

## M extension: iterative vs. single-cycle

One shared radix-2 unit (`mul_div_unit`) executes all 8 RV32M instructions: shift-and-add
multiply, restoring division, one 33-bit adder, 32 iterations. Every M instruction stays in
EX for 37 cycles and stalls the front of the pipeline. The alternative puts a combinational
multiplier and divider in the ALU (1 cycle).

Measured with the old SDC.

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

## Timing: fixing high-fanout nets

Same RTL and SDC; the only difference is whether ABC gets the drive/load constraints and
a delay target (`-constr synth/abc.constr -D 10000`).

| Synthesis | Achieved Fmax | Area | Max-transition violations |
|---|---|---|---|
| RV32I, unbuffered (old SDC) | 59.98 MHz | 74,413 µm² | — |
| RV32I, buffered (old SDC) | **113.75 MHz** | 76,852 µm² | — |
| RV32IM, unbuffered (`synth/synth_core_unbuffered.ys`) | 53.55 MHz | 84,667 µm² | 4,634 |
| RV32IM, buffered | **93.96 MHz** | 87,901 µm² | 0 |

- RV32IM unbuffered: 15.9 ns of the 18.27 ns critical path is three high-fanout nets.
  The worst is the flip-flop `u_if_id.instruction_out[20]` (rs2 bit 0) driving 292
  inputs (1.53 pF, 14.1 ns slew). Slews this large are outside the cell library's
  characterized range, so the unbuffered Fmax is not a valid timing result.
- RV32I unbuffered: ~90% of the critical-path delay came from two weak cells driving
  high-fanout nets, not from logic depth.
- Buffering and cell resizing: **1.90× Fmax for +3.3% area** (RV32I), **1.75× for +3.8%**
  (RV32IM).
- RV32I critical path after buffering: MEM/WB rd → forwarding compare → forwarding mux →
  ALU carry chain. RV32IM: the `mul_div_unit` 33-bit adder.

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
