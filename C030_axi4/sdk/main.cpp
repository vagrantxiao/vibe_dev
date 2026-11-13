#include "xparameters.h"	/* SDK generated parameters */
#include "xil_printf.h"
#include "xil_io.h"		/* Xil_In32 / Xil_Out32 */
#include "xil_types.h"		/* u32 */
#include "xil_cache.h"		/* Xil_DCacheFlushRange / InvalidateRange */
#include "xrtcpsu.h"		/* RTCPSU device driver */
#include <stdint.h>		/* uintptr_t */
#ifdef __cplusplus
#endif



#include "xscugic.h"		/* Interrupt controller device driver */
#include "xil_exception.h"
#include "xil_printf.h"


#define AXI_REG0  XPAR_YDMA_0_BASEADDR
#define AXI_REG1  XPAR_YDMA_0_BASEADDR+4
#define AXI_REG2  XPAR_YDMA_0_BASEADDR+8
#define AXI_REG3  XPAR_YDMA_0_BASEADDR+12
#define AXI_REG4  XPAR_YDMA_0_BASEADDR+16
#define AXI_REG5  XPAR_YDMA_0_BASEADDR+20
#define AXI_REG6  XPAR_YDMA_0_BASEADDR+24
#define AXI_REG7  XPAR_YDMA_0_BASEADDR+28
#define AXI_REG8  XPAR_YDMA_0_BASEADDR+32
#define AXI_REG9  XPAR_YDMA_0_BASEADDR+36
#define AXI_REG10 XPAR_YDMA_0_BASEADDR+40
#define AXI_REG11 XPAR_YDMA_0_BASEADDR+44
#define AXI_REG12 XPAR_YDMA_0_BASEADDR+48
#define AXI_REG13 XPAR_YDMA_0_BASEADDR+52
#define AXI_REG14 XPAR_YDMA_0_BASEADDR+56
#define AXI_REG15 XPAR_YDMA_0_BASEADDR+60
#define AXI_REG16 XPAR_YDMA_0_BASEADDR+64
#define AXI_REG17 XPAR_YDMA_0_BASEADDR+68
#define AXI_REG18 XPAR_YDMA_0_BASEADDR+72
#define AXI_REG19 XPAR_YDMA_0_BASEADDR+76
#define AXI_REG20 XPAR_YDMA_0_BASEADDR+80
#define AXI_REG21 XPAR_YDMA_0_BASEADDR+84
#define AXI_REG22 XPAR_YDMA_0_BASEADDR+88
#define AXI_REG23 XPAR_YDMA_0_BASEADDR+92
#define AXI_REG24 XPAR_YDMA_0_BASEADDR+96
#define AXI_REG25 XPAR_YDMA_0_BASEADDR+100
#define AXI_REG26 XPAR_YDMA_0_BASEADDR+104
#define AXI_REG27 XPAR_YDMA_0_BASEADDR+108
#define AXI_REG28 XPAR_YDMA_0_BASEADDR+112
#define AXI_REG29 XPAR_YDMA_0_BASEADDR+116
#define AXI_REG30 XPAR_YDMA_0_BASEADDR+120
#define AXI_REG31 XPAR_YDMA_0_BASEADDR+124
#define AXI_REG32 XPAR_YDMA_0_BASEADDR+128
#define AXI_REG33 XPAR_YDMA_0_BASEADDR+132
#define AXI_REG34 XPAR_YDMA_0_BASEADDR+136
#define AXI_REG35 XPAR_YDMA_0_BASEADDR+140
#define AXI_REG36 XPAR_YDMA_0_BASEADDR+144
#define AXI_REG37 XPAR_YDMA_0_BASEADDR+148
#define AXI_REG38 XPAR_YDMA_0_BASEADDR+152
#define AXI_REG39 XPAR_YDMA_0_BASEADDR+156
#define AXI_REG40 XPAR_YDMA_0_BASEADDR+160
#define AXI_REG41 XPAR_YDMA_0_BASEADDR+164
#define AXI_REG42 XPAR_YDMA_0_BASEADDR+168
#define AXI_REG43 XPAR_YDMA_0_BASEADDR+172
#define AXI_REG44 XPAR_YDMA_0_BASEADDR+176
#define AXI_REG45 XPAR_YDMA_0_BASEADDR+180
#define AXI_REG46 XPAR_YDMA_0_BASEADDR+184
#define AXI_REG47 XPAR_YDMA_0_BASEADDR+188
#define AXI_REG48 XPAR_YDMA_0_BASEADDR+192
#define AXI_REG49 XPAR_YDMA_0_BASEADDR+196
#define AXI_REG50 XPAR_YDMA_0_BASEADDR+200
#define AXI_REG51 XPAR_YDMA_0_BASEADDR+204
#define AXI_REG52 XPAR_YDMA_0_BASEADDR+208
#define AXI_REG53 XPAR_YDMA_0_BASEADDR+212
#define AXI_REG54 XPAR_YDMA_0_BASEADDR+216
#define AXI_REG55 XPAR_YDMA_0_BASEADDR+220
#define AXI_REG56 XPAR_YDMA_0_BASEADDR+224
#define AXI_REG57 XPAR_YDMA_0_BASEADDR+228
#define AXI_REG58 XPAR_YDMA_0_BASEADDR+232
#define AXI_REG59 XPAR_YDMA_0_BASEADDR+236
#define AXI_REG60 XPAR_YDMA_0_BASEADDR+240
#define AXI_REG61 XPAR_YDMA_0_BASEADDR+244
#define AXI_REG62 XPAR_YDMA_0_BASEADDR+248
#define AXI_REG63 XPAR_YDMA_0_BASEADDR+252

