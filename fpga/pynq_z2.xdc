## PYNQ-Z2 constraints for fpga_top. Pins from the PYNQ-Z2 master XDC.

## 125 MHz board clock
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports sysclk]
create_clock -name sys_clk_pin -period 8.000 -waveform {0 4} [get_ports sysclk]

## BTN0: reset
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports btn0]

## LD0..LD3: done, pass, fail, heartbeat
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## The button is asynchronous to every clock; the 2-flip-flop synchronizer handles it.
set_false_path -from [get_ports btn0]
## LEDs are slow outputs with no timing requirement.
set_false_path -to [get_ports {led[*]}]
