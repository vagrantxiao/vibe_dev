module async_fifo#(
      parameter int DATAWIDTH = 8
    , parameter int ADDRWIDTH = 4
    )(
      input  logic                 wclk
    , input  logic                 wrst_n
    , input  logic                 wrreq
    , input  logic [DATAWIDTH-1:0] data
    , output logic                 full

    , input  logic                 rclk
    , input  logic                 rrst_n
    , input  logic                 rdreq
    , output logic [DATAWIDTH-1:0] q
    , output logic                 empty
);

  // -------------------------------------------------------
  // Dual-port memory
  // -------------------------------------------------------
  logic [DATAWIDTH-1:0] mem [2**ADDRWIDTH];

  // -------------------------------------------------------
  // Write pointer (ADDRWIDTH+1 bits, MSB = wrap bit)
  // -------------------------------------------------------
  logic [ADDRWIDTH:0] wptr;

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      wptr <= '0;
    else if (wrreq && !full)
      wptr <= wptr + 1'b1;
  end

  // Write memory on every accepted write
  always_ff @(posedge wclk) begin
    if (wrreq && !full)
      mem[wptr[ADDRWIDTH-1:0]] <= data;
  end

  // -------------------------------------------------------
  // Read pointer (ADDRWIDTH+1 bits, MSB = wrap bit)
  // -------------------------------------------------------
  logic [ADDRWIDTH:0] rptr;

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
      rptr <= '0;
    else if (rdreq && !empty)
      rptr <= rptr + 1'b1;
  end

  // FWFT: q is combinatorial read from memory
  assign q = mem[rptr[ADDRWIDTH-1:0]];

  // -------------------------------------------------------
  // Stubs (replaced in later milestones)
  // -------------------------------------------------------
  assign full  = 1'b0;
  assign empty = 1'b1;

endmodule
        

