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

    // -----------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------
    localparam DEPTH = 1 << ADDRWIDTH;
    localparam PTR_W = ADDRWIDTH + 1;       // extra bit for full/empty

    logic [PTR_W-1:0] wptr_gray;            // write Gray pointer (wclk domain)
    logic [PTR_W-1:0] rptr_gray;            // read  Gray pointer (rclk domain)
    logic [PTR_W-1:0] wptr_gray_sync;       // write Gray pointer synced to rclk
    logic [PTR_W-1:0] rptr_gray_sync;       // read  Gray pointer synced to wclk
    logic [ADDRWIDTH-1:0] waddr;            // write address into RAM
    logic [ADDRWIDTH-1:0] raddr;            // read  address into RAM

    // -----------------------------------------------------------
    // 1. Dual-port RAM (fifo_mem)
    //    - Synchronous write on wclk
    //    - Asynchronous (combinational) read
    // -----------------------------------------------------------
    logic [DATAWIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge wclk) begin
        if (wrreq && !full)
            mem[waddr] <= data;
    end

    assign q = mem[raddr];

    // -----------------------------------------------------------
    // 2. Write pointer & full logic (wptr_full)
    // -----------------------------------------------------------
    logic [PTR_W-1:0] wbin, wbin_next;
    logic [PTR_W-1:0] wgray_next;
    logic              full_next;

    // next binary & Gray values
    assign wbin_next  = wbin + (wrreq & ~full);
    assign wgray_next = wbin_next ^ (wbin_next >> 1);

    // full when next write Gray == {~top2, rest} of synced read Gray
    assign full_next = (wgray_next == {~rptr_gray_sync[PTR_W-1:PTR_W-2],
                                        rptr_gray_sync[PTR_W-3:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin      <= '0;
            wptr_gray <= '0;
            full      <= 1'b0;
        end else begin
            wbin      <= wbin_next;
            wptr_gray <= wgray_next;
            full      <= full_next;
        end
    end

    assign waddr = wbin[ADDRWIDTH-1:0];

    // -----------------------------------------------------------
    // 3. Read pointer & empty logic (rptr_empty)
    // -----------------------------------------------------------
    logic [PTR_W-1:0] rbin, rbin_next;
    logic [PTR_W-1:0] rgray_next;
    logic              empty_next;

    // next binary & Gray values
    assign rbin_next  = rbin + (rdreq & ~empty);
    assign rgray_next = rbin_next ^ (rbin_next >> 1);

    // empty when next read Gray == synced write Gray
    assign empty_next = (rgray_next == wptr_gray_sync);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin      <= '0;
            rptr_gray <= '0;
            empty     <= 1'b1;         // FIFO starts empty
        end else begin
            rbin      <= rbin_next;
            rptr_gray <= rgray_next;
            empty     <= empty_next;
        end
    end

    assign raddr = rbin[ADDRWIDTH-1:0];

    // -----------------------------------------------------------
    // 4. Synchronizer: rptr_gray -> wclk domain (sync_r2w)
    // -----------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] rptr_gray_meta;
    (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] rptr_gray_sync_r;

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            rptr_gray_meta   <= '0;
            rptr_gray_sync_r <= '0;
        end else begin
            rptr_gray_meta   <= rptr_gray;
            rptr_gray_sync_r <= rptr_gray_meta;
        end
    end

    assign rptr_gray_sync = rptr_gray_sync_r;

    // -----------------------------------------------------------
    // 5. Synchronizer: wptr_gray -> rclk domain (sync_w2r)
    // -----------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] wptr_gray_meta;
    (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] wptr_gray_sync_r;

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            wptr_gray_meta   <= '0;
            wptr_gray_sync_r <= '0;
        end else begin
            wptr_gray_meta   <= wptr_gray;
            wptr_gray_sync_r <= wptr_gray_meta;
        end
    end

    assign wptr_gray_sync = wptr_gray_sync_r;

endmodule
