// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2022.1 (64-bit)
// Version: 2022.1
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// ==============================================================
// 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689

`timescale 1ns/1ps
`default_nettype none

module datamover_m1_m_axi
#(parameter
    CONSERVATIVE            = 0,
    NUM_READ_OUTSTANDING    = 2,
    NUM_WRITE_OUTSTANDING   = 2,
    MAX_READ_BURST_LENGTH   = 16,
    MAX_WRITE_BURST_LENGTH  = 16,
    C_M_AXI_ID_WIDTH        = 1,
    C_M_AXI_ADDR_WIDTH      = 32,
    C_M_AXI_DATA_WIDTH      = 512, // power of 2 & range: 2 to 1024
    C_M_AXI_AWUSER_WIDTH    = 1,
    C_M_AXI_ARUSER_WIDTH    = 1,
    C_M_AXI_WUSER_WIDTH     = 1,
    C_M_AXI_RUSER_WIDTH     = 1,
    C_M_AXI_BUSER_WIDTH     = 1,
    C_TARGET_ADDR           = 32'h00000000,
    C_USER_VALUE            = 1'b0,
    C_PROT_VALUE            = 3'b000,
    C_CACHE_VALUE           = 4'b0011,
    USER_DW                 = 512, // multiple of 8
    USER_AW                 = 32,
    USER_MAXREQS            = 16,
    USER_RFIFONUM_WIDTH     = 6,
    MAXI_BUFFER_IMPL        = "block"
)(
    
    // system signal
    input  wire                               ACLK,
    input  wire                               ARESET,
    input  wire                               ACLK_EN,
    // write address channel
    output wire [C_M_AXI_ID_WIDTH-1:0]        m_axi_m1_AWID,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]      m_axi_m1_AWADDR,
    output wire [7:0]                         m_axi_m1_AWLEN,
    output wire [2:0]                         m_axi_m1_AWSIZE,
    output wire [1:0]                         m_axi_m1_AWBURST,
    output wire [1:0]                         m_axi_m1_AWLOCK,
    output wire [3:0]                         m_axi_m1_AWCACHE,
    output wire [2:0]                         m_axi_m1_AWPROT,
    output wire [3:0]                         m_axi_m1_AWQOS,
    output wire [3:0]                         m_axi_m1_AWREGION,
    output wire [C_M_AXI_AWUSER_WIDTH-1:0]    m_axi_m1_AWUSER,
    output wire                               m_axi_m1_AWVALID,
    input  wire                               m_axi_m1_AWREADY,
    // write data channel
    output wire [C_M_AXI_ID_WIDTH-1:0]        m_axi_m1_WID,
    output wire [C_M_AXI_DATA_WIDTH-1:0]      m_axi_m1_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0]    m_axi_m1_WSTRB,
    output wire                               m_axi_m1_WLAST,
    output wire [C_M_AXI_WUSER_WIDTH-1:0]     m_axi_m1_WUSER,
    output wire                               m_axi_m1_WVALID,
    input  wire                               m_axi_m1_WREADY,
    // write response channel
    input  wire [C_M_AXI_ID_WIDTH-1:0]        m_axi_m1_BID,
    input  wire [1:0]                         m_axi_m1_BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0]     m_axi_m1_BUSER,
    input  wire                               m_axi_m1_BVALID,
    output wire                               m_axi_m1_BREADY,
    // read address channel
    output wire [C_M_AXI_ID_WIDTH-1:0]        m_axi_m1_ARID,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]      m_axi_m1_ARADDR,
    output wire [7:0]                         m_axi_m1_ARLEN,
    output wire [2:0]                         m_axi_m1_ARSIZE,
    output wire [1:0]                         m_axi_m1_ARBURST,
    output wire [1:0]                         m_axi_m1_ARLOCK,
    output wire [3:0]                         m_axi_m1_ARCACHE,
    output wire [2:0]                         m_axi_m1_ARPROT,
    output wire [3:0]                         m_axi_m1_ARQOS,
    output wire [3:0]                         m_axi_m1_ARREGION,
    output wire [C_M_AXI_ARUSER_WIDTH-1:0]    m_axi_m1_ARUSER,
    output wire                               m_axi_m1_ARVALID,
    input  wire                               m_axi_m1_ARREADY,
    // read data channel
    input  wire [C_M_AXI_ID_WIDTH-1:0]        m_axi_m1_RID,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]      m_axi_m1_RDATA,
    input  wire [1:0]                         m_axi_m1_RRESP,
    input  wire                               m_axi_m1_RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0]     m_axi_m1_RUSER,
    input  wire                               m_axi_m1_RVALID,
    output wire                               m_axi_m1_RREADY,

    // internal bus ports
    // write address
    input  wire [USER_AW-1:0]                 wr_addr,
    input  wire [31:0]                        wr_addr_len,
    input  wire                               wr_addr_valid,
    output wire                               wr_addr_ready,
    // write data
    input  wire [USER_DW-1:0]                 wr_data,
    input  wire [USER_DW/8-1:0]               wr_data_be,
    input  wire                               wr_data_valid,
    output wire                               wr_data_ready,
    // write response
    output wire                               wr_resp_valid,
    input  wire                               wr_resp_ready,
    // read address
    input  wire [USER_AW-1:0]                 rd_addr,
    input  wire [31:0]                        rd_addr_len,
    input  wire                               rd_addr_valid,
    output wire                               rd_addr_ready,
    // read data
    output wire [USER_DW-1:0]                 rd_data,
    output wire                               rd_data_valid,
    input  wire                               rd_data_ready,
    output wire [USER_RFIFONUM_WIDTH-1:0]     I_RFIFONUM);
