
`timescale 1 ns / 1 ps
`default_nettype wire

	module ydma #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	  = 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	  = 8,
		parameter integer CONSERVATIVE            = 0,
		parameter integer NUM_READ_OUTSTANDING    = 2,
		parameter integer NUM_WRITE_OUTSTANDING   = 2,
		parameter integer MAX_READ_BURST_LENGTH   = 16,
		parameter integer MAX_WRITE_BURST_LENGTH  = 16,
		parameter integer C_M_AXI_ID_WIDTH        = 1,
		parameter integer C_M_AXI_ADDR_WIDTH      = 32,
		parameter integer C_M_AXI_DATA_WIDTH      = 512, // power of 2 & range: 2 to 1024
		parameter integer C_M_AXI_AWUSER_WIDTH    = 1,
		parameter integer C_M_AXI_ARUSER_WIDTH    = 1,
		parameter integer C_M_AXI_WUSER_WIDTH     = 1,
		parameter integer C_M_AXI_RUSER_WIDTH     = 1,
		parameter integer C_M_AXI_BUSER_WIDTH     = 1,
		parameter integer C_TARGET_ADDR           = 32'h00000000,
		parameter integer C_USER_VALUE            = 1'b0,
		parameter integer C_PROT_VALUE            = 3'b000,
		parameter integer C_CACHE_VALUE           = 4'b0011,
		parameter integer USER_DW                 = 512, // multiple of 8
		parameter integer USER_AW                 = 32,
		parameter integer USER_MAXREQS            = 16,
		parameter integer USER_RFIFONUM_WIDTH     = 6,
		parameter integer MAXI_BUFFER_IMPL        = "block"
	)
	(

		input  wire                                s00_axi_aclk,
		input  wire                                s00_axi_aresetn,
		input  wire [C_S00_AXI_ADDR_WIDTH-1 : 0]   s00_axi_awaddr,
		input  wire [2 : 0]                        s00_axi_awprot,
		input  wire                                s00_axi_awvalid,
		output wire                                s00_axi_awready,
		input  wire [C_S00_AXI_DATA_WIDTH-1 : 0]   s00_axi_wdata,
		input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
		input  wire                                s00_axi_wvalid,
		output wire                                s00_axi_wready,
		output wire [1 : 0]                        s00_axi_bresp,
		output wire                                s00_axi_bvalid,
		input  wire                                s00_axi_bready,
		input  wire [C_S00_AXI_ADDR_WIDTH-1 : 0]   s00_axi_araddr,
		input  wire [2 : 0]                        s00_axi_arprot,
		input  wire                                s00_axi_arvalid,
		output wire                                s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0]   s00_axi_rdata,
		output wire [1 : 0]                        s00_axi_rresp,
		output wire                                s00_axi_rvalid,
		input  wire                                s00_axi_rready,

		// write address channel
		output wire [C_M_AXI_ID_WIDTH-1:0]         m_axi_m1_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1:0]       m_axi_m1_AWADDR,
		output wire [7:0]                          m_axi_m1_AWLEN,
		output wire [2:0]                          m_axi_m1_AWSIZE,
		output wire [1:0]                          m_axi_m1_AWBURST,
		output wire [1:0]                          m_axi_m1_AWLOCK,
		output wire [3:0]                          m_axi_m1_AWCACHE,
		output wire [2:0]                          m_axi_m1_AWPROT,
		output wire [3:0]                          m_axi_m1_AWQOS,
		output wire [3:0]                          m_axi_m1_AWREGION,
		output wire [C_M_AXI_AWUSER_WIDTH-1:0]     m_axi_m1_AWUSER,
		output wire                                m_axi_m1_AWVALID,
		input  wire                                m_axi_m1_AWREADY,
		// write data channel
		output wire [C_M_AXI_ID_WIDTH-1:0]         m_axi_m1_WID,
		output wire [C_M_AXI_DATA_WIDTH-1:0]       m_axi_m1_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1:0]     m_axi_m1_WSTRB,
		output wire                                m_axi_m1_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1:0]      m_axi_m1_WUSER,
		output wire                                m_axi_m1_WVALID,
		input  wire                                m_axi_m1_WREADY,
		// write response channel
		input  wire [C_M_AXI_ID_WIDTH-1:0]         m_axi_m1_BID,
		input  wire [1:0]                          m_axi_m1_BRESP,
		input  wire [C_M_AXI_BUSER_WIDTH-1:0]      m_axi_m1_BUSER,
		input  wire                                m_axi_m1_BVALID,
		output wire                                m_axi_m1_BREADY,
		// read address channel
		output wire [C_M_AXI_ID_WIDTH-1:0]         m_axi_m1_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1:0]       m_axi_m1_ARADDR,
		output wire [7:0]                          m_axi_m1_ARLEN,
		output wire [2:0]                          m_axi_m1_ARSIZE,
		output wire [1:0]                          m_axi_m1_ARBURST,
		output wire [1:0]                          m_axi_m1_ARLOCK,
		output wire [3:0]                          m_axi_m1_ARCACHE,
		output wire [2:0]                          m_axi_m1_ARPROT,
		output wire [3:0]                          m_axi_m1_ARQOS,
		output wire [3:0]                          m_axi_m1_ARREGION,
		output wire [C_M_AXI_ARUSER_WIDTH-1:0]     m_axi_m1_ARUSER,
		output wire                                m_axi_m1_ARVALID,
		input  wire                                m_axi_m1_ARREADY,
		// read data channel
		input  wire [C_M_AXI_ID_WIDTH-1:0]         m_axi_m1_RID,
		input  wire [C_M_AXI_DATA_WIDTH-1:0]       m_axi_m1_RDATA,
		input  wire [1:0]                          m_axi_m1_RRESP,
		input  wire                                m_axi_m1_RLAST,
		input  wire [C_M_AXI_RUSER_WIDTH-1:0]      m_axi_m1_RUSER,
		input  wire                                m_axi_m1_RVALID,
		output wire                                m_axi_m1_RREADY
	);

	// AXI4LITE signals
	reg [C_S00_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S00_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S00_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S00_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S00_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 5;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 64
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg3;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg4;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg5;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg6;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg7;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg8;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg9;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg10;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg11;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg12;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg13;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg14;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg15;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg16;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg17;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg18;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg19;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg20;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg21;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg22;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg23;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg24;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg25;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg26;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg27;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg28;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg29;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg30;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg31;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg32;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg33;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg34;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg35;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg36;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg37;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg38;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg39;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg40;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg41;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg42;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg43;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg44;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg45;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg46;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg47;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg48;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg49;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg50;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg51;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg52;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg53;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg54;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg55;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg56;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg57;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg58;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg59;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg60;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg61;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg62;
	wire [C_S00_AXI_DATA_WIDTH-1:0]	slv_reg63;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S00_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;

	// I/O Connections assignments

	assign s00_axi_awready	= axi_awready;
	assign s00_axi_wready	= axi_wready;
	assign s00_axi_bresp	= axi_bresp;
	assign s00_axi_bvalid	= axi_bvalid;
	assign s00_axi_arready	= axi_arready;
	assign s00_axi_rdata	= axi_rdata;
	assign s00_axi_rresp	= axi_rresp;
	assign s00_axi_rvalid	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one s00_axi_aclk clock cycle when both
	// s00_axi_awvalid and s00_axi_wvalid are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && s00_axi_awvalid && s00_axi_wvalid && aw_en)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (s00_axi_bready && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// s00_axi_awvalid and s00_axi_wvalid are valid. 

	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && s00_axi_awvalid && s00_axi_wvalid && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= s00_axi_awaddr;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one s00_axi_aclk clock cycle when both
	// s00_axi_awvalid and s00_axi_wvalid are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && s00_axi_wvalid && s00_axi_awvalid && aw_en )
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, s00_axi_wvalid, axi_wready and s00_axi_wvalid are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && s00_axi_wvalid && axi_awready && s00_axi_awvalid;

	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	      slv_reg4 <= 0;
	      slv_reg5 <= 0;
	      slv_reg6 <= 0;
	      slv_reg7 <= 0;
	      slv_reg8 <= 0;
	      slv_reg9 <= 0;
	      slv_reg10 <= 0;
	      slv_reg11 <= 0;
	      slv_reg12 <= 0;
	      slv_reg13 <= 0;
	      slv_reg14 <= 0;
	      slv_reg15 <= 0;
	      slv_reg16 <= 0;
	      slv_reg17 <= 0;
	      slv_reg18 <= 0;
	      slv_reg19 <= 0;
	      slv_reg20 <= 0;
	      slv_reg21 <= 0;
	      slv_reg22 <= 0;
	      slv_reg23 <= 0;
	      slv_reg24 <= 0;
	      slv_reg25 <= 0;
	      slv_reg26 <= 0;
	      slv_reg27 <= 0;
	      slv_reg28 <= 0;
	      slv_reg29 <= 0;
	      slv_reg30 <= 0;
	      slv_reg31 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          6'h00:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h01:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h02:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h03:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h04:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                slv_reg4[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h05:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                slv_reg5[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h06:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 6
	                slv_reg6[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h07:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 7
	                slv_reg7[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h08:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 8
	                slv_reg8[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h09:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 9
	                slv_reg9[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h0A:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 10
	                slv_reg10[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h0B:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 11
	                slv_reg11[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h0C:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 12
	                slv_reg12[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h0D:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 13
	                slv_reg13[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h0E:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 14
	                slv_reg14[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h0F:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 15
	                slv_reg15[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h10:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 16
	                slv_reg16[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h11:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 17
	                slv_reg17[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h12:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 18
	                slv_reg18[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h13:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 19
	                slv_reg19[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h14:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 20
	                slv_reg20[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h15:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 21
	                slv_reg21[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h16:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 22
	                slv_reg22[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h17:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 23
	                slv_reg23[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h18:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 24
	                slv_reg24[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h19:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 25
	                slv_reg25[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h1A:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 26
	                slv_reg26[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h1B:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 27
	                slv_reg27[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h1C:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 28
	                slv_reg28[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h1D:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 29
	                slv_reg29[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h1E:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 30
	                slv_reg30[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          6'h1F:
	            for ( byte_index = 0; byte_index <= (C_S00_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( s00_axi_wstrb[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 31
	                slv_reg31[(byte_index*8) +: 8] <= s00_axi_wdata[(byte_index*8) +: 8];
	              end  
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                      slv_reg4 <= slv_reg4;
	                      slv_reg5 <= slv_reg5;
	                      slv_reg6 <= slv_reg6;
	                      slv_reg7 <= slv_reg7;
	                      slv_reg8 <= slv_reg8;
	                      slv_reg9 <= slv_reg9;
	                      slv_reg10 <= slv_reg10;
	                      slv_reg11 <= slv_reg11;
	                      slv_reg12 <= slv_reg12;
	                      slv_reg13 <= slv_reg13;
	                      slv_reg14 <= slv_reg14;
	                      slv_reg15 <= slv_reg15;
	                      slv_reg16 <= slv_reg16;
	                      slv_reg17 <= slv_reg17;
	                      slv_reg18 <= slv_reg18;
	                      slv_reg19 <= slv_reg19;
	                      slv_reg20 <= slv_reg20;
	                      slv_reg21 <= slv_reg21;
	                      slv_reg22 <= slv_reg22;
	                      slv_reg23 <= slv_reg23;
	                      slv_reg24 <= slv_reg24;
	                      slv_reg25 <= slv_reg25;
	                      slv_reg26 <= slv_reg26;
	                      slv_reg27 <= slv_reg27;
	                      slv_reg28 <= slv_reg28;
	                      slv_reg29 <= slv_reg29;
	                      slv_reg30 <= slv_reg30;
	                      slv_reg31 <= slv_reg31;
	                    end
	        endcase
	      end
	  end
	end    

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, s00_axi_wvalid, axi_wready and s00_axi_wvalid are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && s00_axi_awvalid && ~axi_bvalid && axi_wready && s00_axi_wvalid)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (s00_axi_bready && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one s00_axi_aclk clock cycle when
	// s00_axi_arvalid is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when s00_axi_arvalid is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && s00_axi_arvalid)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= s00_axi_araddr;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one s00_axi_aclk clock cycle when both 
	// s00_axi_arvalid and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && s00_axi_arvalid && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && s00_axi_rready)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & s00_axi_arvalid & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        6'h00   : reg_data_out <= slv_reg0;
	        6'h01   : reg_data_out <= slv_reg1;
	        6'h02   : reg_data_out <= slv_reg2;
	        6'h03   : reg_data_out <= slv_reg3;
	        6'h04   : reg_data_out <= slv_reg4;
	        6'h05   : reg_data_out <= slv_reg5;
	        6'h06   : reg_data_out <= slv_reg6;
	        6'h07   : reg_data_out <= slv_reg7;
	        6'h08   : reg_data_out <= slv_reg8;
	        6'h09   : reg_data_out <= slv_reg9;
	        6'h0A   : reg_data_out <= slv_reg10;
	        6'h0B   : reg_data_out <= slv_reg11;
	        6'h0C   : reg_data_out <= slv_reg12;
	        6'h0D   : reg_data_out <= slv_reg13;
	        6'h0E   : reg_data_out <= slv_reg14;
	        6'h0F   : reg_data_out <= slv_reg15;
	        6'h10   : reg_data_out <= slv_reg16;
	        6'h11   : reg_data_out <= slv_reg17;
	        6'h12   : reg_data_out <= slv_reg18;
	        6'h13   : reg_data_out <= slv_reg19;
	        6'h14   : reg_data_out <= slv_reg20;
	        6'h15   : reg_data_out <= slv_reg21;
	        6'h16   : reg_data_out <= slv_reg22;
	        6'h17   : reg_data_out <= slv_reg23;
	        6'h18   : reg_data_out <= slv_reg24;
	        6'h19   : reg_data_out <= slv_reg25;
	        6'h1A   : reg_data_out <= slv_reg26;
	        6'h1B   : reg_data_out <= slv_reg27;
	        6'h1C   : reg_data_out <= slv_reg28;
	        6'h1D   : reg_data_out <= slv_reg29;
	        6'h1E   : reg_data_out <= slv_reg30;
	        6'h1F   : reg_data_out <= slv_reg31;
	        6'h20   : reg_data_out <= slv_reg32;
	        6'h21   : reg_data_out <= slv_reg33;
	        6'h22   : reg_data_out <= slv_reg34;
	        6'h23   : reg_data_out <= slv_reg35;
	        6'h24   : reg_data_out <= slv_reg36;
	        6'h25   : reg_data_out <= slv_reg37;
	        6'h26   : reg_data_out <= slv_reg38;
	        6'h27   : reg_data_out <= slv_reg39;
	        6'h28   : reg_data_out <= slv_reg40;
	        6'h29   : reg_data_out <= slv_reg41;
	        6'h2A   : reg_data_out <= slv_reg42;
	        6'h2B   : reg_data_out <= slv_reg43;
	        6'h2C   : reg_data_out <= slv_reg44;
	        6'h2D   : reg_data_out <= slv_reg45;
	        6'h2E   : reg_data_out <= slv_reg46;
	        6'h2F   : reg_data_out <= slv_reg47;
	        6'h30   : reg_data_out <= slv_reg48;
	        6'h31   : reg_data_out <= slv_reg49;
	        6'h32   : reg_data_out <= slv_reg50;
	        6'h33   : reg_data_out <= slv_reg51;
	        6'h34   : reg_data_out <= slv_reg52;
	        6'h35   : reg_data_out <= slv_reg53;
	        6'h36   : reg_data_out <= slv_reg54;
	        6'h37   : reg_data_out <= slv_reg55;
	        6'h38   : reg_data_out <= slv_reg56;
	        6'h39   : reg_data_out <= slv_reg57;
	        6'h3A   : reg_data_out <= slv_reg58;
	        6'h3B   : reg_data_out <= slv_reg59;
	        6'h3C   : reg_data_out <= slv_reg60;
	        6'h3D   : reg_data_out <= slv_reg61;
	        6'h3E   : reg_data_out <= slv_reg62;
	        6'h3F   : reg_data_out <= slv_reg63;
	        default : reg_data_out <= 0;
	      endcase
	end

	// Output register or memory read data
	always @( posedge s00_axi_aclk )
	begin
	  if ( s00_axi_aresetn == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (s00_axi_arvalid) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	// Add user logic here

    wire [USER_AW-1:0]                 wr_addr;
    wire [31:0]                        wr_addr_len;
    wire                               wr_addr_valid;
    wire                               wr_addr_ready;
    // write data
    wire [USER_DW-1:0]                 wr_data;
    wire [USER_DW/8-1:0]               wr_data_be;
    wire                               wr_data_valid;
    wire                               wr_data_ready;
    // write response
    wire                               wr_resp_valid;
    wire                               wr_resp_ready;
    // read address
    wire [USER_AW-1:0]                 rd_addr;
    wire [31:0]                        rd_addr_len;
    wire                               rd_addr_valid;
    wire                               rd_addr_ready;
    // read data
    wire [USER_DW-1:0]                 rd_data;
    wire                               rd_data_valid;
    wire                               rd_data_ready;

	// =========================================================
	// Register map:
	//   slv_reg0 : FIFO control (software-toggled pulses + ap_start)
	//       [0]=winc_wr_addr_len, [1]=winc_wr_data, [2]=winc_rd_addr_len,
	//       [3]=rinc_rd_data,     [4]=rinc_wr_resp, [5]=ap_start
	//   slv_reg1 + slv_reg2[7:0]       : 40b wr_addr_len FIFO payload {len,addr}
	//   slv_reg3..slv_reg18 (16*32=512): wr_data FIFO payload
	//   slv_reg19 + slv_reg20[7:0]     : 40b rd_addr_len FIFO payload {len,addr}
	//   slv_reg32 : status (full/empty flags)
	//   slv_reg33..slv_reg48 (512b)    : rd_data FIFO readback
	//   slv_reg49                      : wr_resp FIFO readback
	// =========================================================
	wire [31:0] slv_reg0_pulse;
	wire        winc_wr_addr_len, winc_wr_data, winc_rd_addr_len;
	wire        rinc_rd_data,     rinc_wr_resp;
	wire        wfull_wr_addr_len, wfull_wr_data, wfull_rd_addr_len;
	wire        rempty_rd_data,    rempty_wr_resp;
	wire        ap_start;

	// Clock/reset aliases for the merged datamover (m_axi) logic
	wire        ACLK    = s00_axi_aclk;
	wire        ARESET  = ~s00_axi_aresetn;
	wire        ACLK_EN = 1'b1;
	wire [USER_RFIFONUM_WIDTH-1:0] I_RFIFONUM;

	assign winc_wr_addr_len = slv_reg0_pulse[0];
	assign winc_wr_data     = slv_reg0_pulse[1];
	assign winc_rd_addr_len = slv_reg0_pulse[2];
	assign rinc_rd_data     = slv_reg0_pulse[3];
	assign rinc_wr_resp     = slv_reg0_pulse[4];
	assign ap_start         = slv_reg0[5];

	// Status register slv_reg32:
	//   [0]=wfull_wr_addr_len, [1]=wfull_wr_data, [2]=wfull_rd_addr_len,
	//   [3]=rempty_rd_data,    [4]=rempty_wr_resp
	assign slv_reg32 = {27'd0,
	                    rempty_wr_resp,
	                    rempty_rd_data,
	                    wfull_rd_addr_len,
	                    wfull_wr_data,
	                    wfull_wr_addr_len};

	// Unused readback registers tied to 0.
	assign slv_reg50 = 32'd0;
	assign slv_reg51 = 32'd0;
	assign slv_reg52 = 32'd0;
	assign slv_reg53 = 32'd0;
	assign slv_reg54 = 32'd0;
	assign slv_reg55 = 32'd0;
	assign slv_reg56 = 32'd0;
	assign slv_reg57 = 32'd0;
	assign slv_reg58 = 32'd0;
	assign slv_reg59 = 32'd0;
	assign slv_reg60 = 32'd0;
	assign slv_reg61 = 32'd0;
	assign slv_reg62 = 32'd0;
	assign slv_reg63 = 32'd0;

	toggle_detect #(
	    .data_width(32)
	) toggle_detect_slv0 (
	    .data_out(slv_reg0_pulse),
	    .data_in (slv_reg0),
	    .clk     (s00_axi_aclk),
	    .reset   (~s00_axi_aresetn)
	);

	wire [63:0]  wr_addr_len_wdata = {slv_reg2, slv_reg1};
	wire [63:0]  rd_addr_len_wdata = {slv_reg20, slv_reg19};
	// slv_reg21 = wr_data_be[31:0], slv_reg22 = wr_data_be[63:32]
	assign wr_data_be = {slv_reg22, slv_reg21};
	wire [511:0] wr_data_wdata = {slv_reg18, slv_reg17, slv_reg16, slv_reg15,
	                              slv_reg14, slv_reg13, slv_reg12, slv_reg11,
	                              slv_reg10, slv_reg9,  slv_reg8,  slv_reg7,
	                              slv_reg6,  slv_reg5,  slv_reg4,  slv_reg3};
	wire [511:0] rd_data_rdata;
	assign {slv_reg48, slv_reg47, slv_reg46, slv_reg45,
	        slv_reg44, slv_reg43, slv_reg42, slv_reg41,
	        slv_reg40, slv_reg39, slv_reg38, slv_reg37,
	        slv_reg36, slv_reg35, slv_reg34, slv_reg33} = rd_data_rdata;

	fifo_stream_out #(
	    .PAYLOAD_BITS(64),
	    .NUM_BRAM_ADDR_BITS(9)
	) arm2fabric_wr_addr_len (
	    .clk           (s00_axi_aclk),
	    .reset         (~s00_axi_aresetn),
	    .wdata         (wr_addr_len_wdata),
	    .winc          (winc_wr_addr_len),
	    .full          (wfull_wr_addr_len),
	    .dout          ({wr_addr_len, wr_addr}),
	    .val_out       (wr_addr_valid),
	    .ready_downward(wr_addr_ready)
	);

	fifo_stream_out #(
	    .PAYLOAD_BITS(512),
	    .NUM_BRAM_ADDR_BITS(9)
	) arm2fabric_wr_data (
	    .clk           (s00_axi_aclk),
	    .reset         (~s00_axi_aresetn),
	    .wdata         (wr_data_wdata),
	    .winc          (winc_wr_data),
	    .full          (wfull_wr_data),
	    .dout          (wr_data),
	    .val_out       (wr_data_valid),
	    .ready_downward(wr_data_ready)
	);

	fifo_stream_out #(
	    .PAYLOAD_BITS(64),
	    .NUM_BRAM_ADDR_BITS(9)
	) arm2fabric_rd_addr_len (
	    .clk           (s00_axi_aclk),
	    .reset         (~s00_axi_aresetn),
	    .wdata         (rd_addr_len_wdata),
	    .winc          (winc_rd_addr_len),
	    .full          (wfull_rd_addr_len),
	    .dout          ({rd_addr_len, rd_addr}),
	    .val_out       (rd_addr_valid),
	    .ready_downward(rd_addr_ready)
	);

	fifo_stream_in #(
	    .PAYLOAD_BITS(512),
	    .NUM_BRAM_ADDR_BITS(9)
	) fabric2arm_rd_data (
	    .clk         (s00_axi_aclk),
	    .reset       (~s00_axi_aresetn),
	    .din         (rd_data),
	    .val_in      (rd_data_valid),
	    .ready_upward(rd_data_ready),
	    .rdata       (rd_data_rdata),
	    .rempty      (rempty_rd_data),
	    .rinc        (rinc_rd_data)
	);

	fifo_stream_in #(
	    .PAYLOAD_BITS(32),
	    .NUM_BRAM_ADDR_BITS(9)
	) fabric2arm_wr_resp (
	    .clk         (s00_axi_aclk),
	    .reset       (~s00_axi_aresetn),
	    .din         (32'd0), // write response is always 0 for now
	    .val_in      (wr_resp_valid),
	    .ready_upward(wr_resp_ready),
	    .rdata       (slv_reg49),
	    .rempty      (rempty_wr_resp),
	    .rinc        (rinc_wr_resp)
	);


assign I_RFIFONUM  = 2;

wire [31:0] cplQ_len;
wire        cplQ_valid;
wire        cplQ_ready;

wire [31:0] rd_meta_len;
wire        rd_meta_valid;
wire        rd_meta_ready;

wire [31:0] wrQ_len;
wire        wrQ_valid;
wire        wrQ_ready;

wire [31:0] wr_meta_len;
wire        wr_meta_valid;
wire        wr_meta_ready;


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
	// User logic ends

	endmodule
