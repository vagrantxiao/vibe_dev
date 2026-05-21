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
  // Gray code conversion (combinatorial)
  // -------------------------------------------------------
  logic [ADDRWIDTH:0] wptr_g;
  logic [ADDRWIDTH:0] rptr_g;

  assign wptr_g = wptr ^ (wptr >> 1);
  assign rptr_g = rptr ^ (rptr >> 1);

  // -------------------------------------------------------
  // 2-FF synchronizer: wptr_g → rclk domain
  // -------------------------------------------------------
  logic [ADDRWIDTH:0] wptr_g_ff1, wptr_g_sync;

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      wptr_g_ff1  <= '0;
      wptr_g_sync <= '0;
    end else begin
      wptr_g_ff1  <= wptr_g;
      wptr_g_sync <= wptr_g_ff1;
    end

  end

  // -------------------------------------------------------
  // 2-FF synchronizer: rptr_g → wclk domain
  // -------------------------------------------------------
  logic [ADDRWIDTH:0] rptr_g_ff1, rptr_g_sync;

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      rptr_g_ff1  <= '0;
      rptr_g_sync <= '0;
    end else begin
      rptr_g_ff1  <= rptr_g;
      rptr_g_sync <= rptr_g_ff1;
    end
  end

  // -------------------------------------------------------
  // Empty flag (read clock domain)
  // FIFO is empty when read Gray pointer == synced write Gray pointer
  // -------------------------------------------------------
  assign empty = (rptr_g == wptr_g_sync);

  // -------------------------------------------------------
  // Full flag (write clock domain)
  // FIFO is full when top 2 bits of wptr_g differ from rptr_g_sync
  // and the remaining lower bits are equal (Gray code full condition)
  // -------------------------------------------------------
  assign full = (wptr_g[ADDRWIDTH]   != rptr_g_sync[ADDRWIDTH]  ) &
                (wptr_g[ADDRWIDTH-1] != rptr_g_sync[ADDRWIDTH-1]) &
                (wptr_g[ADDRWIDTH-2:0] == rptr_g_sync[ADDRWIDTH-2:0]);

endmodule
        

