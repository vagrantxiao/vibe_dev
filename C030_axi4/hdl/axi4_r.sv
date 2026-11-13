
module axi4_r
#(parameter
    CONSERVATIVE            = 0,
    NUM_READ_OUTSTANDING    = 2,
    NUM_WRITE_OUTSTANDING   = 2,
    MAX_READ_BURST_LENGTH   = 16,
    MAX_WRITE_BURST_LENGTH  = 16,
    C_M_AXI_ID_WIDTH        = 1,
    C_M_AXI_ADDR_WIDTH      = 32,
    C_M_AXI_DATA_WIDTH      = 32, // power of 2 & range: 2 to 1024
    C_M_AXI_AWUSER_WIDTH    = 1,
    C_M_AXI_ARUSER_WIDTH    = 1,
    C_M_AXI_WUSER_WIDTH     = 1,
    C_M_AXI_RUSER_WIDTH     = 1,
    C_M_AXI_BUSER_WIDTH     = 1,
    C_TARGET_ADDR           = 32'h00000000,
    C_USER_VALUE            = 1'b0,
    C_PROT_VALUE            = 3'b000,
    C_CACHE_VALUE           = 4'b0011,
    USER_DW                 = 32, // multiple of 8
    USER_AW                 = 32,
    USER_MAXREQS            = 16,
    USER_RFIFONUM_WIDTH     = 6,
    MAXI_BUFFER_IMPL        = "block"
)(
    // system signal
    input  wire                               ACLK,
    input  wire                               ARESET,
    input  wire                               ACLK_EN,

    input  wire [C_M_AXI_ID_WIDTH-1:0]        RID,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]      RDATA,
    input  wire [1:0]                         RRESP,
    input  wire                               RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0]     RUSER,
    input  wire                               RVALID,
    output logic                              RREADY,

    output logic [USER_DW-1:0]                I_RDATA,
    output logic                              I_RVALID,
    input  wire                               I_RREADY,

    output logic                              meta_ready_out,
    input  wire [31:0]                        meta_len_in,
    input  wire                               meta_valid_in
);

typedef enum logic [1:0] {
    IDLE,
    DATA, 
    ERR
} state_t;

typedef struct packed {
    state_t              state;
    logic  [31:0]        left_words; // Unit is Word (x64Bytes)
} st_t;

st_t st_nxt, st_ff;

always_comb begin
    // sequential state
    st_nxt = st_ff;
    
    // important control signals
    meta_ready_out = 1'b0;
    RREADY = 1'b0;
    I_RVALID = 1'b0;

    // Data path
    I_RDATA  = RDATA;

    case(st_ff.state)
        IDLE: begin
            meta_ready_out = 1'b1;
            if (meta_valid_in) begin
                st_nxt.state      = DATA;
                st_nxt.left_words = meta_len_in;
            end
        end

        DATA: begin
            RREADY   = I_RREADY;
            I_RVALID = RVALID;
            if (I_RVALID && I_RREADY) begin
                if (st_ff.left_words == 1) begin
                    st_nxt.state      = IDLE;
                    st_nxt.left_words = '0;
                end else begin
                    st_nxt.left_words = st_ff.left_words - 1;
                end
            end
        end

        ERR: begin
            // trap in this state until reset
        end

    endcase
end

always_ff @(posedge ACLK) begin
    if (ARESET) begin
        st_ff <= '0;
    end else begin
        st_ff <= st_nxt;
    end
end

//======================================
// For debug only
// synthesis translate_off
logic [31:0] word_cnt_dbg_ff;
always_ff @(posedge ACLK) begin
    if (ARESET) begin
        word_cnt_dbg_ff <= '0;
    end else begin
        word_cnt_dbg_ff <= ((I_RVALID && I_RREADY) ? (word_cnt_dbg_ff + 1) : word_cnt_dbg_ff);
    end
end
// synthesis translate_on
//======================================


endmodule