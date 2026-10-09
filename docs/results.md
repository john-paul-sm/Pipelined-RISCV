# Results log

Running record of measured results, before/after each change, and notes for the README.
Every number lists how it was measured.

## Setup

| Item | Value |
|---|---|
| Simulator | Verilator 5.050 |
| Synthesis | Yosys 0.69+260 (OSS CAD Suite 2026-10-08), slang plugin (`read_slang`) |
| Timing | OpenSTA 3.1.0 |
| Library | SKY130 `sky130_fd_sc_hd`, typical corner `tt_025C_1v80` |
| PDK source | volare, sky130 build from 2025 (hash: TODO) |
| Synthesis boundary | `riscv_core` (memories excluded; they connect through the memory ports) |
| Timing conditions | Pre-layout: no wire parasitics, ideal clock. Input/output delay 2.0 ns, driving cell `buf_2`, output load 0.0175 pF |

## Area

| Configuration | Cells | Cell area (µm²) | Sequential | Date | Notes |
|---|---|---|---|---|---|
| Base RV32I, predict-not-taken, run 1 | 6,303 | 74,415 | 40,259 µm² (54.1%) | 2026-10-09 | ABC used 193 `lpflow` power-isolation cells as logic |
| Base RV32I, `-dont_use *lpflow* *_0` | 6,305 | **74,413** | 40,259 µm² (54.1%) | 2026-10-09 | Baseline |
| Base RV32I, buffered (`-constr`, `-D 10000`) | 6,954 | **76,852** | 40,259 µm² (52.4%) | 2026-10-09 | +2,439 µm² (+3.3%): ~650 buffers (559 `clkbuf_1`, 88 `buf_1`, 3 others) |

Area breakdown (baseline):

| Block | Cells | Area (µm²) | Share |
|---|---|---|---|
| Register file storage | 1,024 `edfxtp_1` | ~30,700 | ~41% |
| Register file read muxes | 511 `mux4_2` | ~11,500 | ~15% |
| PC + pipeline registers | 475 `dfxtp_1` | ~9,500 | ~13% |
| Other logic (ALU, forwarding, control, adders) | ~4,300 | ~22,700 | ~31% |

## Timing

| Configuration | Clock target | WNS | Min period | Fmax | Date |
|---|---|---|---|---|---|
| Base, unbuffered | 10 ns | −6.674 ns | 16.67 ns | **59.98 MHz** | 2026-10-09 |
| Base, buffered (`-constr`, `-D 10000`) | 10 ns | 0 (slack +1.209 ns, met) | 8.79 ns | **113.75 MHz** | 2026-10-09 |

Unbuffered critical path (16.329 ns arrival): flip-flop `_10986_` Q = 9.804 ns, inverter
`_04806_` = 4.930 ns, 6 logic gates = 1.595 ns. ~90% of the delay is two weak cells
driving high-fanout nets.

Buffered critical path (8.659 ns arrival, ~40 cells, max fanout on the path = 8): starts
at `u_mem_wb.rd_addr_out[0]` → rd/rs compare (forwarding unit) → forwarding mux → a long
carry chain (ALU adder) → endpoint flip-flop `_11997_`. This is the EX-stage path:
forwarding select → ALU. Endpoint not yet identified (likely PC via branch redirect, or
EX/MEM). Fix effect: 59.98 → 113.75 MHz (1.90×) for +3.3% area.

## Performance (cycles)

Cycles from reset release to the tohost store. Base core, predict-not-taken.
IPC needs the valid bit (retired instruction count) — TODO.

| Program | Stresses | Cycles (base) | Retired | IPC | Cycles (next config) |
|---|---|---|---|---|---|
| `isa_rv32i` | All RV32I instructions (correctness) | 262 | TODO | TODO | |
| `crc32` | Data-dependent branches | 5,194 | TODO | TODO | |
| `hanoi` | Recursive calls / returns | 10,741 | TODO | TODO | |
| `fir` | Software multiply (M baseline) | 143,356 | TODO | TODO | |

## Notes for the README

- 5-stage in-order RV32I (37 instructions; no FENCE/ECALL/EBREAK). Full forwarding
  (EX/MEM and MEM/WB), 1-cycle load-use stall, predict-not-taken with a 2-cycle branch
  penalty, write-first register file.
- Synthesis boundary is `riscv_core` with memory ports, so Yosys `opt_clean` keeps all
  logic and the area excludes the memories.
- The register file is ~56% of the core's cell area (flip-flop storage + read muxes).
  Possible later optimization: latch-based or SRAM-macro register file.
- First timing run: 59.98 MHz, limited by unbuffered high-fanout nets, not by logic depth.
  Fix: give ABC a delay target (`-D`) and drive/load constraints (`-constr`) so it runs
  buffer / upsize / dnsize. Result: **113.75 MHz** (8.79 ns), +3.3% area. The critical
  path is now real logic: MEM/WB rd compare → forwarding mux → ALU carry chain.
- Neither reference project (Jon-Totorica19, AxC1271) fixed its unbuffered fanout;
  both reported the unbuffered number.
- All timing is pre-layout (no wire delay, ideal clock); real silicon would be slower.
- Self-checking test programs: pass/fail reported through a tohost store
  (riscv-tests convention). Test programs were generated with AI assistance and
  verified in simulation.
