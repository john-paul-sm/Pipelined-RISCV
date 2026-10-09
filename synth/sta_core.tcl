read_liberty /home/johnp/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog build/riscv_core_synth.v
link_design riscv_core
read_sdc synth/riscv_core.sdc
report_checks -path_delay max -fields {slew cap fanout net} -digits 3
report_wns
report_tns
report_clock_min_period
report_clock_min_period -include_port_paths
exit