
module axi4_ar
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

    input  wire [USER_AW-1:0]                 I_ARADDR,
    input  wire [31:0]                        I_ARLEN,
    input  wire                               I_ARVALID,
    output logic                              I_ARREADY,

    output logic [C_M_AXI_ID_WIDTH-1:0]        ARID,
    output logic [C_M_AXI_ADDR_WIDTH-1:0]      ARADDR,
    output logic [7:0]                         ARLEN,
    output logic [2:0]                         ARSIZE,
    output logic [1:0]                         ARBURST,
    output logic [1:0]                         ARLOCK,
    output logic [3:0]                         ARCACHE,
    output logic [2:0]                         ARPROT,
    output logic [3:0]                         ARQOS,
    output logic [3:0]                         ARREGION,
    output logic [C_M_AXI_ARUSER_WIDTH-1:0]    ARUSER,
    output logic                               ARVALID,
    input  wire                                ARREADY,

    input  wire                                cplQ_ready,
    output logic [31:0]                        cplQ_len,
    output logic                               cplQ_valid
);

typedef enum logic [1:0] {
    IDLE,
    ADDR
} state_t;

typedef struct packed {
    state_t              state;
    logic  [31:0]        left_words; // Unit is Word (x64Bytes)
    logic  [USER_AW-1:0] addr;
} st_t;

st_t st_nxt, st_ff;

logic [USER_AW-1:0] last_packet_addr_net;
logic               across_boundary_net;

localparam ADDR_LSB_1KB = 10;
localparam ADDR_LSB_64B = 6;
localparam BYTE_NUM_1KB = (1 << ADDR_LSB_1KB);
localparam WORD_NUM_1KB = 1 << (ADDR_LSB_1KB - ADDR_LSB_64B);
localparam AXI_LEN_1KB  = WORD_NUM_1KB - 1;


//======================================
// For debug only
// synthesis translate_off
enum logic [1:0] {
    NOT_SET,
    YES,
    NO
} debug_flag_nxt, debug_flag_ff;

always_ff @(posedge ACLK) begin
    if (ARESET) begin
        debug_flag_ff <= NOT_SET;
    end else begin
        debug_flag_ff <= debug_flag_nxt;
    end
end

// synthesis translate_on
//======================================


always_comb begin
    // sequential state
    st_nxt         = st_ff;
    // debug_flag_nxt = debug_flag_ff;


    // important control signals
    cplQ_valid           = 1'b0;
    last_packet_addr_net = '0;
    across_boundary_net  = 1'b0;
    I_ARREADY            = 1'b0;
    ARVALID              = '0;

    // datapath
    ARID     = '0;
    ARADDR   = st_ff.addr;
    ARLEN    = AXI_LEN_1KB;
    ARSIZE   = 6;
    ARBURST  = 1;
    ARLOCK   = '0;
    ARCACHE  = C_CACHE_VALUE;
    ARPROT   = C_PROT_VALUE;
    ARQOS    = '0;
    ARREGION = '0;
    ARUSER   = C_USER_VALUE;

    cplQ_len = I_ARLEN;
    

    case(st_ff.state)
        IDLE: begin
            I_ARREADY  = cplQ_ready;
            cplQ_valid = I_ARVALID;
            if (I_ARVALID && I_ARREADY) begin
                st_nxt.state         = ADDR;
                st_nxt.left_words    = I_ARLEN;
                st_nxt.addr          = I_ARADDR << ADDR_LSB_64B;
            end
        end

        ADDR: begin
            ARVALID  = 1'b1;
            last_packet_addr_net = (st_ff.left_words << ADDR_LSB_64B) + st_ff.addr - 1;
            across_boundary_net = (last_packet_addr_net[USER_AW-1:ADDR_LSB_1KB] != st_ff.addr[USER_AW-1:ADDR_LSB_1KB]);
            
            if (ARREADY) begin
                if (across_boundary_net) begin
                    st_nxt.addr       = st_ff.addr + BYTE_NUM_1KB;
                    st_nxt.left_words = st_ff.left_words - WORD_NUM_1KB;
                    // debug_flag_nxt    = YES;
                end else begin
                    ARLEN             = st_ff.left_words - 1; // This is not right.
                    st_nxt.state      = IDLE;
                    st_nxt.left_words = '0;
                    // debug_flag_nxt    = NO;
                end
            end
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

endmodule