module tb_top();

localparam DATAWIDTH = 32;
localparam ADDRWIDTH = 10;
localparam TEST_NUM = 1000;

reg wclk = 0;
reg rclk = 0;
reg wrst_n = 0;
reg rrst_n = 0;
reg wpush = 0;
reg rpop  = 0;
reg [DATAWIDTH-1:0] wdin = 0;


wire wfull, rempty;
wire [DATAWIDTH-1:0] rdout;


async_fifo#(
      .DATAWIDTH (DATAWIDTH  )
    , .ADDRWIDTH (ADDRWIDTH  )
)dut(
      .wclk      (wclk       )
    , .wrst_n    (wrst_n     )
    , .wpush     (wpush      )
    , .wdin      (wdin       )
    , .wfull     (wfull      )
    , .rclk      (rclk       )
    , .rrst_n    (rrst_n     )
    , .rpop      (rpop       )
    , .rdout     (rdout      )
    , .rempty    (rempty     )
);


always #3 wclk = ~wclk;
always #5 rclk = ~rclk;

task automatic send_data(logic [DATAWIDTH-1:0] din) begin
  wait(!wfull);
  wdin = din;
  wpush = 1'b1;
  @(posedge wclk);
  wpush = 1'b0;
endtask


initial begin
  #100;
  @(posedge wclk);
  wrst_n = 1;
  $display("wr side is reset");

  @(posedge rclk);
  rrst_n = 1;
  $display("rd side is reste");

  #100
  @(posedge wclk);
  for (int i=0; i<TEST_NUM; i=i+1) begin
    send_data(i);
  end
  #100
  $finish();
end








endmodule
