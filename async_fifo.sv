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



endmodule
        

