create_project project_1 /home/ylxiao/ws232/vibe_dev/build/project_1 -part xczu9eg-ffvb1156-2-e
set_property board_part xilinx.com:zcu102:part0:3.4 [current_project]
add_files -norecurse {/home/ylxiao/ws232/vibe_dev/async_fifo.sv /home/ylxiao/ws232/vibe_dev/asynchronizer.sv /home/ylxiao/ws232/vibe_dev/ydff.sv}
update_compile_order -fileset sources_1
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse /home/ylxiao/ws232/vibe_dev/tb_top.sv
update_compile_order -fileset sim_1
update_compile_order -fileset sim_1
# Disabling source management mode.  This is to allow the top design properties to be set without GUI intervention.
set_property source_mgmt_mode None [current_project]
set_property top async_fifo [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
# Re-enabling previously disabled source management mode.
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sim_1
# Disabling source management mode.  This is to allow the top design properties to be set without GUI intervention.
set_property source_mgmt_mode None [current_project]
set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
# Re-enabling previously disabled source management mode.
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sim_1
launch_simulation
source tb_top.tcl
run all
close_sim
