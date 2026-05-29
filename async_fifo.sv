module async_fifo#(
      parameter int DATAWIDTH = 8
    , parameter int ADDRWIDTH = 4
    )(
      input  wire                  wclk
    , input  wire                  wrst_n
    , input  wire                  wrreq
    , input  wire  [DATAWIDTH-1:0] data
    , output logic                 full

    , input  wire                  rclk
    , input  wire                  rrst_n
    , input  wire                  rdreq
    , output logic [DATAWIDTH-1:0] q
    , output logic                 empty
);

  // -----------------------------------------------------------------------
  // MS1: Single-clock functional core
  //   - Dual-port register array
  //   - Binary write/read counters (ADDRWIDTH+1 bits, MSB = wrap bit)
  //   - FWFT combinational read port
  //   - Full/empty via direct binary pointer comparison (no CDC sync yet)
  // -----------------------------------------------------------------------
  localparam DEPTH = 1 << ADDRWIDTH;

  // Memory
  logic [DATAWIDTH-1:0] mem [0:DEPTH-1];

  // Write-domain binary pointer
  logic [ADDRWIDTH:0] wptr;

  // Read-domain binary pointer
  logic [ADDRWIDTH:0] rptr;

  // -----------------------------------------------------------------------
  // Full / Empty
  //   Use (ADDRWIDTH+1)-bit pointers so the MSB acts as a wrap toggle:
  //   empty : pointers are equal (same wrap parity, same address)
  //   full  : wrap bits differ, address bits equal
  // -----------------------------------------------------------------------
  assign empty = (wptr == rptr);
  assign full  = (wptr[ADDRWIDTH] != rptr[ADDRWIDTH]) &&
                 (wptr[ADDRWIDTH-1:0] == rptr[ADDRWIDTH-1:0]);

  // -----------------------------------------------------------------------
  // Write port  (wclk domain)
  // -----------------------------------------------------------------------
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      wptr <= '0;
    else if (wrreq && !full) begin
      mem[wptr[ADDRWIDTH-1:0]] <= data;
      wptr <= wptr + 1'b1;
    end
  end

  // -----------------------------------------------------------------------
  // Read port  (rclk domain) — FWFT: q is always the head of the FIFO
  // -----------------------------------------------------------------------
  assign q = mem[rptr[ADDRWIDTH-1:0]];

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
      rptr <= '0;
    else if (rdreq && !empty)
      rptr <= rptr + 1'b1;
  end

endmodule
