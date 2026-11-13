
module skid_buffer
#(
      parameter DATA_WIDTH = 32
)(
      input  wire                  clk
    , input  wire                  reset

    , input  wire [DATA_WIDTH-1:0] din_data
    , input  wire                  din_valid
    , output wire                  din_ready
    
    , output wire [DATA_WIDTH-1:0] dout_data
    , output wire                  dout_valid
    , input  wire                  dout_ready
);

typedef enum logic [1:0] {
    EMPTY, // no data, no more pull
    HALF,   // 1 token, can push and pull
    FULL   // 2 totans, no more push
} state_t;

typedef struct packed {
    logic [DATA_WIDTH-1:0] main_data;
    logic [DATA_WIDTH-1:0] aux_data;
    logic                  valid;
    logic                  ready;
    state_t                state;
} st_t;

st_t st_nxt, st_ff;

logic push_hs_net; // push new data handshake
logic pull_hs_net; // pull new data handshake

assign push_hs_net = din_ready && din_valid;
assign pull_hs_net = dout_ready && dout_valid;

always_comb begin
    st_nxt = st_ff;
    st_nxt.valid = 0;
    st_nxt.ready = 0;

    case (st_ff.state)
        EMPTY: begin
            st_nxt.main_data = din_data;
            // aux dont care
            if (push_hs_net) begin
                st_nxt.valid = 1'b1;
                st_nxt.state = HALF;
            end
            st_nxt.ready = 1'b1;
        end

        HALF: begin
            if (push_hs_net && pull_hs_net) begin
                st_nxt.main_data = din_data;
                // aux dont care
                st_nxt.valid = 1'b1;
                st_nxt.ready = 1'b1;
            end else if (!push_hs_net && !pull_hs_net) begin
                // main data keep
                // aux data dont care
                st_nxt.valid = 1'b1;
                st_nxt.ready = 1'b1;
            end else if (push_hs_net && (!pull_hs_net)) begin
                // main data keep
                st_nxt.aux_data = din_data;
                st_nxt.ready = 1'b0;
                st_nxt.valid = 1'b1;
                st_nxt.state = FULL;
            end else begin // !push_hs_net && pull_hs_net
                // main data dont care
                // aux data dont care
                st_nxt.ready = 1'b1;
                st_nxt.valid = 1'b0;
                st_nxt.state = EMPTY;
            end
        end

        FULL: begin
            st_nxt.valid = 1'b1;
            if (pull_hs_net) begin
                st_nxt.main_data = st_ff.aux_data;
                // aux dont care
                st_nxt.valid = 1'b1;
                st_nxt.ready = 1'b1;
                st_nxt.state = HALF;
            end else begin
                // main data keep
                // aux data keep
                st_nxt.valid = 1'b1;
                st_nxt.ready = 1'b0;
            end
        end

        default begin
        end
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        st_ff       <= '0;
        st_ff.ready <= 1'b1;
    end else begin
        st_ff <= st_nxt;
    end
end

// output assignment
assign dout_data  = st_ff.main_data;
assign dout_valid = st_ff.valid;
assign din_ready  = st_ff.ready;



endmodule