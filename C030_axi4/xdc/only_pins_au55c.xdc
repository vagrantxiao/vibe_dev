# Copyright 2023 RapidStream Design Automation, Inc.
# All Rights Reserved.

set_property PACKAGE_PIN BE45 [get_ports HBM_CATTRIP]
set_property IOSTANDARD LVCMOS18 [get_ports HBM_CATTRIP]
set_property PULLDOWN true [get_ports HBM_CATTRIP]


set_property PACKAGE_PIN AR14 [get_ports {pcie_refclk_clk_n[0]}]
set_property PACKAGE_PIN AR15 [get_ports {pcie_refclk_clk_p[0]}]

set_property PACKAGE_PIN BF41 [get_ports pcie_perstn]
set_property IOSTANDARD LVCMOS18 [get_ports pcie_perstn]

set_property PACKAGE_PIN AN1 [get_ports {pci_express_x4_rxn[3]}]
set_property PACKAGE_PIN AN5 [get_ports {pci_express_x4_rxn[2]}]
set_property PACKAGE_PIN AM3 [get_ports {pci_express_x4_rxn[1]}]
set_property PACKAGE_PIN AN2 [get_ports {pci_express_x4_rxp[3]}]
set_property PACKAGE_PIN AN6 [get_ports {pci_express_x4_rxp[2]}]
set_property PACKAGE_PIN AM4 [get_ports {pci_express_x4_rxp[1]}]
set_property PACKAGE_PIN AP8 [get_ports {pci_express_x4_txn[3]}]
set_property PACKAGE_PIN AN10 [get_ports {pci_express_x4_txn[2]}]
set_property PACKAGE_PIN AM8 [get_ports {pci_express_x4_txn[1]}]
set_property PACKAGE_PIN AP9 [get_ports {pci_express_x4_txp[3]}]
set_property PACKAGE_PIN AN11 [get_ports {pci_express_x4_txp[2]}]
set_property PACKAGE_PIN AM9 [get_ports {pci_express_x4_txp[1]}]
set_property PACKAGE_PIN AL2 [get_ports {pci_express_x4_rxp[0]}]
set_property PACKAGE_PIN AL1 [get_ports {pci_express_x4_rxn[0]}]
set_property PACKAGE_PIN AL11 [get_ports {pci_express_x4_txp[0]}]
set_property PACKAGE_PIN AL10 [get_ports {pci_express_x4_txn[0]}]

set_property IOSTANDARD LVDS [get_ports {hbm_clk_clk_n[0]}]
set_property PACKAGE_PIN BK43 [get_ports {hbm_clk_clk_p[0]}]
set_property PACKAGE_PIN BK44 [get_ports {hbm_clk_clk_n[0]}]
set_property IOSTANDARD LVDS [get_ports {hbm_clk_clk_p[0]}]


create_clock -period 10.000 -name {pcie_refclk_clk_p[0]} -waveform {0.000 5.000} [get_ports {pcie_refclk_clk_p[0]}]
set_input_delay -clock [get_clocks {pcie_refclk_clk_p[0]}] -min -add_delay 0.000 [get_ports pcie_perstn]
set_input_delay -clock [get_clocks {pcie_refclk_clk_p[0]}] -max -add_delay 0.000 [get_ports pcie_perstn]
set_clock_groups -asynchronous -group [get_clocks design_1_i/xdma_0/inst/pcie4c_ip_i/inst/design_1_xdma_0_0_pcie4c_ip_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_intclk/O] -group [get_clocks {pcie_refclk_clk_p[0]}]

create_clock -period 10.000 -name {hbm_clk_clk_p[0]} -waveform {0.000 5.000} [get_ports {hbm_clk_clk_p[0]}]
set_clock_groups -asynchronous -group [get_clocks {pcie_refclk_clk_p[0]}] -group [get_clocks xdma_0_axi_aclk]
set_clock_groups -asynchronous -group [get_clocks {pcie_refclk_clk_p[0]}] -group [get_clocks pipe_clk]

