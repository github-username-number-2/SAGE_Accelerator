set_property PACKAGE_PIN A10 [get_ports perst_n]
set_property IOSTANDARD LVCMOS33 [get_ports perst_n]
set_property PULLDOWN true [get_ports perst_n]
set_false_path -from [get_ports perst_n]

set_property PACKAGE_PIN A9 [get_ports clkreq_n]
set_property IOSTANDARD LVCMOS33 [get_ports clkreq_n]
set_property PULLDOWN true [get_ports clkreq_n]

set_property PACKAGE_PIN B6 [get_ports refclk_p]
create_clock -period 10.000 -name sys_clk [get_ports refclk_p]

set_property LOC GTPE2_CHANNEL_X0Y3 [get_cells {xdma/inst/xdma_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
set_property PACKAGE_PIN G3 [get_ports per0_n]
set_property PACKAGE_PIN G4 [get_ports per0_p]
set_property PACKAGE_PIN B1 [get_ports pet0_n]
set_property PACKAGE_PIN B2 [get_ports pet0_p]

set_property PACKAGE_PIN V14 [get_ports {leds[2]}]
set_property PACKAGE_PIN V13 [get_ports {leds[1]}]
set_property PACKAGE_PIN V12 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]
set_property PULLUP true [get_ports {leds[2]}]
set_property PULLUP true [get_ports {leds[1]}]
set_property PULLUP true [get_ports {leds[0]}]
set_property DRIVE 8 [get_ports {leds[2]}]
set_property DRIVE 8 [get_ports {leds[1]}]
set_property DRIVE 8 [get_ports {leds[0]}]

# 0..3 are connector pins 1, 2, 4, 5
set_property PACKAGE_PIN A14 [get_ports {iocon[0]}]
set_property PACKAGE_PIN A13 [get_ports {iocon[1]}]
set_property PACKAGE_PIN B12 [get_ports {iocon[2]}]
set_property PACKAGE_PIN A12 [get_ports {iocon[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {iocon[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {iocon[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {iocon[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {iocon[3]}]

set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]


# ================================================================
# CDC Constraints: userclk1 (125 MHz) <-> clk_out1_clk_wiz_0 (10 MHz)
# ================================================================



# CDC Constraints: userclk1 (125 MHz) <-> clk_out1_clk_wiz_0 (10 MHz)
set_max_delay -datapath_only -from [get_clocks userclk1] -to [get_clocks clk_out1_clk_wiz_0] 8.000
set_max_delay -datapath_only -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks userclk1] 8.000
set_bus_skew -from [get_clocks userclk1] -to [get_clocks clk_out1_clk_wiz_0] 8.000
set_bus_skew -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks userclk1] 8.000

# Async reset paths
set_false_path -to [get_pins ffn_adapter/rst_n_meta_reg/D]
set_false_path -to [get_pins ffn_adapter/adapter_rst_n_reg/CLR]