//------------------------Local signal-------------------
assign I_RFIFONUM  = 2;

logic [31:0] cplQ_len;
logic        cplQ_valid;
logic        cplQ_ready;

logic [31:0] rd_meta_len;
logic        rd_meta_valid;
logic        rd_meta_ready;

logic [31:0] wrQ_len;
logic        wrQ_valid;
logic        wrQ_ready;

logic [31:0] wr_meta_len;
logic        wr_meta_valid;
logic        wr_meta_ready;


axi4_ar
#(  
    .CONSERVATIVE            (CONSERVATIVE),
    .NUM_READ_OUTSTANDING    (NUM_READ_OUTSTANDING),
    .NUM_WRITE_OUTSTANDING   (NUM_WRITE_OUTSTANDING),
    .MAX_READ_BURST_LENGTH   (MAX_READ_BURST_LENGTH),
    .MAX_WRITE_BURST_LENGTH  (MAX_WRITE_BURST_LENGTH),
    .C_M_AXI_ID_WIDTH        (C_M_AXI_ID_WIDTH),
    .C_M_AXI_ADDR_WIDTH      (C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH      (C_M_AXI_DATA_WIDTH), // power of 2 & range: 2 to 1024
    .C_M_AXI_AWUSER_WIDTH    (C_M_AXI_AWUSER_WIDTH),
    .C_M_AXI_ARUSER_WIDTH    (C_M_AXI_ARUSER_WIDTH),
    .C_M_AXI_WUSER_WIDTH     (C_M_AXI_WUSER_WIDTH),
    .C_M_AXI_RUSER_WIDTH     (C_M_AXI_RUSER_WIDTH),
    .C_M_AXI_BUSER_WIDTH     (C_M_AXI_BUSER_WIDTH),
    .C_TARGET_ADDR           (C_TARGET_ADDR),
    .C_USER_VALUE            (C_USER_VALUE),
    .C_PROT_VALUE            (C_PROT_VALUE),
    .C_CACHE_VALUE           (C_CACHE_VALUE),
    .USER_DW                 (USER_DW), // multiple of 8
    .USER_AW                 (USER_AW),
    .USER_MAXREQS            (USER_MAXREQS),
    .USER_RFIFONUM_WIDTH     (USER_RFIFONUM_WIDTH),
    .MAXI_BUFFER_IMPL        (MAXI_BUFFER_IMPL)
) u_axi4_ar (
    // system signal
    .ACLK                     (ACLK),
    .ARESET                   (ARESET),
    .ACLK_EN                  (ACLK_EN),

    .I_ARADDR                 (rd_addr),
    .I_ARLEN                  (rd_addr_len),
    .I_ARVALID                (rd_addr_valid),
    .I_ARREADY                (rd_addr_ready),

    .ARID                     (m_axi_m1_ARID),
    .ARADDR                   (m_axi_m1_ARADDR),
    .ARLEN                    (m_axi_m1_ARLEN),
    .ARSIZE                   (m_axi_m1_ARSIZE),
    .ARBURST                  (m_axi_m1_ARBURST),
    .ARLOCK                   (m_axi_m1_ARLOCK),
    .ARCACHE                  (m_axi_m1_ARCACHE),
    .ARPROT                   (m_axi_m1_ARPROT),
    .ARQOS                    (m_axi_m1_ARQOS),
    .ARREGION                 (m_axi_m1_ARREGION),
    .ARUSER                   (m_axi_m1_ARUSER),
    .ARVALID                  (m_axi_m1_ARVALID),
    .ARREADY                  (m_axi_m1_ARREADY),

    .cplQ_ready               (cplQ_ready),
    .cplQ_len                 (cplQ_len),
    .cplQ_valid               (cplQ_valid)
);

