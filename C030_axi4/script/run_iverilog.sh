#!/bin/bash
set -euo pipefail

IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}

# Icarus always prints a harmless "sorry" notice for part/struct-field reads in
# always_comb (no -W flag disables it); filter it while keeping other messages.
"$IVERILOG" -g2012 -s tb_top -s iverilog_dump -o tb_top.vvp \
  -f ../script/filelist.f ../script/iverilog_dump.sv 2>&1 \
  | { grep -v "sorry: constant selects in always_\* processes are not fully supported" || true; }
"$VVP" -n tb_top.vvp -fst
