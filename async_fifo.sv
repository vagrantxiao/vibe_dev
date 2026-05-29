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
  // MS2: Full CDC implementation
  //   - Dual-port register array
  //   - Binary counters + Gray encoding per domain
  //   - 2-FF synchronizers in each direction
  //   - Full flag in wclk domain, empty flag in rclk domain
  //   - FWFT combinational read port
  //   - Independent async resets per domain
  // -----------------------------------------------------------------------
  localparam DEPTH = 1 << ADDRWIDTH;

  // Memory
  logic [DATAWIDTH-1:0] mem [0:DEPTH-1];

  // -----------------------------------------------------------------------
  // Write-domain signals
  // -----------------------------------------------------------------------
  logic [ADDRWIDTH:0] wbin;           // binary write pointer
  logic [ADDRWIDTH:0] wbin_next;
  logic [ADDRWIDTH:0] wgray;          // Gray-encoded write pointer
  logic [ADDRWIDTH:0] wgray_next;

  // -----------------------------------------------------------------------
  // Read-domain signals
  // -----------------------------------------------------------------------
  logic [ADDRWIDTH:0] rbin;           // binary read pointer
  logic [ADDRWIDTH:0] rbin_next;
  logic [ADDRWIDTH:0] rgray;          // Gray-encoded read pointer
  logic [ADDRWIDTH:0] rgray_next;

  // -----------------------------------------------------------------------
  // 2-FF synchronizers
  //   rgray_sync : rgray  →  wclk domain  (used for full)
  //   wgray_sync : wgray  →  rclk domain  (used for empty)
  // -----------------------------------------------------------------------
  logic [ADDRWIDTH:0] rgray_sync1, rgray_sync2;
  logic [ADDRWIDTH:0] wgray_sync1, wgray_sync2;

  // =======================================================================
  // WRITE DOMAIN
  // =======================================================================

  assign wbin_next  = wbin + (ADDRWIDTH+1)'(wrreq & ~full);
  assign wgray_next = (wbin_next >> 1) ^ wbin_next;  // binary → Gray

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wbin  <= '0;
      wgray <= '0;
    end else begin
      wbin  <= wbin_next;
      wgray <= wgray_next;
    end
  end

  // Write port
  always_ff @(posedge wclk) begin
    if (wrreq && !full)
      mem[wbin[ADDRWIDTH-1:0]] <= data;
  end

  // Synchronize rgray into wclk domain
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      rgray_sync1 <= '0;
      rgray_sync2 <= '0;
    end else begin
      rgray_sync1 <= rgray;
      rgray_sync2 <= rgray_sync1;
    end
  end

  // Full flag: next wgray == rgray_sync with top 2 bits inverted
  // This detects write pointer lapping the read pointer
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      full <= 1'b0;
    else
      full <= (wgray_next == {~rgray_sync2[ADDRWIDTH:ADDRWIDTH-1],
                               rgray_sync2[ADDRWIDTH-2:0]});
  end

  // =======================================================================
  // READ DOMAIN
  // =======================================================================

  assign rbin_next  = rbin + (ADDRWIDTH+1)'(rdreq & ~empty);
  assign rgray_next = (rbin_next >> 1) ^ rbin_next;  // binary → Gray

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rbin  <= '0;
      rgray <= '0;
    end else begin
      rbin  <= rbin_next;
      rgray <= rgray_next;
    end
  end

  // FWFT: q is always the current head of the FIFO
  assign q = mem[rbin[ADDRWIDTH-1:0]];

  // Synchronize wgray into rclk domain
  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      wgray_sync1 <= '0;
      wgray_sync2 <= '0;
    end else begin
      wgray_sync1 <= wgray;
      wgray_sync2 <= wgray_sync1;
    end
  end

  // Empty flag: next rgray == wgray_sync (no new data has arrived)
  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
      empty <= 1'b1;
    else
      empty <= (rgray_next == wgray_sync2);
  end

endmodule
