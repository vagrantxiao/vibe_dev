/*
async_fifo#(
      .DATAWIDTH (           )
    , .ADDRWIDTH (           )
)(
      .wclk      (           )
    , .wrst_n    (           )
    , .wpush     (           )
    , .wdin      (           )
    , .wfull     (           )
    , .rclk      (           )
    , .rrst_n    (           )
    , .rpop      (           )
    , .rdou      (           )
    , .rempty    (           )
);
*/




module async_fifo#(
      parameter DATAWIDTH = 8
    , parameter ADDRWIDTH = 4
    )(
      input                  wclk
    , input                  wrst_n
    , input                  wpush
    , input [DATAWIDTH-1:0]  wdin
    , output                 wfull

    , input                  rclk
    , input                  rrst_n
    , input                  rpop
    , output [DATAWIDTH-1:0] rdout
    , output                 rempty
);


logic [DATAWIDTH-1 : 0] mem [(1<<ADDRWIDTH)-1:0];

logic [ADDRWIDTH : 0] wwptr_bin;
logic [ADDRWIDTH : 0] wwptr_gray;
logic [ADDRWIDTH : 0] wrptr_gray;

logic [ADDRWIDTH : 0] rrptr_bin;
logic [ADDRWIDTH : 0] rrptr_gray;
logic [ADDRWIDTH : 0] rwptr_gray;


///////////////////////////////////////////////////////////////////////////////
// write clock domain

integer ii;
// write port
always_ff @ (posedge wclk) begin
    if(!wrst_n) begin
        for(ii=0; ii<(1<<ADDRWIDTH); ii = ii+1) begin
            mem[ii] <= 0;
        end
    end else begin
        if( ~wfull && wpush) begin
            mem[wwptr_bin[ADDRWIDTH-1:0]] <= wdin;
        end
    end
end

//wwptr_bin
always_ff @ (posedge wclk) begin
    if(!wrst_n) begin
        wwptr_bin <= 0;
    end else begin
        wwptr_bin <= ((~wfull) && wpush) ? wwptr_bin+1 : wwptr_bin;
    end
end

assign wwptr_gray = (wwptr_bin>>1) ^ wwptr_bin;

asynchronizer#(
      .DATAWIDTH (ADDRWIDTH+1)
)sync_r2w(
      .dclk      (wclk       )
    , .drst_n    (wrst_n     )
    , .ddout     (wrptr_gray )
    , .sdin      (rrptr_gray )
);

assign wfull = ({~wrptr_gray[ADDRWIDTH:ADDRWIDTH-1], wrptr_gray[ADDRWIDTH-2:0]} == wwptr_gray);


///////////////////////////////////////////////////////////////////////////////
// read clock domain

assign rdout = mem[rrptr_bin[ADDRWIDTH-1:0]];

//rrptr_bin
always_ff @ (posedge rclk) begin
    if(!rrst_n) begin
        rrptr_bin <= 0;
    end else begin
        rrptr_bin <= ((~rempty) && rpop) ? rrptr_bin+1 : rrptr_bin;
    end
end

assign rrptr_gray = (rrptr_bin>>1) ^ rrptr_bin;

asynchronizer#(
      .DATAWIDTH (ADDRWIDTH+1)
)sync_w2r(
      .dclk      (rclk       )
    , .drst_n    (rrst_n     )
    , .ddout     (rwptr_gray )
    , .sdin      (wwptr_gray )
);

assign rempty = (rwptr_gray == rrptr_gray);


endmodule


        

