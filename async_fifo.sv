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

endmodule
