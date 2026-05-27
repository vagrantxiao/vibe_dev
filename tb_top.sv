module tb_top();

// ---------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------
localparam DATAWIDTH = 32;
localparam ADDRWIDTH = 10;
localparam DEPTH     = 1 << ADDRWIDTH;    // 1024
localparam TEST_NUM  = 2000;

// ---------------------------------------------------------------
// Signals
// ---------------------------------------------------------------
logic                 wclk      = 0;
logic                 rclk      = 0;
logic                 wrst_n    = 0;
logic                 rrst_n    = 0;
logic                 wrreq     = 0;
logic                 rdreq     = 0;
logic [DATAWIDTH-1:0] data      = 0;
logic                 full;
logic                 empty;
logic [DATAWIDTH-1:0] q;

logic [DATAWIDTH-1:0] expected_data[$];
logic [DATAWIDTH-1:0] exp_data;
int                   pass_count = 0;
int                   fail_count = 0;

// ---------------------------------------------------------------
// 2.1  Clock generation — independent frequencies
// ---------------------------------------------------------------
always #3 wclk = ~wclk;   // wclk period = 6 ns
always #5 rclk = ~rclk;   // rclk period = 10 ns

// ---------------------------------------------------------------
// DUT instantiation
// ---------------------------------------------------------------
async_fifo#(
      .DATAWIDTH (DATAWIDTH  )
    , .ADDRWIDTH (ADDRWIDTH  )
)dut(
      .wclk      (wclk       )
    , .wrst_n    (wrst_n     )
    , .wrreq     (wrreq      )
    , .data      (data       )
    , .full      (full       )
    , .rclk      (rclk       )
    , .rrst_n    (rrst_n     )
    , .rdreq     (rdreq      )
    , .q         (q          )
    , .empty     (empty      )
);

// ---------------------------------------------------------------
// Timeout
// ---------------------------------------------------------------
initial begin
  #500_000;
  $fatal(1, "[%0t] Test timed out after 500,000 ns!", $time);
end

// ---------------------------------------------------------------
// Helper tasks
// ---------------------------------------------------------------

// Write one word (waits for !full)
task automatic write_one(input logic [DATAWIDTH-1:0] wdata);
  wait(!full);
  @(posedge wclk);
  wrreq <= 1'b1;
  data  <= wdata;
  @(posedge wclk);
  #1;
  wrreq <= 1'b0;
endtask

// Read one word (waits for !empty, returns data via q)
task automatic read_one(output logic [DATAWIDTH-1:0] rdata);
  wait(!empty);
  rdata = q;              // async read — data available before rdreq
  @(posedge rclk);
  rdreq <= 1'b1;
  @(posedge rclk);
  #1;
  rdreq <= 1'b0;
endtask

// Apply reset
task automatic apply_reset();
  wrst_n = 0;
  rrst_n = 0;
  wrreq  = 0;
  rdreq  = 0;
  data   = 0;
  #100;
  @(posedge wclk); wrst_n = 1;
  @(posedge rclk); rrst_n = 1;
  #50;  // let synchronizers settle
endtask