// =========================================================
// Register map (matches YDMA Verilog):
//   slv_reg0  : control (software-toggled pulses + ap_start level)
//       [0]=winc_wr_addr_len, [1]=winc_wr_data, [2]=winc_rd_addr_len,
//       [3]=rinc_rd_data,     [4]=rinc_wr_resp, [5]=ap_start
//   slv_reg1  : wr_addr[31:0]     (64B-word address; HW shifts <<6)
//   slv_reg2  : wr_len[31:0]      (number of 64B words)
//   slv_reg3..slv_reg18 (16x32)   : wr_data[511:0]
//   slv_reg19 : rd_addr[31:0]
//   slv_reg20 : rd_len[31:0]
//   slv_reg21 : wr_data_be[31:0]
//   slv_reg22 : wr_data_be[63:32]
//   slv_reg32 : status
//       [0]=wfull_wr_addr_len, [1]=wfull_wr_data, [2]=wfull_rd_addr_len,
//       [3]=rempty_rd_data,    [4]=rempty_wr_resp
//   slv_reg33..slv_reg48 (16x32)  : rd_data[511:0] readback
//   slv_reg49 : wr_resp readback
// =========================================================

// Control (slv_reg0) bit positions.
#define CTRL_WINC_WR_ADDR_LEN  0
#define CTRL_WINC_WR_DATA      1
#define CTRL_WINC_RD_ADDR_LEN  2
#define CTRL_RINC_RD_DATA      3
#define CTRL_RINC_WR_RESP      4
#define CTRL_AP_START          5

// Status (slv_reg32) bit positions.
#define ST_WFULL_WR_ADDR_LEN   0
#define ST_WFULL_WR_DATA       1
#define ST_WFULL_RD_ADDR_LEN   2
#define ST_REMPTY_RD_DATA      3
#define ST_REMPTY_WR_RESP      4

// Shadow copy of slv_reg0. The DUT's toggle_detect converts any bit
// transition into a one-cycle winc/rinc pulse, so each push/pop just
// flips the corresponding bit. ap_start (bit 5) is a held level.
static u32 ctrl_shadow = 0;

// Flip one control bit to emit a single pulse on the matching winc/rinc.
static inline void ctrl_pulse(int bit){
	ctrl_shadow ^= (1u << bit);
	Xil_Out32(AXI_REG0, ctrl_shadow);
}

// Set/clear the ap_start level (bit 5), leaving the other bits untouched.
static inline void set_ap_start(int on){
	if (on) ctrl_shadow |=  (1u << CTRL_AP_START);
	else    ctrl_shadow &= ~(1u << CTRL_AP_START);
	Xil_Out32(AXI_REG0, ctrl_shadow);
}

static inline u32 read_status(void){
	return Xil_In32(AXI_REG32);
}

// -------- write-address channel --------
void set_aw_addr_len(unsigned int addr, unsigned int len){
	Xil_Out32(AXI_REG1, addr); // wr_addr  (64B-word units)
	Xil_Out32(AXI_REG2, len);  // wr_len   (number of 64B words)
}

void send_aw(unsigned int addr, unsigned int len){
	// Wait until the wr_addr_len FIFO is not full.
	while (read_status() & (1u << ST_WFULL_WR_ADDR_LEN));
	set_aw_addr_len(addr, len);
	// Push the descriptor (winc_wr_addr_len pulse).
	ctrl_pulse(CTRL_WINC_WR_ADDR_LEN);
}

