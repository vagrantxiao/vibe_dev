#!/bin/bash -f
set -e

if ! command -v vivado >/dev/null 2>&1; then
  source /tools/Xilinx/Vivado/2022.1/settings64.sh
fi

xvlog -sv -f ../script/filelist.f -L uvm -L xpm -define XSIM
xelab tb_top -relax -debug typical -L xpm -s tb_top -timescale 1ns/1ps
xsim tb_top -wdb dump.wdb -tclbatch ../script/xsim_wave.tcl --testplusarg AFIFO_TRACE
