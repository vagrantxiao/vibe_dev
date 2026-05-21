/*
asynchronizer#(
      .DATAWIDTH(8)
    )(
      .dclk() 
    , .drst_n()
    , .ddout()
    , .sdin()
);
*/

module asynchronizer#(
      parameter DATAWIDTH = 8
    )(
      input                  dclk 
    , input                  drst_n
    , input [DATAWIDTH-1:0]  sdin
    , output [DATAWIDTH-1:0] ddout
);

logic [DATAWIDTH-1:0] ddin;

ydff #(
      .DATAWIDTH (DATAWIDTH)
)ydff1(
      .dout      (ddin     )
    , .clk       (dclk     )
    , .rst_n     (drst_n   )
    , .din       (sdin     )
    , .en        (1'b1     )
);

ydff #(
      .DATAWIDTH (DATAWIDTH)
)ydff2(
      .dout      (ddout    )
    , .clk       (dclk     )
    , .rst_n     (drst_n   )
    , .din       (ddin     )
    , .en        (1'b1     )
);


endmodule

