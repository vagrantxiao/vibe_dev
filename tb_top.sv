module tb_top();

localparam DATAWIDTH  = 32;
localparam ADDRWIDTH  = 10;
localparam DEPTH      = 1 << ADDRWIDTH;
localparam TEST_NUM   = 2000;

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

logic [DATAWIDTH-1:0] data_in;
logic [31:0]          sent_count = 0;
logic [31:0]          rcvd_count = 0;

// Shared expected-data queue and reader-enable flag
logic [DATAWIDTH-1:0] expected_data[$];
logic [DATAWIDTH-1:0] exp_data;
logic                 rd_en     = 0;  // enables/disables the reader thread


always #3 wclk = ~wclk;
always #5 rclk = ~rclk;

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

// =========================================================================
// Global timeout
// =========================================================================
initial begin
  #500_000;
  $fatal(1, "[%0t] Test timed out!", $time);
end

// =========================================================================
// Helper tasks
// =========================================================================
task automatic send_item(input logic [DATAWIDTH-1:0] d);
  wait(!full);
  @(posedge wclk); #1;
  wrreq = 1'b1;
  data  = d;
  @(posedge wclk); #1;
  wrreq = 1'b0;
  expected_data.push_back(d);
  sent_count++;
endtask

task automatic check_empty_after_drain;
  // wait up to 1000 rclk cycles for FIFO to drain and empty to assert
  repeat (1000) @(posedge rclk);
  if (!empty)
    $fatal(1, "[%0t] ERROR: FIFO not empty after drain!", $time);
endtask

// =========================================================================
// Reader thread — active only when rd_en is high
// =========================================================================
initial begin
  wait(rrst_n);
  forever begin
    @(posedge rclk); #1;
    rdreq = 1'b0;
    if (!rd_en) continue;
    wait(!empty && rd_en);
    exp_data = expected_data.pop_front();
    rcvd_count++;
    if (q !== exp_data) begin
      $display("[%0t][%0d] MISMATCH: expected=0x%08h actual=0x%08h",
               $time, rcvd_count, exp_data, q);
      $fatal(1, "[%0t] Data mismatch!", $time);
    end else begin
      $display("[%0t][%0d] OK: 0x%08h", $time, rcvd_count, q);
    end
    rdreq = 1'b1;
  end
end

// =========================================================================
// Main test sequence
// =========================================================================
initial begin
  // ---- Reset both domains -----------------------------------------------
  #100;
  @(posedge wclk); wrst_n = 1;
  $display("[%0t] wrst_n released", $time);
  @(posedge rclk); rrst_n = 1;
  $display("[%0t] rrst_n released", $time);
  #50;

  // =========================================================================
  // TC1: Fill-to-full → drain-to-empty
  // =========================================================================
  $display("\n[%0t] === TC1: Fill-to-full → drain-to-empty ===", $time);
  rd_en = 0;  // hold reader off so we can fill completely

  // Fill DEPTH items
  for (int i = 0; i < DEPTH; i++) begin
    data_in = $urandom;
    send_item(data_in);
  end

  // FIFO must now be full
  @(posedge wclk); #1;
  if (!full)
    $fatal(1, "[%0t] TC1 FAIL: expected full to be asserted after filling %0d entries", $time, DEPTH);
  $display("[%0t] TC1: full asserted correctly after %0d writes", $time, DEPTH);

  // Try one more write — should be ignored (full)
  wrreq = 1'b1; data = 32'hDEADBEEF;
  @(posedge wclk); #1;
  wrreq = 1'b0;
  if (sent_count !== DEPTH)
    $fatal(1, "[%0t] TC1 FAIL: write was accepted while full!", $time);
  $display("[%0t] TC1: back-pressure write correctly blocked", $time);

  // Drain the FIFO
  rd_en = 1;
  wait(rcvd_count == DEPTH);
  rd_en = 0;
  @(posedge rclk); #1;
  rdreq = 1'b0;

  // Wait for empty to propagate
  repeat (10) @(posedge rclk);
  if (!empty)
    $fatal(1, "[%0t] TC1 FAIL: expected empty to be asserted after full drain", $time);
  $display("[%0t] TC1: empty asserted correctly after full drain", $time);
  $display("[%0t] TC1 PASSED", $time);

  // =========================================================================
  // TC2: Simultaneous wrreq + rdreq with exactly 1 entry in FIFO
  // =========================================================================
  $display("\n[%0t] === TC2: Simultaneous write+read with 1 entry ===", $time);
  rd_en = 0;

  // Write exactly 1 item
  data_in = $urandom;
  send_item(data_in);

  // With 1 entry: assert rdreq and wrreq at the same time
  data_in = $urandom;
  wait(!full && !empty);
  @(posedge wclk); #1;
  wrreq = 1'b1;  data  = data_in;
  // simultaneously enable read on the next rclk edge
  fork
    begin
      @(posedge rclk); #1;
      rdreq = 1'b1;
      @(posedge rclk); #1;
      rdreq = 1'b0;
    end
  join_none
  @(posedge wclk); #1;
  wrreq = 1'b0;
  expected_data.push_back(data_in);
  sent_count++;

  // Let the queued read complete and verify
  rd_en = 1;
  wait(rcvd_count == sent_count);
  rd_en = 0;
  @(posedge rclk); #1;
  rdreq = 1'b0;
  repeat (10) @(posedge rclk);
  $display("[%0t] TC2 PASSED", $time);

  // =========================================================================
  // TC3: Main regression — TEST_NUM random items, wclk faster than rclk
  // =========================================================================
  $display("\n[%0t] === TC3: Main regression (%0d items) ===", $time, TEST_NUM);
  rd_en = 1;

  for (int i = 0; i < TEST_NUM; i++) begin
    data_in = $urandom;
    send_item(data_in);
  end

  // Wait for all sent items to be received
  wait(rcvd_count == sent_count);
  repeat (50) @(posedge rclk);
  if (!empty)
    $fatal(1, "[%0t] TC3 FAIL: FIFO not empty after regression", $time);
  $display("[%0t] TC3 PASSED", $time);

  // =========================================================================
  // All tests passed
  // =========================================================================
  $display("\n[%0t] *** All tests completed successfully! sent=%0d rcvd=%0d ***",
           $time, sent_count, rcvd_count);
  $finish();
end

endmodule
