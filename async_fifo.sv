/*
async_fifo#(
      .DATAWIDTH (           )
    , .ADDRWIDTH (           )
)(
      .wclk      (           )
    , .wrst_n    (           )
    , .wrreq     (           )
    , .data      (           )
    , .full     (           )
    , .rclk      (           )
    , .rrst_n    (           )
    , .rdreq      (           )
    , .rdou      (           )
    , .empty    (           )
);
*/




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


logic [DATAWIDTH-1 : 0] mem [(1<<ADDRWIDTH)-1:0];
initial begin
    for(int i=0; i<(1<<ADDRWIDTH); i++) begin
        mem[i] = 0;
    end
end

logic [DATAWIDTH-1 : 0] mem_reg;

logic [ADDRWIDTH : 0] wwptr_bin;
logic [ADDRWIDTH : 0] wwptr_gray;
logic [ADDRWIDTH : 0] wrptr_gray;

logic [ADDRWIDTH : 0] rrptr_bin;
logic [ADDRWIDTH : 0] rrptr_gray;
logic [ADDRWIDTH : 0] rwptr_gray;


///////////////////////////////////////////////////////////////////////////////
// write clock domain

// write port
always_ff @ (posedge wclk) begin
    if( ~full && wrreq) begin
        mem[wwptr_bin[ADDRWIDTH-1:0]] <= data;
        mem_reg                       <= data;
    end
end

//wwptr_bin
always_ff @ (posedge wclk) begin
    if(!wrst_n) begin
        wwptr_bin <= 0;
    end else begin
        wwptr_bin <= ((~full) && wrreq) ? wwptr_bin+1 : wwptr_bin;
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

assign full = ({~wrptr_gray[ADDRWIDTH:ADDRWIDTH-1], wrptr_gray[ADDRWIDTH-2:0]} == wwptr_gray);


///////////////////////////////////////////////////////////////////////////////
// read clock domain

assign q = mem[rrptr_bin[ADDRWIDTH-1:0]];

//rrptr_bin
always_ff @ (posedge rclk) begin
    if(!rrst_n) begin
        rrptr_bin <= 0;
    end else begin
        rrptr_bin <= ((~empty) && rdreq) ? rrptr_bin+1 : rrptr_bin;
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

assign empty = (rwptr_gray == rrptr_gray);


endmodule


        

