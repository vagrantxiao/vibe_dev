puts ${argc}

if {${argc} != 4} {
	puts stderr "Should -tclargs <app_kernel> <clk_ns> <part> <board>!"
	exit 1
}

set APP_NAME  "[lindex $argv 0]"
set PERIOD    "[lindex $argv 1]"
set PART      "[lindex $argv 2]"
set BOARD     "[lindex $argv 3]"

set SRC_DIR   "."

open_project hls
set_top ${APP_NAME} 
add_files "${SRC_DIR}/c/Serpen.h"
add_files "${SRC_DIR}/c/Serpen.cpp"
add_files -tb "${SRC_DIR}/c/host.cpp" -cflags "-Wno-unknown-pragmas" -csimflags "-Wno-unknown-pragmas"
open_solution "solution" -flow_target vivado
set_part ${PART}
create_clock -period ${PERIOD} -name default
#csim_design -clean -O
csynth_design
# cosim_design -trace_level all
# export_design -format ip_catalog
