############################################################
## This file is generated automatically by Vitis HLS.
## Please DO NOT edit it.
## Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
############################################################
open_project build
set_top datamover
add_files     ./read_and_write.cpp
add_files     ./read_and_write.h
add_files -tb ./read_and_write_host.cpp -cflags   "-Wno-unknown-pragmas -Wno-unknown-pragmas" -csimflags "-Wno-unknown-pragmas"
open_solution "solution" -flow_target vivado
set_part {xcu50-fsvh2104-2-e}
create_clock -period 10 -name default
set_directive_top -name datamover "datamover"
#csim_design -clean -O
csynth_design
#cosim_design -O -trace_level all
#export_design -format ip_catalog
