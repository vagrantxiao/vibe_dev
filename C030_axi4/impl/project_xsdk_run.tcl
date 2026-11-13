
connect -url tcp:127.0.0.1:3121
source /tools/Xilinx/Vitis/2022.2/scripts/vitis/util/zynqmp_utils.tcl
targets -set -nocase -filter {name =~"APU*"}
rst -system
after 3000
targets -set -filter {jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && level==0 && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-14710093-0"}
fpga -file /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/sdk_ws/my_app/_ide/bitstream/design_1_wrapper.bit
targets -set -nocase -filter {name =~"APU*"}
loadhw -hw /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/sdk_ws/floorplan_static_wrapper_hw_platform_0/export/floorplan_static_wrapper_hw_platform_0/hw/design_1_wrapper.xsa -mem-ranges [list {0x80000000 0xbfffffff} {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}] -regs
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}
set mode [expr [mrd -value 0xFF5E0200] & 0xf]
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor
dow /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/sdk_ws/floorplan_static_wrapper_hw_platform_0/export/floorplan_static_wrapper_hw_platform_0/sw/floorplan_static_wrapper_hw_platform_0/boot/fsbl.elf
set bp_16_32_fsbl_bp [bpadd -addr &XFsbl_Exit]
con -block -timeout 60
bpremove $bp_16_32_fsbl_bp
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor
dow /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/sdk_ws/my_app/Debug/my_app.elf
configparams force-mem-access 0
targets -set -nocase -filter {name =~ "*A53*#0"}
con
