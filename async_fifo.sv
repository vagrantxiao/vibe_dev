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

endmodule
