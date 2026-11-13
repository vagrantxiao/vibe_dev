module axi4_w
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
    input  wire                                ACLK,
    input  wire                                ARESET,
    input  wire                                ACLK_EN,

    // write data channel
    output logic [C_M_AXI_ID_WIDTH-1:0]        WID,
    output logic [C_M_AXI_DATA_WIDTH-1:0]      WDATA,
    output logic [C_M_AXI_DATA_WIDTH/8-1:0]    WSTRB,
    output logic                               WLAST,
    output logic [C_M_AXI_WUSER_WIDTH-1:0]     WUSER,
    output logic                               WVALID,
    input  wire                                WREADY,

    // write data
    input  wire [USER_DW-1:0]                  I_WDATA,
    input  wire [USER_DW/8-1:0]                I_WSTRB,
    input  wire                                I_WVALID,
    output logic                               I_WREADY,

    // write response channel
    input  wire [C_M_AXI_ID_WIDTH-1:0]         BID,
    input  wire [1:0]                          BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0]      BUSER,
    input  wire                                BVALID,
    output logic                               BREADY,

    // write response
    output logic                               I_BVALID,
    input  wire                                I_BREADY,

    output logic                               meta_ready_out,
    input  wire [31:0]                         meta_len_in,
    input  wire                                meta_valid_in
);

localparam ADDR_LSB_1KB = 10;
localparam ADDR_LSB_64B = 6;
localparam BYTE_NUM_1KB = (1 << ADDR_LSB_1KB);
localparam WORD_NUM_1KB = 1 << (ADDR_LSB_1KB - ADDR_LSB_64B);
localparam AXI_LEN_1KB  = WORD_NUM_1KB - 1;

typedef enum logic [2:0] {
    IDLE,
    DATA,
    RECV_B,
    SEND_B,
    ERR
} state_t;

typedef struct packed {
    state_t              state;
    logic  [31:0]        left_words; // Unit is Word (x64Bytes)
    logic  [31:0]        words_cnt;  // Unit is Word (x64Bytes)
} st_t;

st_t st_nxt, st_ff;

always_comb begin
    // sequential state
    st_nxt = st_ff;
    
    // important control signals
    meta_ready_out = 1'b0;
    I_WREADY       = 1'b0;
    WVALID         = 1'b0;
    WLAST          = 1'b0;
    BREADY         = 1'b0;
    I_BVALID       = 1'b0;

    // Data path
    WSTRB          = I_WSTRB;
    WID            = '0;
    WDATA          = I_WDATA;
    WUSER          = '0;

    case(st_ff.state)
        IDLE: begin
            meta_ready_out = 1'b1;
            if (meta_valid_in) begin
                st_nxt.state      = DATA;
                st_nxt.left_words = meta_len_in;
                st_nxt.words_cnt  = '0;
            end
        end

        DATA: begin
            I_WREADY = WREADY;
            WVALID   = I_WVALID;
            if (I_WVALID && I_WREADY) begin
                if (st_ff.left_words == 1) begin
                    st_nxt.state      = RECV_B;
                    WLAST             = 1'b1;
                    st_nxt.left_words = '0;
                    st_nxt.words_cnt  = '0;
                end else begin
                    st_nxt.left_words = st_ff.left_words - 1;
                    st_nxt.words_cnt  = st_ff.words_cnt + 1;
                    WLAST             = (st_ff.words_cnt[ADDR_LSB_1KB - ADDR_LSB_64B -1 : 0] == AXI_LEN_1KB);
                    if (WLAST) st_nxt.state = RECV_B;
                end
            end
        end

        RECV_B: begin
            BREADY = 1'b1;
            if (BVALID) begin
                if (st_ff.left_words == 0) begin
                    st_nxt.state = SEND_B;
                end else begin
                    st_nxt.state = DATA;
                end
            end
        end

        SEND_B: begin
            I_BVALID = 1'b1;
            if (I_BREADY) begin
                st_nxt.state = IDLE;
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
        word_cnt_dbg_ff <= ((I_WVALID && I_WREADY) ? (word_cnt_dbg_ff + 1) : word_cnt_dbg_ff);
    end
end
// synthesis translate_on
//======================================












endmodule