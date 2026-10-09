# Results

5-stage in-order RV32I core, SKY130 `sky130_fd_sc_hd` (typical corner), pre-layout.

## Summary

| Metric | Value |
|---|---|
| Target clock | 10 ns (100 MHz) |
| Setup slack (WNS) | **+1.209 ns (met)** |
| Hold slack | **+0.414 ns (met)** |
| Achieved Fmax | **113.75 MHz** (8.79 ns) |
| Cell area | **0.0769 mm²** (76,852 µm²) |
| Power (estimate) | **8.43 mW** at 100 MHz |
| IPC | TODO |

## Timing: fixing high-fanout nets

| Synthesis | Setup slack at 10 ns | Achieved Fmax | Area |
|---|---|---|---|
| Unbuffered | −6.674 ns (violated) | 59.98 MHz | 74,413 µm² |
| Buffered (ABC `-D` + `-constr`) | **+1.209 ns (met)** | **113.75 MHz** | 76,852 µm² |

- Unbuffered: ~90% of the critical-path delay came from two weak cells driving
  high-fanout nets, not from logic depth.
- Buffering and cell resizing: **1.90× Fmax for +3.3% area**.
- New critical path: MEM/WB rd → forwarding compare → forwarding mux → ALU carry chain.

## Area

| Block | Share of cell area |
|---|---|
| Register file (storage + read muxes) | ~56% |
| PC + pipeline registers | ~13% |
| ALU, forwarding, control, adders | ~31% |

The register file dominates area. A latch-based or SRAM-macro register file is the
largest possible area saving.

## Power (estimate)

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
| `isa_rv32i` | All RV32I instructions | 262 | TODO |
| `crc32` | Data-dependent branches | 5,194 | TODO |
| `hanoi` | Recursive calls / returns | 10,741 | TODO |
| `fir` | Software multiply (M baseline) | 143,356 | TODO |

## Notes

- Full forwarding (EX/MEM, MEM/WB), write-first register file, synthesis boundary at the
  core's memory ports.
- Timing is pre-layout (no wire delay, ideal clock); post-layout would be slower.
- Test programs are self-checking; they were generated with AI assistance and verified
  in simulation.