skid_buffer #(
    .DATA_WIDTH(32)
) u_cplQ (
    .clk                      (ACLK),
    .reset                    (ARESET),

    .din_data                 (cplQ_len),
    .din_valid                (cplQ_valid),
    .din_ready                (cplQ_ready),

    .dout_data                (rd_meta_len),
    .dout_valid               (rd_meta_valid),
    .dout_ready               (rd_meta_ready)
);

axi4_r
#(
    .CONSERVATIVE            (CONSERVATIVE),
    .NUM_READ_OUTSTANDING    (NUM_READ_OUTSTANDING),
    .NUM_WRITE_OUTSTANDING   (NUM_WRITE_OUTSTANDING),
    .MAX_READ_BURST_LENGTH   (MAX_READ_BURST_LENGTH),
    .MAX_WRITE_BURST_LENGTH  (MAX_WRITE_BURST_LENGTH),
    .C_M_AXI_ID_WIDTH        (C_M_AXI_ID_WIDTH),
    .C_M_AXI_ADDR_WIDTH      (C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH      (C_M_AXI_DATA_WIDTH), // power of 2 & range: 2 to 1024
    .C_M_AXI_AWUSER_WIDTH    (C_M_AXI_AWUSER_WIDTH),
    .C_M_AXI_ARUSER_WIDTH    (C_M_AXI_ARUSER_WIDTH),
    .C_M_AXI_WUSER_WIDTH     (C_M_AXI_WUSER_WIDTH),
    .C_M_AXI_RUSER_WIDTH     (C_M_AXI_RUSER_WIDTH),
    .C_M_AXI_BUSER_WIDTH     (C_M_AXI_BUSER_WIDTH),
    .C_TARGET_ADDR           (C_TARGET_ADDR),
    .C_USER_VALUE            (C_USER_VALUE),
    .C_PROT_VALUE            (C_PROT_VALUE),
    .C_CACHE_VALUE           (C_CACHE_VALUE),
    .USER_DW                 (USER_DW), // multiple of 8
    .USER_AW                 (USER_AW),
    .USER_MAXREQS            (USER_MAXREQS),
    .USER_RFIFONUM_WIDTH     (USER_RFIFONUM_WIDTH),
    .MAXI_BUFFER_IMPL        (MAXI_BUFFER_IMPL)
) u_axi4_r (
    // system signal
    .ACLK                    (ACLK),
    .ARESET                  (ARESET),
    .ACLK_EN                 (ACLK_EN),
    .RID                     (m_axi_m1_RID),
    .RDATA                   (m_axi_m1_RDATA),
    .RRESP                   (m_axi_m1_RRESP),
    .RLAST                   (m_axi_m1_RLAST),
    .RUSER                   (m_axi_m1_RUSER),
    .RVALID                  (m_axi_m1_RVALID),
    .RREADY                  (m_axi_m1_RREADY),

    .I_RDATA                 (rd_data),
    .I_RVALID                (rd_data_valid),
    .I_RREADY                (rd_data_ready),

    .meta_ready_out          (rd_meta_ready),
    .meta_len_in             (rd_meta_len),
    .meta_valid_in           (rd_meta_valid)
);