// -------- write-data channel --------
// Fills all 16 lanes of the 512-bit word with 'data' and sets the 64-bit
// byte-enable to 'be' replicated across both halves.
void set_w_data_be(unsigned int data, unsigned int be){
	Xil_Out32(AXI_REG3,  data);
	Xil_Out32(AXI_REG4,  data+1);
	Xil_Out32(AXI_REG5,  data+2);
	Xil_Out32(AXI_REG6,  data+3);
	Xil_Out32(AXI_REG7,  data+4);
	Xil_Out32(AXI_REG8,  data+5);
	Xil_Out32(AXI_REG9,  data+6);
	Xil_Out32(AXI_REG10, data+7);
	Xil_Out32(AXI_REG11, data+8);
	Xil_Out32(AXI_REG12, data+9);
	Xil_Out32(AXI_REG13, data+10);
	Xil_Out32(AXI_REG14, data+11);
	Xil_Out32(AXI_REG15, data+12);
	Xil_Out32(AXI_REG16, data+13);
	Xil_Out32(AXI_REG17, data+14);
	Xil_Out32(AXI_REG18, data+15);

	Xil_Out32(AXI_REG21, be); // wr_data_be[31:0]
	Xil_Out32(AXI_REG22, be); // wr_data_be[63:32]
}

void send_w(unsigned int data, unsigned int be){
	// Wait until the wr_data FIFO is not full.
	while (read_status() & (1u << ST_WFULL_WR_DATA));
	set_w_data_be(data, be);
	// Push the 512-bit word (winc_wr_data pulse).
	ctrl_pulse(CTRL_WINC_WR_DATA);
}

// -------- read-address channel --------
void set_ar_addr_len(unsigned int addr, unsigned int len){
	Xil_Out32(AXI_REG19, addr); // rd_addr (64B-word units)
	Xil_Out32(AXI_REG20, len);  // rd_len  (number of 64B words)
}

void send_ar(unsigned int addr, unsigned int len){
	// Wait until the rd_addr_len FIFO is not full.
	while (read_status() & (1u << ST_WFULL_RD_ADDR_LEN));
	set_ar_addr_len(addr, len);
	// Push the descriptor (winc_rd_addr_len pulse).
	ctrl_pulse(CTRL_WINC_RD_ADDR_LEN);
}

// -------- write-response drain --------
// Pop one entry from the wr_resp FIFO once it is not empty.
unsigned int wait_wr_resp(void){
	unsigned int resp;
	while (read_status() & (1u << ST_REMPTY_WR_RESP));
	resp = Xil_In32(AXI_REG49);
	// Advance the wr_resp FIFO (rinc_wr_resp pulse).
	ctrl_pulse(CTRL_RINC_WR_RESP);
	return resp;
}

// -------- software read-data check --------
// CPU reads the 512-bit word directly from the DDR buffer (bypassing the
// read-FIFO path) and checks it against the expected ramp.
// Returns the number of mismatched 32-bit lanes for this word (0 = OK).
// Expected lane k == base_val + k.
unsigned int sw_read_word(u32 word[16], int rd_num, unsigned int base_val){
	unsigned int errors = 0;
	int k;

	for (k = 0; k < 16; k++) {
		unsigned int expected = base_val + k;
		if (word[k] != expected) {
			xil_printf("SW MISMATCH rd_num[%08d] lane[%02d] exp=0x%08x act=0x%08x\n\r",
			           rd_num, k, expected, word[k]);
			errors++;
		}
	}
	return errors;
}

