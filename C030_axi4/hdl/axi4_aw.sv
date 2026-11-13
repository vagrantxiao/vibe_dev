module axi4_aw
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
    // write address channel
    output logic [C_M_AXI_ID_WIDTH-1:0]        AWID,
    output logic [C_M_AXI_ADDR_WIDTH-1:0]      AWADDR,
    output logic [7:0]                         AWLEN,
    output logic [2:0]                         AWSIZE,
    output logic [1:0]                         AWBURST,
    output logic [1:0]                         AWLOCK,
    output logic [3:0]                         AWCACHE,
    output logic [2:0]                         AWPROT,
    output logic [3:0]                         AWQOS,
    output logic [3:0]                         AWREGION,
    output logic [C_M_AXI_AWUSER_WIDTH-1:0]    AWUSER,
    output logic                               AWVALID,
    input  wire                                AWREADY,

    // internal bus ports
    // write address
    input  wire  [USER_AW-1:0]                 I_AWADDR,
    input  wire  [31:0]                        I_AWLEN,
    input  wire                                I_AWVALID,
    output logic                               I_AWREADY,

    input  wire                                wrQ_ready,
    output logic [31:0]                        wrQ_len,
    output logic                               wrQ_valid
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
    last_packet_addr_net = '0;
    across_boundary_net  = 1'b0;
    I_AWREADY            = 1'b0;
    AWVALID              = '0;
    wrQ_valid            = 1'b0;

    // datapath
    AWID     = '0;
    AWADDR   = st_ff.addr;
    AWLEN    = AXI_LEN_1KB;
    AWSIZE   =  6;
    AWBURST  =  1;
    AWLOCK   = '0;
    AWCACHE  = C_CACHE_VALUE;
    AWPROT   = C_PROT_VALUE;
    AWQOS    = '0;
    AWREGION = '0;
    AWUSER   = C_USER_VALUE;

    wrQ_len  = I_AWLEN;
    

    case(st_ff.state)
        IDLE: begin
            I_AWREADY = wrQ_ready;
            wrQ_valid = I_AWVALID;
            if (I_AWVALID && I_AWREADY) begin
                st_nxt.state         = ADDR;
                st_nxt.left_words    = I_AWLEN;
                st_nxt.addr          = I_AWADDR << ADDR_LSB_64B;
            end
        end

        ADDR: begin
            AWVALID  = 1'b1;
            last_packet_addr_net = (st_ff.left_words << ADDR_LSB_64B) + st_ff.addr - 1;
            across_boundary_net = (last_packet_addr_net[USER_AW-1:ADDR_LSB_1KB] != st_ff.addr[USER_AW-1:ADDR_LSB_1KB]);
            
            if (AWREADY) begin
                if (across_boundary_net) begin
                    st_nxt.addr       = st_ff.addr + BYTE_NUM_1KB;
                    st_nxt.left_words = st_ff.left_words - WORD_NUM_1KB;
                    // debug_flag_nxt    = YES;
                end else begin
                    AWLEN             = st_ff.left_words - 1; // This is not right.
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