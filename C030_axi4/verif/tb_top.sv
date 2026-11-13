`timescale 1ns/1ps

// Co-simulation testbench instantiating axi2stream_v2_0 and datamover_m1_m_axi.
// axi2stream_v2_0 exposes a native 512-bit datapath to the datamover:
//   * fifo_wr_addr[31:0] + fifo_wr_len[7:0]  (packed to datamover wr_addr/wr_addr_len)
//   * fifo_wr_data[511:0]
//   * fifo_rd_addr[31:0] + fifo_rd_len[7:0]
//   * fifo_rd_data[511:0]
//   * fifo_wr_resp[31:0]
// A simple 512-bit AXI4 memory model closes the m_axi_m1 loop.

module tb_top;

localparam int AXIL_DW         = 32;
localparam int AXIL_AW         = 8;      // v2 uses 8-bit AXI-Lite address (64 regs)
localparam int MEM_DEPTH_WORDS = 2048;   // 2048 x 64B
localparam int BURST_WORDS     = 1024;   // total 1024 x 64B user-side (len = 0x400)
localparam int CHUNK_WORDS     = 16;     // 16 x 64B = 1KB (datamover splits bursts at 1KB)
localparam int NUM_CHUNKS      = BURST_WORDS / CHUNK_WORDS;
localparam int TB_TIMEOUT_CYCLES = 20_000_000;
localparam logic [31:0] BASE_ADDR_BYTES = 32'h4000_0000;        // 1GB byte address
localparam logic [31:0] BASE_ADDR_WORDS = (BASE_ADDR_BYTES >> 6); // 64B-word address = 0x0100_0000

// ---------------- axi2stream_v2_0 register map ----------------
// Byte addr = reg_idx * 4 (ADDR_LSB = 2, 6-bit reg index).
localparam logic [AXIL_AW-1:0] ADDR_CTRL      = 8'h00; // slv_reg0
localparam logic [AXIL_AW-1:0] ADDR_WR_ADDR   = 8'h04; // slv_reg1
localparam logic [AXIL_AW-1:0] ADDR_WR_LEN    = 8'h08; // slv_reg2[7:0]
localparam logic [AXIL_AW-1:0] ADDR_WR_DATA0  = 8'h0C; // slv_reg3  (first  32b of 512)
localparam logic [AXIL_AW-1:0] ADDR_WR_DATA_BE_LO = 8'h54; // slv_reg21 = wr_data_be[31:0]
localparam logic [AXIL_AW-1:0] ADDR_WR_DATA_BE_HI = 8'h58; // slv_reg22 = wr_data_be[63:32]
localparam logic [AXIL_AW-1:0] ADDR_RD_ADDR   = 8'h4C; // slv_reg19
localparam logic [AXIL_AW-1:0] ADDR_RD_LEN    = 8'h50; // slv_reg20[7:0]
localparam logic [AXIL_AW-1:0] ADDR_STATUS    = 8'h80; // slv_reg32
localparam logic [AXIL_AW-1:0] ADDR_RD_DATA0  = 8'h84; // slv_reg33 (first  32b of 512)
localparam logic [AXIL_AW-1:0] ADDR_WR_RESP   = 8'hC4; // slv_reg49

// Control (slv_reg0) bit layout:
localparam int CTRL_WINC_WR_ADDR_LEN = 0;
localparam int CTRL_WINC_WR_DATA     = 1;
localparam int CTRL_WINC_RD_ADDR_LEN = 2;
localparam int CTRL_RINC_RD_DATA     = 3;
localparam int CTRL_RINC_WR_RESP     = 4;
localparam int CTRL_AP_START         = 5;

// Status (slv_reg32) bit layout:
localparam int ST_WFULL_WR_ADDR_LEN = 0;
localparam int ST_WFULL_WR_DATA     = 1;
localparam int ST_WFULL_RD_ADDR_LEN = 2;
localparam int ST_REMTY_RD_DATA     = 3;
localparam int ST_REMTY_WR_RESP     = 4;

// ---------------- clock / reset ----------------
logic ap_clk   = 1'b0;
logic ap_rst_n = 1'b0;
always #5 ap_clk = ~ap_clk;

// ---------------- AXI-Lite master to axi2stream ----------------
logic [AXIL_AW-1:0]        s00_axi_awaddr;
logic [2:0]                s00_axi_awprot;
logic                      s00_axi_awvalid;
logic                      s00_axi_awready;
logic [AXIL_DW-1:0]        s00_axi_wdata;
logic [(AXIL_DW/8)-1:0]    s00_axi_wstrb;
logic                      s00_axi_wvalid;
logic                      s00_axi_wready;
logic [1:0]                s00_axi_bresp;
logic                      s00_axi_bvalid;
logic                      s00_axi_bready;
logic [AXIL_AW-1:0]        s00_axi_araddr;
logic [2:0]                s00_axi_arprot;
logic                      s00_axi_arvalid;
logic                      s00_axi_arready;
logic [AXIL_DW-1:0]        s00_axi_rdata;
logic [1:0]                s00_axi_rresp;
logic                      s00_axi_rvalid;
logic                      s00_axi_rready;

// ---------------- FIFO channels between axi2stream_v2 and datamover ----------------
logic         ap_start;

logic [31:0]  fifo_wr_addr;
logic [31:0]  fifo_wr_len;
logic         fifo_wr_addr_len_valid;
logic         fifo_wr_addr_len_ready;

logic [511:0] fifo_wr_data;
logic         fifo_wr_data_valid;
logic         fifo_wr_data_ready;

logic [31:0]  fifo_rd_addr;
logic [31:0]  fifo_rd_len;
logic         fifo_rd_addr_len_valid;
logic         fifo_rd_addr_len_ready;

logic [511:0] fifo_rd_data;
logic         fifo_rd_data_valid;
logic         fifo_rd_data_ready;

logic [31:0]  fifo_wr_resp;
logic         fifo_wr_resp_valid;
logic         fifo_wr_resp_ready;

// Datamover expects 32b lengths and byte-enables.
logic [31:0]  dm_wr_addr_len;
logic [31:0]  dm_rd_addr_len;
logic [63:0]  dm_wr_data_be;logic [5:0]   i_rfifonum;

assign dm_wr_addr_len = fifo_wr_len;
assign dm_rd_addr_len = fifo_rd_len;

// Datamover drives wr_resp valid/ready; we synthesize a dummy 32b payload
// (datamover does not expose BRESP data).
assign fifo_wr_resp = 32'h0000_0001;

// ---------------- m_axi_m1 bus wires ----------------
logic [0:0]   m_axi_m1_AWID;
logic [31:0]  m_axi_m1_AWADDR;
logic [7:0]   m_axi_m1_AWLEN;
logic [2:0]   m_axi_m1_AWSIZE;
logic [1:0]   m_axi_m1_AWBURST;
logic [1:0]   m_axi_m1_AWLOCK;
logic [3:0]   m_axi_m1_AWCACHE;
logic [2:0]   m_axi_m1_AWPROT;
logic [3:0]   m_axi_m1_AWQOS;
logic [3:0]   m_axi_m1_AWREGION;
logic [0:0]   m_axi_m1_AWUSER;
logic         m_axi_m1_AWVALID;
logic         m_axi_m1_AWREADY;
logic [0:0]   m_axi_m1_WID;
logic [511:0] m_axi_m1_WDATA;
logic [63:0]  m_axi_m1_WSTRB;
logic         m_axi_m1_WLAST;
logic [0:0]   m_axi_m1_WUSER;
logic         m_axi_m1_WVALID;
logic         m_axi_m1_WREADY;
logic [0:0]   m_axi_m1_BID;
logic [1:0]   m_axi_m1_BRESP;
logic [0:0]   m_axi_m1_BUSER;
logic         m_axi_m1_BVALID;
logic         m_axi_m1_BREADY;
logic [0:0]   m_axi_m1_ARID;
logic [31:0]  m_axi_m1_ARADDR;
logic [7:0]   m_axi_m1_ARLEN;
logic [2:0]   m_axi_m1_ARSIZE;
logic [1:0]   m_axi_m1_ARBURST;
logic [1:0]   m_axi_m1_ARLOCK;
logic [3:0]   m_axi_m1_ARCACHE;
logic [2:0]   m_axi_m1_ARPROT;
logic [3:0]   m_axi_m1_ARQOS;
logic [3:0]   m_axi_m1_ARREGION;
logic [0:0]   m_axi_m1_ARUSER;
logic         m_axi_m1_ARVALID;
logic         m_axi_m1_ARREADY;
logic [0:0]   m_axi_m1_RID;
logic [511:0] m_axi_m1_RDATA;
logic [1:0]   m_axi_m1_RRESP;
logic         m_axi_m1_RLAST;
logic [0:0]   m_axi_m1_RUSER;
logic         m_axi_m1_RVALID;
logic         m_axi_m1_RREADY;

// ---------------- axi2stream_v2_0 instance ----------------
ydma #(
  .C_S00_AXI_DATA_WIDTH(AXIL_DW),
  .C_S00_AXI_ADDR_WIDTH(AXIL_AW)
) u_ydma (
  .s00_axi_aclk    (ap_clk),
  .s00_axi_aresetn (ap_rst_n),
  .s00_axi_awaddr  (s00_axi_awaddr),
  .s00_axi_awprot  (s00_axi_awprot),
  .s00_axi_awvalid (s00_axi_awvalid),
  .s00_axi_awready (s00_axi_awready),
  .s00_axi_wdata   (s00_axi_wdata),
  .s00_axi_wstrb   (s00_axi_wstrb),
  .s00_axi_wvalid  (s00_axi_wvalid),
  .s00_axi_wready  (s00_axi_wready),
  .s00_axi_bresp   (s00_axi_bresp),
  .s00_axi_bvalid  (s00_axi_bvalid),
  .s00_axi_bready  (s00_axi_bready),
  .s00_axi_araddr  (s00_axi_araddr),
  .s00_axi_arprot  (s00_axi_arprot),
  .s00_axi_arvalid (s00_axi_arvalid),
  .s00_axi_arready (s00_axi_arready),
  .s00_axi_rdata   (s00_axi_rdata),
  .s00_axi_rresp   (s00_axi_rresp),
  .s00_axi_rvalid  (s00_axi_rvalid),
  .s00_axi_rready  (s00_axi_rready),
  .m_axi_m1_AWID    (m_axi_m1_AWID),
  .m_axi_m1_AWADDR  (m_axi_m1_AWADDR),
  .m_axi_m1_AWLEN   (m_axi_m1_AWLEN),
  .m_axi_m1_AWSIZE  (m_axi_m1_AWSIZE),
  .m_axi_m1_AWBURST (m_axi_m1_AWBURST),
  .m_axi_m1_AWLOCK  (m_axi_m1_AWLOCK),
  .m_axi_m1_AWCACHE (m_axi_m1_AWCACHE),
  .m_axi_m1_AWPROT  (m_axi_m1_AWPROT),
  .m_axi_m1_AWQOS   (m_axi_m1_AWQOS),
  .m_axi_m1_AWREGION(m_axi_m1_AWREGION),
  .m_axi_m1_AWUSER  (m_axi_m1_AWUSER),
  .m_axi_m1_AWVALID (m_axi_m1_AWVALID),
  .m_axi_m1_AWREADY (m_axi_m1_AWREADY),

  .m_axi_m1_WID    (m_axi_m1_WID),
  .m_axi_m1_WDATA  (m_axi_m1_WDATA),
  .m_axi_m1_WSTRB  (m_axi_m1_WSTRB),
  .m_axi_m1_WLAST  (m_axi_m1_WLAST),
  .m_axi_m1_WUSER  (m_axi_m1_WUSER),
  .m_axi_m1_WVALID (m_axi_m1_WVALID),
  .m_axi_m1_WREADY (m_axi_m1_WREADY),

  .m_axi_m1_BID    (m_axi_m1_BID),
  .m_axi_m1_BRESP  (m_axi_m1_BRESP),
  .m_axi_m1_BUSER  (m_axi_m1_BUSER),
  .m_axi_m1_BVALID (m_axi_m1_BVALID),
  .m_axi_m1_BREADY (m_axi_m1_BREADY),

  .m_axi_m1_ARID    (m_axi_m1_ARID),
  .m_axi_m1_ARADDR  (m_axi_m1_ARADDR),
  .m_axi_m1_ARLEN   (m_axi_m1_ARLEN),
  .m_axi_m1_ARSIZE  (m_axi_m1_ARSIZE),
  .m_axi_m1_ARBURST (m_axi_m1_ARBURST),
  .m_axi_m1_ARLOCK  (m_axi_m1_ARLOCK),
  .m_axi_m1_ARCACHE (m_axi_m1_ARCACHE),
  .m_axi_m1_ARPROT  (m_axi_m1_ARPROT),
  .m_axi_m1_ARQOS   (m_axi_m1_ARQOS),
  .m_axi_m1_ARREGION(m_axi_m1_ARREGION),
  .m_axi_m1_ARUSER  (m_axi_m1_ARUSER),
  .m_axi_m1_ARVALID (m_axi_m1_ARVALID),
  .m_axi_m1_ARREADY (m_axi_m1_ARREADY),

  .m_axi_m1_RID    (m_axi_m1_RID),
  .m_axi_m1_RDATA  (m_axi_m1_RDATA),
  .m_axi_m1_RRESP  (m_axi_m1_RRESP),
  .m_axi_m1_RLAST  (m_axi_m1_RLAST),
  .m_axi_m1_RUSER  (m_axi_m1_RUSER),
  .m_axi_m1_RVALID (m_axi_m1_RVALID),
  .m_axi_m1_RREADY (m_axi_m1_RREADY)
);

// ---------------- Simple 512-bit AXI4 memory model ----------------
axi_mem_model #(
  .ADDR_WIDTH (32),
  .DATA_WIDTH (512),
  .ID_WIDTH   (1),
  .DEPTH_WORDS(MEM_DEPTH_WORDS),
  .BASE_ADDR_BYTES(BASE_ADDR_BYTES)
) u_m1_mem (
  .clk    (ap_clk),
  .rst    (~ap_rst_n),
  .awvalid(m_axi_m1_AWVALID),
  .awready(m_axi_m1_AWREADY),
  .awaddr (m_axi_m1_AWADDR),
  .awid   (m_axi_m1_AWID),
  .awlen  (m_axi_m1_AWLEN),
  .awsize (m_axi_m1_AWSIZE),
  .awburst(m_axi_m1_AWBURST),
  .awlock (m_axi_m1_AWLOCK),
  .awcache(m_axi_m1_AWCACHE),
  .awprot (m_axi_m1_AWPROT),
  .awqos  (m_axi_m1_AWQOS),
  .awregion(m_axi_m1_AWREGION),
  .awuser (m_axi_m1_AWUSER),
  .wvalid (m_axi_m1_WVALID),
  .wready (m_axi_m1_WREADY),
  .wdata  (m_axi_m1_WDATA),
  .wstrb  (m_axi_m1_WSTRB),
  .wlast  (m_axi_m1_WLAST),
  .wid    (m_axi_m1_WID),
  .wuser  (m_axi_m1_WUSER),
  .bvalid (m_axi_m1_BVALID),
  .bready (m_axi_m1_BREADY),
  .bresp  (m_axi_m1_BRESP),
  .bid    (m_axi_m1_BID),
  .buser  (m_axi_m1_BUSER),
  .arvalid(m_axi_m1_ARVALID),
  .arready(m_axi_m1_ARREADY),
  .araddr (m_axi_m1_ARADDR),
  .arid   (m_axi_m1_ARID),
  .arlen  (m_axi_m1_ARLEN),
  .arsize (m_axi_m1_ARSIZE),
  .arburst(m_axi_m1_ARBURST),
  .arlock (m_axi_m1_ARLOCK),
  .arcache(m_axi_m1_ARCACHE),
  .arprot (m_axi_m1_ARPROT),
  .arqos  (m_axi_m1_ARQOS),
  .arregion(m_axi_m1_ARREGION),
  .aruser (m_axi_m1_ARUSER),
  .rvalid (m_axi_m1_RVALID),
  .rready (m_axi_m1_RREADY),
  .rdata  (m_axi_m1_RDATA),
  .rlast  (m_axi_m1_RLAST),
  .rid    (m_axi_m1_RID),
  .ruser  (m_axi_m1_RUSER),
  .rresp  (m_axi_m1_RRESP)
);

// ---------------- Test control ----------------
logic [31:0]  ctrl_shadow;
logic [31:0]  tmp_data;
logic [31:0]  wr_resp_data;
logic [511:0] exp_word512;
logic [511:0] got_word512;
integer       i, j;

initial begin : tb_watchdog
  repeat (TB_TIMEOUT_CYCLES) @(posedge ap_clk);
  $fatal(1, "[FAIL] tb_top timeout after %0d cycles", TB_TIMEOUT_CYCLES);
end

task automatic axil_write(input logic [AXIL_AW-1:0] addr, input logic [31:0] data);
begin
  @(posedge ap_clk);
  s00_axi_awaddr  <= addr;
  s00_axi_awprot  <= 3'b000;
  s00_axi_awvalid <= 1'b1;
  s00_axi_wdata   <= data;
  s00_axi_wstrb   <= 4'hF;
  s00_axi_wvalid  <= 1'b1;
  s00_axi_bready  <= 1'b1;
  do @(posedge ap_clk);
  while (!(s00_axi_awready && s00_axi_wready));
  s00_axi_awvalid <= 1'b0;
  s00_axi_wvalid  <= 1'b0;
  while (!s00_axi_bvalid) @(posedge ap_clk);
  @(posedge ap_clk);
  s00_axi_bready  <= 1'b0;
end
endtask

task automatic axil_read(input logic [AXIL_AW-1:0] addr, output logic [31:0] data);
begin
  @(posedge ap_clk);
  s00_axi_araddr  <= addr;
  s00_axi_arprot  <= 3'b000;
  s00_axi_arvalid <= 1'b1;
  while (!s00_axi_arready) @(posedge ap_clk);
  @(posedge ap_clk);
  s00_axi_arvalid <= 1'b0;
  s00_axi_rready  <= 1'b1;
  while (!s00_axi_rvalid) @(posedge ap_clk);
  data = s00_axi_rdata;
  @(posedge ap_clk);
  s00_axi_rready  <= 1'b0;
end
endtask

// Toggle a bit in slv_reg0 (control). The DUT's toggle_detect converts the
// transition into a one-cycle pulse on the corresponding winc/rinc line.
task automatic ctrl_toggle_bit(input int bit_idx);
begin
  ctrl_shadow = ctrl_shadow ^ (32'h1 << bit_idx);
  axil_write(ADDR_CTRL, ctrl_shadow);
end
endtask

task automatic wait_not_full(input int wfull_bit);
  int t;
begin
  t = 0;
  while (1) begin
    axil_read(ADDR_STATUS, tmp_data);
    if (tmp_data[wfull_bit] == 1'b0) break;
    t = t + 1;
    if (t > 2000000) $fatal(1, "[FAIL] wait_not_full timeout bit=%0d", wfull_bit);
  end
end
endtask

task automatic wait_not_empty(input int rempty_bit);
  int t;
begin
  t = 0;
  while (1) begin
    axil_read(ADDR_STATUS, tmp_data);
    if (tmp_data[rempty_bit] == 1'b0) break;
    t = t + 1;
    if (t > 2000000) $fatal(1, "[FAIL] wait_not_empty timeout bit=%0d", rempty_bit);
  end
end
endtask

// Push a {len, addr} payload into the wr_addr_len FIFO.
task automatic push_wr_addr_len(input logic [31:0] addr, input logic [31:0] len);
begin
  wait_not_full(ST_WFULL_WR_ADDR_LEN);
  axil_write(ADDR_WR_ADDR, addr);
  axil_write(ADDR_WR_LEN,  len);
  ctrl_toggle_bit(CTRL_WINC_WR_ADDR_LEN);
end
endtask

// Push a {len, addr} payload into the rd_addr_len FIFO.
task automatic push_rd_addr_len(input logic [31:0] addr, input logic [31:0] len);
begin
  wait_not_full(ST_WFULL_RD_ADDR_LEN);
  axil_write(ADDR_RD_ADDR, addr);
  axil_write(ADDR_RD_LEN,  len);
  ctrl_toggle_bit(CTRL_WINC_RD_ADDR_LEN);
end
endtask

// Push a 512-bit payload into the wr_data FIFO by writing slv_reg3..slv_reg18
// (16 x 32b, little-endian: slv_reg3 is bits [31:0], slv_reg18 is bits [511:480]).
task automatic push_wr_data(input logic [511:0] d);
  int k;
begin
  wait_not_full(ST_WFULL_WR_DATA);
  for (k = 0; k < 16; k = k + 1) begin
    axil_write(ADDR_WR_DATA0 + (k * 4), d[32*k +: 32]);
  end
  ctrl_toggle_bit(CTRL_WINC_WR_DATA);
end
endtask

// Pop a 512-bit payload from the rd_data FIFO: pulse rinc, then read back
// slv_reg33..slv_reg48 (16 x 32b).
task automatic pop_rd_data(output logic [511:0] d);
  int k;
  logic [31:0] w;
begin
  wait_not_empty(ST_REMTY_RD_DATA);
  ctrl_toggle_bit(CTRL_RINC_RD_DATA);
  repeat (2) @(posedge ap_clk);
  d = '0;
  for (k = 0; k < 16; k = k + 1) begin
    axil_read(ADDR_RD_DATA0 + (k * 4), w);
    d[32*k +: 32] = w;
  end
end
endtask

task automatic pop_wr_resp(output logic [31:0] d);
begin
  wait_not_empty(ST_REMTY_WR_RESP);
  ctrl_toggle_bit(CTRL_RINC_WR_RESP);
  repeat (2) @(posedge ap_clk);
  axil_read(ADDR_WR_RESP, d);
end
endtask

// Build a deterministic 512-bit test word based on burst index i.
function automatic logic [511:0] gen_pattern(input int idx);
  int k;
  logic [511:0] v;
begin
  v = '0;
  for (k = 0; k < 16; k = k + 1) begin
    v[32*k +: 32] = 32'hA000_0000 + (idx * 16) + k;
  end
  return v;
end
endfunction

initial begin
  s00_axi_awaddr  = '0;
  s00_axi_awprot  = '0;
  s00_axi_awvalid = 1'b0;
  s00_axi_wdata   = '0;
  s00_axi_wstrb   = '0;
  s00_axi_wvalid  = 1'b0;
  s00_axi_bready  = 1'b0;
  s00_axi_araddr  = '0;
  s00_axi_arprot  = '0;
  s00_axi_arvalid = 1'b0;
  s00_axi_rready  = 1'b0;
  ctrl_shadow     = '0;

  repeat (20) @(posedge ap_clk);
  ap_rst_n = 1'b1;
  repeat (10) @(posedge ap_clk);

  for (i = 0; i < MEM_DEPTH_WORDS; i = i + 1) begin
    u_m1_mem.mem[i] = '0;
  end

  // Program wr_data byte-enables to all-ones (full 64B writes).
  axil_write(ADDR_WR_DATA_BE_LO, 32'hFFFF_FFFF);
  axil_write(ADDR_WR_DATA_BE_HI, 32'hFFFF_FFFF);

  // Assert ap_start.
  ctrl_shadow[CTRL_AP_START] = 1'b1;
  axil_write(ADDR_CTRL, ctrl_shadow);

  // -------- WRITE phase: single descriptor, len = 0x400 (datamover chunks to 1KB) --------
  $display("[CO-SIM v2] WRITE phase: single descriptor len=0x%0h @ word_addr=0x%08x (byte=0x%08x)",
           BURST_WORDS, BASE_ADDR_WORDS, BASE_ADDR_BYTES);
  // datamover shifts the 64B-word address left by 6 internally.
  push_wr_addr_len(BASE_ADDR_WORDS, BURST_WORDS);
  for (i = 0; i < BURST_WORDS; i = i + 1) begin
    push_wr_data(gen_pattern(i));
  end
  pop_wr_resp(wr_resp_data);
  $display("[CO-SIM v2] WRITE done. wr_resp=0x%08x", wr_resp_data);

  // -------- READ phase: single descriptor, len = 0x400 (datamover chunks to 1KB) --------
  $display("[CO-SIM v2] READ phase: single descriptor len=0x%0h @ word_addr=0x%08x (byte=0x%08x)",
           BURST_WORDS, BASE_ADDR_WORDS, BASE_ADDR_BYTES);
  push_rd_addr_len(BASE_ADDR_WORDS, BURST_WORDS);
  for (i = 0; i < BURST_WORDS; i = i + 1) begin
    pop_rd_data(got_word512);
    exp_word512 = gen_pattern(i);
    if (got_word512 !== exp_word512) begin
      for (j = 0; j < 16; j = j + 1) begin
        if (got_word512[32*j +: 32] !== exp_word512[32*j +: 32]) begin
          $display("  mismatch beat=%0d lane=%0d exp=0x%08x act=0x%08x",
                   i, j, exp_word512[32*j +: 32], got_word512[32*j +: 32]);
        end
      end
      $fatal(1, "[FAIL] rd mismatch at beat %0d", i);
    end
  end
  $display("[CO-SIM v2] READ done. last rd_data[31:0]=0x%08x", got_word512[31:0]);

  $display("[PASS] axi2stream_v2_0 <-> datamover_m1_m_axi single-descriptor len=0x%0h @1GB co-sim OK", BURST_WORDS);
  $finish;
end

endmodule


// ============================================================================
// Simple AXI4 memory model.  Supports multi-beat read/write bursts.  Address
// field is interpreted as a byte address and shifted by $clog2(DATA_WIDTH/8)
// to index the word memory.
// ============================================================================
module axi_mem_model #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 512,
  parameter int ID_WIDTH   = 1,
  parameter int DEPTH_WORDS= 2048,
  parameter logic [ADDR_WIDTH-1:0] BASE_ADDR_BYTES = '0
) (
  input  logic                     clk,
  input  logic                     rst,

  input  logic                     awvalid,
  output logic                     awready,
  input  logic [ADDR_WIDTH-1:0]    awaddr,
  input  logic [ID_WIDTH-1:0]      awid,
  input  logic [7:0]               awlen,
  input  logic [2:0]               awsize,
  input  logic [1:0]               awburst,
  input  logic [1:0]               awlock,
  input  logic [3:0]               awcache,
  input  logic [2:0]               awprot,
  input  logic [3:0]               awqos,
  input  logic [3:0]               awregion,
  input  logic [0:0]               awuser,

  input  logic                     wvalid,
  output logic                     wready,
  input  logic [DATA_WIDTH-1:0]    wdata,
  input  logic [DATA_WIDTH/8-1:0]  wstrb,
  input  logic                     wlast,
  input  logic [ID_WIDTH-1:0]      wid,
  input  logic [0:0]               wuser,

  output logic                     bvalid,
  input  logic                     bready,
  output logic [1:0]               bresp,
  output logic [ID_WIDTH-1:0]      bid,
  output logic [0:0]               buser,

  input  logic                     arvalid,
  output logic                     arready,
  input  logic [ADDR_WIDTH-1:0]    araddr,
  input  logic [ID_WIDTH-1:0]      arid,
  input  logic [7:0]               arlen,
  input  logic [2:0]               arsize,
  input  logic [1:0]               arburst,
  input  logic [1:0]               arlock,
  input  logic [3:0]               arcache,
  input  logic [2:0]               arprot,
  input  logic [3:0]               arqos,
  input  logic [3:0]               arregion,
  input  logic [0:0]               aruser,

  output logic                     rvalid,
  input  logic                     rready,
  output logic [DATA_WIDTH-1:0]    rdata,
  output logic                     rlast,
  output logic [ID_WIDTH-1:0]      rid,
  output logic [0:0]               ruser,
  output logic [1:0]               rresp
);

localparam int STRB_WIDTH = DATA_WIDTH / 8;

logic [DATA_WIDTH-1:0] mem [0:DEPTH_WORDS-1];

logic [ADDR_WIDTH-1:0] wr_base_addr;
logic [7:0]            wr_len;
logic [15:0]           wr_beat;
logic                  wr_active;
logic                  wr_resp_pending;

logic [ADDR_WIDTH-1:0] rd_base_addr;
logic [7:0]            rd_len;
logic [15:0]           rd_beat;
logic                  rd_active;
logic [ID_WIDTH-1:0]   rd_id;

int unsigned idx;
integer      byte_i;

assign awready = (!wr_active) && (!bvalid) && (!wr_resp_pending);
assign wready  = wr_active;
assign arready = (!rd_active) && (!rvalid);

always_ff @(posedge clk) begin
  if (rst) begin
    wr_base_addr    <= '0;
    wr_len          <= '0;
    wr_beat         <= '0;
    wr_active       <= 1'b0;
    wr_resp_pending <= 1'b0;
    bvalid          <= 1'b0;
    bresp           <= 2'b00;
    bid             <= '0;
    buser           <= '0;
  end else begin
    if (awvalid && awready) begin
      wr_base_addr <= awaddr;
      wr_len       <= awlen;
      wr_beat      <= '0;
      wr_active    <= 1'b1;
      bid          <= awid;
    end

    if (wvalid && wready && wr_active) begin
      idx = (wr_base_addr >= BASE_ADDR_BYTES)
          ? (((wr_base_addr - BASE_ADDR_BYTES) >> $clog2(STRB_WIDTH)) + wr_beat)
          : DEPTH_WORDS;
      if (idx < DEPTH_WORDS) begin
        for (byte_i = 0; byte_i < STRB_WIDTH; byte_i = byte_i + 1) begin
          if (wstrb[byte_i]) mem[idx][8*byte_i +: 8] <= wdata[8*byte_i +: 8];
        end
      end
      if ((wr_beat == wr_len) || wlast) begin
        wr_active       <= 1'b0;
        wr_resp_pending <= 1'b1;
      end
      wr_beat <= wr_beat + 1'b1;
    end

    if (wr_resp_pending && !bvalid) begin
      bvalid <= 1'b1;
      bresp  <= 2'b00;
      buser  <= '0;
      wr_resp_pending <= 1'b0;
    end

    if (bvalid && bready) bvalid <= 1'b0;
  end
end

always_ff @(posedge clk) begin
  if (rst) begin
    rd_base_addr <= '0;
    rd_len       <= '0;
    rd_beat      <= '0;
    rd_active    <= 1'b0;
    rd_id        <= '0;
    rvalid       <= 1'b0;
    rdata        <= '0;
    rlast        <= 1'b0;
    rid          <= '0;
    ruser        <= '0;
    rresp        <= 2'b00;
  end else begin
    if (arvalid && arready) begin
      rd_base_addr <= araddr;
      rd_len       <= arlen;
      rd_beat      <= '0;
      rd_active    <= 1'b1;
      rd_id        <= arid;
    end

    if (rd_active && (!rvalid || rready)) begin
      idx = (rd_base_addr >= BASE_ADDR_BYTES)
          ? (((rd_base_addr - BASE_ADDR_BYTES) >> $clog2(STRB_WIDTH)) + rd_beat)
          : DEPTH_WORDS;
      rdata <= (idx < DEPTH_WORDS) ? mem[idx] : '0;
      rid   <= rd_id;
      ruser <= '0;
      rresp <= 2'b00;
      rlast <= (rd_beat == rd_len);
      rvalid<= 1'b1;
      if (rd_beat == rd_len) rd_active <= 1'b0;
      else                    rd_beat   <= rd_beat + 1'b1;
    end

    if (rvalid && rready && rlast) begin
      rvalid <= 1'b0;
      rlast  <= 1'b0;
    end
  end
end

endmodule