// -------- read-data channel --------
// The SynFIFO latches the current head into rdata on each rinc and advances
// the pointer, so we pulse rinc_rd_data first to fetch the word, then read
// back slv_reg33..slv_reg48.
// Returns the number of mismatched 32-bit lanes for this word (0 = OK).
// Expected lane k (reg33+k) == base_val + k.
unsigned int read_word(int rd_num, unsigned int base_val){
	unsigned int lane[16];
	unsigned int errors = 0;
	int k;

	// Wait until the rd_data FIFO is not empty.
	while (read_status() & (1u << ST_REMPTY_RD_DATA));

	// Fetch the head word into the readback registers.
	ctrl_pulse(CTRL_RINC_RD_DATA);

	// Read back all 16 lanes (reg33 = lane0 ... reg48 = lane15).
	lane[0]  = Xil_In32(AXI_REG33);
	lane[1]  = Xil_In32(AXI_REG34);
	lane[2]  = Xil_In32(AXI_REG35);
	lane[3]  = Xil_In32(AXI_REG36);
	lane[4]  = Xil_In32(AXI_REG37);
	lane[5]  = Xil_In32(AXI_REG38);
	lane[6]  = Xil_In32(AXI_REG39);
	lane[7]  = Xil_In32(AXI_REG40);
	lane[8]  = Xil_In32(AXI_REG41);
	lane[9]  = Xil_In32(AXI_REG42);
	lane[10] = Xil_In32(AXI_REG43);
	lane[11] = Xil_In32(AXI_REG44);
	lane[12] = Xil_In32(AXI_REG45);
	lane[13] = Xil_In32(AXI_REG46);
	lane[14] = Xil_In32(AXI_REG47);
	lane[15] = Xil_In32(AXI_REG48);

	// Compare against the expected ramp; print only on mismatch.
	for (k = 0; k < 16; k++) {
		unsigned int expected = base_val + k;
		if (lane[k] != expected) {
			xil_printf("MISMATCH rd_num[%08d] lane[%02d] exp=0x%08x act=0x%08x\n\r",
			           rd_num, k, expected, lane[k]);
			errors++;
		}
	}
	return errors;
}


int main(void)
{
	const unsigned int NUM_WORDS = 1024;   // number of 64B words (wr_len/rd_len)
	const unsigned int BE_ALL    = 0xFFFFFFFF;  // full 64B byte-enable (per half)
	unsigned int i;
	unsigned int total_errors = 0;

	// A 512-bit word = 16 x u32 (64 bytes). Declare a DDR buffer of NUM_WORDS
	// such words, 64-byte aligned so its base is a whole 64B-word address.
	// The datamover takes a 64B-word address (byte address >> 6).
	static u32 buffer[1024][16] __attribute__((aligned(64)));

	// Extract the init (base) address of the array and convert to the HW's
	// 64B-word address units.
	uintptr_t base_byte_addr = (uintptr_t)&buffer[0][0];
	unsigned int BASE_WORD    = (unsigned int)(base_byte_addr >> 6);

	xil_printf("Hello World\n\r");
	xil_printf("buffer base byte addr = 0x%08x, word addr = 0x%08x\n\r",
	           (unsigned int)base_byte_addr, BASE_WORD);

	// Enable the datapath.
	set_ap_start(1);

	// The FPGA datamover accesses DDR directly, bypassing the PS cache.
	// Flush the buffer so the data the HW will read/overwrite is coherent.
	Xil_DCacheFlushRange((UINTPTR)buffer, sizeof(buffer));

	// -------- WRITE: single descriptor (datamover chunks to 1KB bursts) --------
	send_aw(BASE_WORD, NUM_WORDS);
	for (i = 0; i < NUM_WORDS; i++) {
		// Word i, lane k (k=0..15) = i*16 + k, so the whole stream is a
		// monotonically increasing ramp 0,1,2,... Full byte-enable.
		// Expected readback for word i: lane k (reg33+k) == i*16 + k.
		send_w(i*16, BE_ALL);
	}
	wait_wr_resp();

	// HW just wrote the buffer in DDR; drop any stale cached copies before
	// the read-back path (or any CPU access) observes it.
	Xil_DCacheInvalidateRange((UINTPTR)buffer, sizeof(buffer));

	// -------- SW CHECK: CPU reads the DDR buffer directly and checks it ------
	// Validates what the HW datamover actually wrote to memory, independent
	// of the read-FIFO path. Prints only on mismatch.
	{
		unsigned int sw_errors = 0;
		for (i = 0; i < NUM_WORDS; i++) {
			sw_errors += sw_read_word(buffer[i], i, i*16);
		}
		if (sw_errors == 0) {
			xil_printf("SW PASS: all %d words (%d lanes) matched in DDR\n\r",
			           NUM_WORDS, NUM_WORDS*16);
		} else {
			xil_printf("SW FAIL: %d lane mismatches in DDR\n\r", sw_errors);
		}
		total_errors += sw_errors;
	}

	// -------- HW READ: single descriptor, drain and check NUM_WORDS words ----
	// read_word prints only on mismatch; a clean run prints nothing per word.
	send_ar(BASE_WORD, NUM_WORDS);
	for (i = 0; i < NUM_WORDS; i++) {
		total_errors += read_word(i, i*16);
	}

	if (total_errors == 0) {
		xil_printf("PASS: all %d words (%d lanes) matched (SW+HW)\n\r",
		           NUM_WORDS, NUM_WORDS*16);
	} else {
		xil_printf("FAIL: %d lane mismatches (SW+HW)\n\r", total_errors);
	}

	return XST_SUCCESS;
}