axi4_aw
#(
    .CONSERVATIVE            (CONSERVATIVE),
    .NUM_READ_OUTSTANDING    (NUM_READ_OUTSTANDING),
    .NUM_WRITE_OUTSTANDING   (NUM_WRITE_OUTSTANDING),
    .MAX_READ_BURST_LENGTH   (MAX_READ_BURST_LENGTH),
    .MAX_WRITE_BURST_LENGTH  (MAX_WRITE_BURST_LENGTH),
    .C_M_AXI_ID_WIDTH        (C_M_AXI_ID_WIDTH),
    .C_M_AXI_ADDR_WIDTH      (C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH      (C_M_AXI_DATA_WIDTH), // power of 2 & range: 2 to 1024
    .C_M_AXI_AWUSER_WIDTH    (C_M_AXI_AWUSER_WIDTH),
    .C_M_AXI_ARUSER_WIDTH    (C_M_AXI_ARUSER_WIDTH),
    .C_M_AXI_WUSER_WIDTH     (C_M_AXI_WUSER_WIDTH),
    .C_M_AXI_RUSER_WIDTH     (C_M_AXI_RUSER_WIDTH),
    .C_M_AXI_BUSER_WIDTH     (C_M_AXI_BUSER_WIDTH),
    .C_TARGET_ADDR           (C_TARGET_ADDR),
    .C_USER_VALUE            (C_USER_VALUE),
    .C_PROT_VALUE            (C_PROT_VALUE),
    .C_CACHE_VALUE           (C_CACHE_VALUE),
    .USER_DW                 (USER_DW), // multiple of 8
    .USER_AW                 (USER_AW),
    .USER_MAXREQS            (USER_MAXREQS),
    .USER_RFIFONUM_WIDTH     (USER_RFIFONUM_WIDTH),
    .MAXI_BUFFER_IMPL        (MAXI_BUFFER_IMPL)
) u_axi4_aw (
    // system signal
    .ACLK                    (ACLK),
    .ARESET                  (ARESET),
    .ACLK_EN                 (ACLK_EN),
    // write address channel
    .AWID                    (m_axi_m1_AWID),
    .AWADDR                  (m_axi_m1_AWADDR),
    .AWLEN                   (m_axi_m1_AWLEN),
    .AWSIZE                  (m_axi_m1_AWSIZE),
    .AWBURST                 (m_axi_m1_AWBURST),
    .AWLOCK                  (m_axi_m1_AWLOCK),
    .AWCACHE                 (m_axi_m1_AWCACHE),
    .AWPROT                  (m_axi_m1_AWPROT),
    .AWQOS                   (m_axi_m1_AWQOS),
    .AWREGION                (m_axi_m1_AWREGION),
    .AWUSER                  (m_axi_m1_AWUSER),
    .AWVALID                 (m_axi_m1_AWVALID),
    .AWREADY                 (m_axi_m1_AWREADY),
    // internal bus ports
    // write address
    .I_AWADDR                (wr_addr),
    .I_AWLEN                 (wr_addr_len),
    .I_AWVALID               (wr_addr_valid),
    .I_AWREADY               (wr_addr_ready),

    .wrQ_ready               (wrQ_ready),
    .wrQ_len                 (wrQ_len),
    .wrQ_valid               (wrQ_valid)
);

