// Extra top-level module compiled only for Icarus runs, so tb_top stays
// simulator-agnostic. vvp is invoked with -fst to emit FST instead of VCD.
module iverilog_dump;
  initial begin
    $dumpfile("dump.fst");
    $dumpvars(0, tb_top);
  end
endmodule