// ---------------------------------------------------------------
// Master test flow
// ---------------------------------------------------------------
initial begin

  // ===========================================================
  // 2.2  Reset sequence
  // ===========================================================
  $display("\n========== TEST: Reset Sequence ==========");
  apply_reset();
  $display("[%0t] Reset released (wrst_n=1, rrst_n=1)", $time);

  // After reset: empty must be 1, full must be 0
  #20;
  if (empty !== 1'b1) begin
    $fatal(1, "[%0t] FAIL: empty should be 1 after reset, got %0b", $time, empty);
  end
  if (full !== 1'b0) begin
    $fatal(1, "[%0t] FAIL: full should be 0 after reset, got %0b", $time, full);
  end
  $display("[%0t] PASS: After reset — empty=1, full=0", $time);
  pass_count++;

  // ===========================================================
  // 2.4  Full flag test — write until full
  // ===========================================================
  $display("\n========== TEST: Full Flag ==========");
  begin
    int wr_count;
    wr_count = 0;
    expected_data = {};

    // Fill FIFO to capacity
    while (!full) begin
      automatic logic [DATAWIDTH-1:0] wdata = $urandom;
      @(posedge wclk);
      wrreq <= 1'b1;
      data  <= wdata;
      @(posedge wclk);
      #1;
      wrreq <= 1'b0;
      wr_count++;
      expected_data.push_back(wdata);
      // Allow full flag to propagate through synchronizers
      #2;
    end

    $display("[%0t] Wrote %0d words, full=%0b", $time, wr_count, full);

    if (wr_count != DEPTH) begin
      $display("[%0t] WARNING: Expected to write %0d words before full, wrote %0d (conservative full is OK)",
               $time, DEPTH, wr_count);
    end

    // Attempt one more write while full — should be blocked
    @(posedge wclk);
    wrreq <= 1'b1;
    data  <= 32'hDEAD_BEEF;
    @(posedge wclk);
    #1;
    wrreq <= 1'b0;
    // The write guard (wrreq && !full) in RTL prevents this from corrupting memory

    $display("[%0t] PASS: Full flag asserted after filling FIFO", $time);
    pass_count++;
  end

  // ===========================================================
  // 2.5  Empty flag test — read until empty, verify data
  // ===========================================================
  $display("\n========== TEST: Empty Flag ==========");
  begin
    int rd_count;
    logic [DATAWIDTH-1:0] rdata;
    rd_count = 0;

    while (!empty) begin
      rdata = q;
      exp_data = expected_data.pop_front();
      rd_count++;
      if (rdata !== exp_data) begin
        $display("[%0t][%0d] FAIL: expected=0x%08h, actual=0x%08h", $time, rd_count, exp_data, rdata);
        fail_count++;
      end
      @(posedge rclk);
      rdreq <= 1'b1;
      @(posedge rclk);
      #1;
      rdreq <= 1'b0;
      // Allow empty flag to propagate
      #2;
    end

    $display("[%0t] Read %0d words, empty=%0b", $time, rd_count, empty);

    if (fail_count > 0) begin
      $fatal(1, "[%0t] FAIL: %0d data mismatches during empty-flag test", $time, fail_count);
    end

    $display("[%0t] PASS: Empty flag asserted after draining FIFO, all data correct", $time);
    pass_count++;
  end

  // ===========================================================
  // 2.3  Write-then-read (TEST_NUM words, concurrent R/W)
  //      Writer and reader run in parallel; we wait for both
  //      to finish, then verify counts and empty flag.
  // ===========================================================
  $display("\n========== TEST: Write-Then-Read (%0d words) ==========", TEST_NUM);

  // Re-apply reset for a clean state
  apply_reset();
  expected_data = {};

  begin
    int  sent_count;
    int  rcvd_count;
    int  mismatch;
    logic wr_done;
    sent_count = 0;
    rcvd_count = 0;
    mismatch   = 0;
    wr_done    = 0;

    fork
      // --- Writer ---
      begin
        logic [DATAWIDTH-1:0] wdata;
        for (int i = 0; i < TEST_NUM; i++) begin
          wdata = $urandom;
          write_one(wdata);
          expected_data.push_back(wdata);
          sent_count++;
          if (sent_count % 500 == 0)
            $display("[%0t] Sent %0d / %0d", $time, sent_count, TEST_NUM);
        end
        $display("[%0t] Write phase complete — %0d words sent", $time, sent_count);
        wr_done = 1;
      end

      // --- Reader ---
      begin
        logic [DATAWIDTH-1:0] rdata;
        // Keep reading until writer is done AND fifo is drained
        while (!wr_done || !empty) begin
          if (!empty) begin
            read_one(rdata);
            exp_data = expected_data.pop_front();
            rcvd_count++;
            if (rdata !== exp_data) begin
              $display("[%0t][%0d] FAIL: expected=0x%08h, actual=0x%08h",
                       $time, rcvd_count, exp_data, rdata);
              mismatch++;
            end
            if (rcvd_count % 500 == 0)
              $display("[%0t] Received %0d / %0d", $time, rcvd_count, TEST_NUM);
          end else begin
            @(posedge rclk); // wait a cycle if empty
          end
        end
      end
    join

    if (mismatch > 0)
      $fatal(1, "[%0t] FAIL: %0d mismatches in write-then-read test", $time, mismatch);

    if (sent_count != TEST_NUM || rcvd_count != TEST_NUM)
      $fatal(1, "[%0t] FAIL: sent=%0d, rcvd=%0d, expected=%0d",
             $time, sent_count, rcvd_count, TEST_NUM);

    // Wait and check empty
    #200;
    if (!empty)
      $fatal(1, "[%0t] FAIL: FIFO not empty after reading all data", $time);

    $display("[%0t] PASS: Write-then-read — %0d/%0d words verified, FIFO empty",
             $time, rcvd_count, TEST_NUM);
    pass_count++;
  end

  // ===========================================================
  // Summary
  // ===========================================================
  $display("\n==========================================");
  $display("  ALL TESTS PASSED (%0d / %0d)", pass_count, pass_count);
  $display("==========================================\n");
  $finish();
end

endmodule