skid_buffer #(
    .DATA_WIDTH(32)
) u_wrQ (
    .clk                      (ACLK),
    .reset                    (ARESET),

    .din_data                 (wrQ_len),
    .din_valid                (wrQ_valid),
    .din_ready                (wrQ_ready),

    .dout_data                (wr_meta_len),
    .dout_valid               (wr_meta_valid),
    .dout_ready               (wr_meta_ready)
);


axi4_w
#(
    .CONSERVATIVE            (CONSERVATIVE),
    .NUM_READ_OUTSTANDING    (NUM_READ_OUTSTANDING),
    .NUM_WRITE_OUTSTANDING   (NUM_WRITE_OUTSTANDING),
    .MAX_READ_BURST_LENGTH   (MAX_READ_BURST_LENGTH),
    .MAX_WRITE_BURST_LENGTH  (MAX_WRITE_BURST_LENGTH),
    .C_M_AXI_ID_WIDTH        (C_M_AXI_ID_WIDTH),
    .C_M_AXI_ADDR_WIDTH      (C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH      (C_M_AXI_DATA_WIDTH), // power of 2 & range: 2 to 1024
    .C_M_AXI_AWUSER_WIDTH    (C_M_AXI_AWUSER_WIDTH),
    .C_M_AXI_ARUSER_WIDTH    (C_M_AXI_ARUSER_WIDTH),
    .C_M_AXI_WUSER_WIDTH     (C_M_AXI_WUSER_WIDTH),
    .C_M_AXI_RUSER_WIDTH     (C_M_AXI_RUSER_WIDTH),
    .C_M_AXI_BUSER_WIDTH     (C_M_AXI_BUSER_WIDTH),
    .C_TARGET_ADDR           (C_TARGET_ADDR),
    .C_USER_VALUE            (C_USER_VALUE),
    .C_PROT_VALUE            (C_PROT_VALUE),
    .C_CACHE_VALUE           (C_CACHE_VALUE),
    .USER_DW                 (USER_DW), // multiple of 8
    .USER_AW                 (USER_AW),
    .USER_MAXREQS            (USER_MAXREQS),
    .USER_RFIFONUM_WIDTH     (USER_RFIFONUM_WIDTH),
    .MAXI_BUFFER_IMPL        (MAXI_BUFFER_IMPL)
) u_axi4_w (
    // system signal
    .ACLK                    (ACLK),
    .ARESET                  (ARESET),
    .ACLK_EN                 (ACLK_EN),

    // write data channel
    .WID                     (m_axi_m1_WID),
    .WDATA                   (m_axi_m1_WDATA),
    .WSTRB                   (m_axi_m1_WSTRB),
    .WLAST                   (m_axi_m1_WLAST),
    .WUSER                   (m_axi_m1_WUSER),
    .WVALID                  (m_axi_m1_WVALID),
    .WREADY                  (m_axi_m1_WREADY),

    // write data
    .I_WDATA                 (wr_data),
    .I_WSTRB                 (wr_data_be),
    .I_WVALID                (wr_data_valid),
    .I_WREADY                (wr_data_ready),

    // write response channel
    .BID                     (m_axi_m1_BID),
    .BRESP                   (m_axi_m1_BRESP),
    .BUSER                   (m_axi_m1_BUSER),
    .BVALID                  (m_axi_m1_BVALID),
    .BREADY                  (m_axi_m1_BREADY),

    // write response
    .I_BVALID                (wr_resp_valid),
    .I_BREADY                (wr_resp_ready),

    .meta_ready_out          (wr_meta_ready),
    .meta_len_in             (wr_meta_len),
    .meta_valid_in           (wr_meta_valid)
);

endmodule








