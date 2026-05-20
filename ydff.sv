`timescale 1ns / 1ps
/* instance 
ydff #(
      .DATA_WIDTH ()
)(
      .dout      ()
    , .clk       (clk)
    , .rst_n     (rst_n)
    , .din       ()
    , .en        ()
);
*/

module ydff #(
      parameter DATAWIDTH = 8
    , parameter INIT      = 0
)(
      output reg   [DATAWIDTH-1:0] dout
    , input  wire                  clk 
    , input  wire                  rst_n
    , input  wire  [DATAWIDTH-1:0] din
    , input  wire                  en
);

always@(posedge clk)begin
    if(~rst_n) begin
        dout <= INIT;
    end else begin
        dout <= (en ? din : dout);
    end
end


endmodule

