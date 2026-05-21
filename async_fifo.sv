module async_fifo#(
      parameter DATAWIDTH = 8
    , parameter ADDRWIDTH = 4
    )(
      input                  wclk
    , input                  wrst_n
    , input                  wrreq
    , input [DATAWIDTH-1:0]  data
    , output                 full

    , input                  rclk
    , input                  rrst_n
    , input                  rdreq
    , output [DATAWIDTH-1:0] q
    , output                 empty
);

  // -------------------------------------------------------
  // Dual-port memory
  // -------------------------------------------------------
  reg [DATAWIDTH-1:0] mem [0:2**ADDRWIDTH-1];

  // -------------------------------------------------------
  // Write pointer (ADDRWIDTH+1 bits, MSB = wrap bit)
  // -------------------------------------------------------
  reg [ADDRWIDTH:0] wptr;

  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      wptr <= '0;
    else if (wrreq && !full)
      wptr <= wptr + 1'b1;
  end

  // Write memory on every accepted write
  always @(posedge wclk) begin
    if (wrreq && !full)
      mem[wptr[ADDRWIDTH-1:0]] <= data;
  end

  // -------------------------------------------------------
  // Stubs (replaced in later milestones)
  // -------------------------------------------------------
  assign full  = 1'b0;
  assign empty = 1'b1;
  assign q     = '0;

endmodule
        

