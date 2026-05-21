create_project project_1 project_1 -part xczu9eg-ffvb1156-2-e
set_property board_part xilinx.com:zcu102:part0:3.4 [current_project]
add_files ../async_fifo.sv
add_files ../asynchronizer.sv
add_files ../ydff.sv
add_files -fileset sim_1 ../tb_top.sv
update_compile_order -fileset sim_1
set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
#source tb_top.tcl
run all
close_sim
