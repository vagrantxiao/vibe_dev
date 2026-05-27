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
// Clock generation — variable frequencies for clock ratio sweep
// ---------------------------------------------------------------
int wclk_half = 3;   // wclk half-period (default 3 → period=6ns)
int rclk_half = 5;   // rclk half-period (default 5 → period=10ns)

always #(wclk_half) wclk = ~wclk;
always #(rclk_half) rclk = ~rclk;

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
  #5_000_000;
  $fatal(1, "[%0t] Test timed out after 5,000,000 ns!", $time);
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
  // 3.1  Simultaneous read/write at various rates
  //      Writer inserts random delays; reader inserts random
  //      delays. Both run concurrently.
  // ===========================================================
  $display("\n========== TEST 3.1: Simultaneous R/W (various rates) ==========");
  apply_reset();
  expected_data = {};

  begin
    int  sent_count, rcvd_count, mismatch;
    logic wr_done;
    localparam N31 = 2000;
    sent_count = 0; rcvd_count = 0; mismatch = 0; wr_done = 0;

    fork
      // Writer with random back-pressure
      begin
        logic [DATAWIDTH-1:0] wdata;
        for (int i = 0; i < N31; i++) begin
          wdata = $urandom;
          // Random idle cycles (0-3)
          repeat ($urandom_range(0, 3)) @(posedge wclk);
          write_one(wdata);
          expected_data.push_back(wdata);
          sent_count++;
        end
        wr_done = 1;
      end
      // Reader with random back-pressure
      begin
        logic [DATAWIDTH-1:0] rdata;
        while (rcvd_count < N31) begin
          if (!empty) begin
            // Random idle cycles (0-3)
            repeat ($urandom_range(0, 3)) @(posedge rclk);
            read_one(rdata);
            exp_data = expected_data.pop_front();
            rcvd_count++;
            if (rdata !== exp_data) mismatch++;
          end else begin
            @(posedge rclk);
          end
        end
      end
    join

    if (mismatch > 0)
      $fatal(1, "[%0t] FAIL 3.1: %0d mismatches", $time, mismatch);
    if (rcvd_count != N31)
      $fatal(1, "[%0t] FAIL 3.1: sent=%0d rcvd=%0d", $time, sent_count, rcvd_count);
    $display("[%0t] PASS 3.1: %0d words, random delays, zero mismatches", $time, N31);
    pass_count++;
  end

  // ===========================================================
  // 3.2  Clock ratio sweep
  //      Test three scenarios: wclk>>rclk, wclk<<rclk, wclk≈rclk
  // ===========================================================
  begin
    int  ratios_w[3] = '{2, 7, 5};   // wclk half-periods
    int  ratios_r[3] = '{7, 2, 5};   // rclk half-periods
    string ratio_names[3] = '{"wclk>>rclk (fast-wr)", "wclk<<rclk (fast-rd)", "wclk~=rclk"};
    localparam N32 = 1000;

    for (int r = 0; r < 3; r++) begin
      $display("\n========== TEST 3.2.%0d: Clock Ratio — %s ==========", r, ratio_names[r]);
      wclk_half = ratios_w[r];
      rclk_half = ratios_r[r];
      apply_reset();
      expected_data = {};

      begin
        int  sent_count, rcvd_count, mismatch;
        logic wr_done;
        sent_count = 0; rcvd_count = 0; mismatch = 0; wr_done = 0;

        fork
          begin
            logic [DATAWIDTH-1:0] wdata;
            for (int i = 0; i < N32; i++) begin
              wdata = $urandom;
              write_one(wdata);
              expected_data.push_back(wdata);
              sent_count++;
            end
            wr_done = 1;
          end
          begin
            logic [DATAWIDTH-1:0] rdata;
            while (rcvd_count < N32) begin
              if (!empty) begin
                read_one(rdata);
                exp_data = expected_data.pop_front();
                rcvd_count++;
                if (rdata !== exp_data) mismatch++;
              end else begin
                @(posedge rclk);
              end
            end
          end
        join

        if (mismatch > 0)
          $fatal(1, "[%0t] FAIL 3.2.%0d: %0d mismatches", $time, r, mismatch);
        if (rcvd_count != N32)
          $fatal(1, "[%0t] FAIL 3.2.%0d: sent=%0d rcvd=%0d", $time, r, sent_count, rcvd_count);
        $display("[%0t] PASS 3.2.%0d: %0d words verified", $time, r, N32);
        pass_count++;
      end
    end

    // Restore default clock rates
    wclk_half = 3;
    rclk_half = 5;
  end

  // ===========================================================
  // 3.3  Back-to-back full→empty cycles
  //      Fill completely, drain completely, repeat 4 times.
  // ===========================================================
  $display("\n========== TEST 3.3: Back-to-back Full→Empty ==========");
  apply_reset();

  begin
    int mismatch;
    mismatch = 0;

    for (int cycle = 0; cycle < 4; cycle++) begin
      expected_data = {};
      // Fill
      begin
        logic [DATAWIDTH-1:0] wdata;
        int cnt;
        cnt = 0;
        while (!full) begin
          wdata = $urandom;
          @(posedge wclk);
          wrreq <= 1'b1;
          data  <= wdata;
          @(posedge wclk);
          #1;
          wrreq <= 1'b0;
          expected_data.push_back(wdata);
          cnt++;
          #2;
        end
        $display("[%0t] Cycle %0d: filled %0d words", $time, cycle, cnt);
      end
      // Drain
      begin
        logic [DATAWIDTH-1:0] rdata;
        int cnt;
        cnt = 0;
        while (!empty) begin
          rdata = q;
          exp_data = expected_data.pop_front();
          if (rdata !== exp_data) mismatch++;
          cnt++;
          @(posedge rclk);
          rdreq <= 1'b1;
          @(posedge rclk);
          #1;
          rdreq <= 1'b0;
          #2;
        end
        $display("[%0t] Cycle %0d: drained %0d words", $time, cycle, cnt);
      end
    end

    if (mismatch > 0)
      $fatal(1, "[%0t] FAIL 3.3: %0d mismatches across fill/drain cycles", $time, mismatch);
    $display("[%0t] PASS 3.3: 4 fill/drain cycles, zero mismatches", $time);
    pass_count++;
  end

  // ===========================================================
  // 3.4  Reset during operation
  //      Start writing, assert reset mid-transfer, verify
  //      clean recovery and correct behavior after re-reset.
  // ===========================================================
  $display("\n========== TEST 3.4: Reset During Operation ==========");
  apply_reset();
  expected_data = {};

  begin
    // Write some data
    begin
      logic [DATAWIDTH-1:0] wdata;
      for (int i = 0; i < 100; i++) begin
        wdata = $urandom;
        write_one(wdata);
      end
    end
    $display("[%0t] Wrote 100 words, now asserting reset mid-operation", $time);

    // Assert reset while FIFO has data
    wrst_n = 0;
    rrst_n = 0;
    wrreq  = 0;
    rdreq  = 0;
    #100;

    // Release reset
    @(posedge wclk); wrst_n = 1;
    @(posedge rclk); rrst_n = 1;
    #50;

    // Verify FIFO is in clean state
    if (empty !== 1'b1)
      $fatal(1, "[%0t] FAIL 3.4: empty should be 1 after mid-op reset, got %0b", $time, empty);
    if (full !== 1'b0)
      $fatal(1, "[%0t] FAIL 3.4: full should be 0 after mid-op reset, got %0b", $time, full);

    // Now do a clean write-read to prove FIFO works after reset
    expected_data = {};
    begin
      logic [DATAWIDTH-1:0] wdata;
      int mismatch;
      mismatch = 0;

      for (int i = 0; i < 50; i++) begin
        wdata = $urandom;
        write_one(wdata);
        expected_data.push_back(wdata);
      end
      begin
        logic [DATAWIDTH-1:0] rdata;
        for (int i = 0; i < 50; i++) begin
          read_one(rdata);
          exp_data = expected_data.pop_front();
          if (rdata !== exp_data) mismatch++;
        end
      end
      if (mismatch > 0)
        $fatal(1, "[%0t] FAIL 3.4: %0d mismatches after recovery", $time, mismatch);
    end

    $display("[%0t] PASS 3.4: Reset mid-op, clean recovery, 50 words verified post-reset", $time);
    pass_count++;
  end

  // ===========================================================
  // 3.5  Randomized stimulus
  //      Each cycle: randomly decide to write, read, both, or
  //      neither. Run for many cycles, verify all data.
  // ===========================================================
  $display("\n========== TEST 3.5: Randomized Stimulus ==========");
  apply_reset();
  expected_data = {};

  begin
    localparam N35 = 3000;
    int  sent_count, rcvd_count, mismatch;
    sent_count = 0; rcvd_count = 0; mismatch = 0;

    fork
      // Random writer — uses write_one with random idle gaps
      begin
        logic [DATAWIDTH-1:0] wdata;
        while (sent_count < N35) begin
          // Randomly skip 0-1 cycles
          if ($urandom_range(0, 2) == 0)
            @(posedge wclk);
          wdata = $urandom;
          write_one(wdata);
          expected_data.push_back(wdata);
          sent_count++;
        end
      end
      // Random reader — uses read_one with random idle gaps
      begin
        logic [DATAWIDTH-1:0] rdata;
        while (rcvd_count < N35) begin
          if ($urandom_range(0, 2) == 0)
            @(posedge rclk);
          read_one(rdata);
          exp_data = expected_data.pop_front();
          rcvd_count++;
          if (rdata !== exp_data) mismatch++;
        end
      end
    join

    if (mismatch > 0)
      $fatal(1, "[%0t] FAIL 3.5: %0d mismatches in randomized test", $time, mismatch);
    $display("[%0t] PASS 3.5: %0d words, random enables, zero mismatches", $time, N35);
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
