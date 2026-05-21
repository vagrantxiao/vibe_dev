module tb_top();

localparam DATAWIDTH = 32;
localparam ADDRWIDTH = 10;
localparam TEST_NUM = 2000;

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
logic                 send_done = 0;
logic [31:0]          sent_count = 0;
logic [31:0]          rcvd_count = 0;

logic [DATAWIDTH-1:0] expected_data[$];
logic [DATAWIDTH-1:0] exp_data;


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
    , .full      (full      )
    , .rclk      (rclk       )
    , .rrst_n    (rrst_n     )
    , .rdreq     (rdreq      )
    , .q         (q          )
    , .empty     (empty     )
);

initial begin
  #100;
  @(posedge wclk);
  wrst_n = 1;
  $display("wr side is reset");

  @(posedge rclk);
  rrst_n = 1;
  $display("rd side is reste");

  wait(send_done);
  $display("All data sent, waiting for remaining data to be read...");
  #10000
  if (!empty) begin
    $display("Error: FIFO is not empty after waiting, some data may not have been read!");
    $fatal("Test failed due to unread data in FIFO.");
  end else if (sent_count != TEST_NUM) begin
    $display("Error: Expected to send %0d items, but only sent %0d items!", TEST_NUM, sent_count);
    $fatal("Test failed due to incorrect number of items sent.");
  end else if (rcvd_count != TEST_NUM) begin
    $display("Error: Expected to read %0d items, but only read %0d items!", TEST_NUM, rcvd_count);
    $fatal("Test failed due to incorrect number of items read.");
  end else begin
    $display("Test completed successfully!");
  end
  $finish();
end

task automatic send_data(input logic [DATAWIDTH-1:0] data_in);
  wait(!full);
  wrreq = 1'b1;
  data = data_in;
  @(posedge wclk);
  #1;
  wrreq = 1'b0;
endtask

initial begin
  wait(wrst_n);
  #1;

  for (int i=0; i<TEST_NUM; i=i+1) begin
    data_in = $urandom;
    send_data(data_in);
    sent_count = sent_count + 1;
    expected_data.push_back(data_in);
    $display("Sent data: 0x%08h", data_in);
  end
  send_done = 1;
end

initial begin
  wait(rrst_n);
  forever begin
    @(posedge rclk);
    #1;
    rdreq = 1'b0;
    wait(!empty);
    exp_data = expected_data.pop_front();
    rcvd_count = rcvd_count + 1;
    if (q != exp_data) begin
      $display("[%0d] Data mismatch: expected=0x%08h, actual=0x%08h", rcvd_count, exp_data, q);
      $fatal("Data mismatch detected!");
    end else begin
      $display("[%0d] Data match: expected=0x%08h, actual=0x%08h", rcvd_count, exp_data, q);
    end
    rdreq = 1'b1;
  end
end



endmodule
