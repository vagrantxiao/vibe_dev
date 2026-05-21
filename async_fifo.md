# Async FIFO Design Notes

## Overview

Designing an asynchronous FIFO from scratch in SystemVerilog, targeting Xilinx ZCU102 (xczu9eg), simulated with Vivado. The DUT is `async_fifo.sv` with parameterizable `DATAWIDTH` and `ADDRWIDTH`. The testbench (`tb_top.sv`) sends 2000 random 32-bit words and verifies read-back correctness across two independent clocks (wclk period=6ns, rclk period=10ns).

## Design Plan

### 1. Dual-Port Memory Array
- `reg [DATAWIDTH-1:0] mem [0:2**ADDRWIDTH-1]`
- Written on `wclk`, read combinatorially for `q` (FWFT style)

### 2. Binary Write/Read Pointers
- `ADDRWIDTH+1`-bit counters (extra bit distinguishes full vs. empty)
- Each counter lives entirely in its own clock domain

### 3. Gray Code Conversion
- XOR-based binary-to-Gray conversion before any CDC crossing
- Avoids multi-bit transitions at the synchronizer input

### 4. Two-FF Synchronizers
- Gray-coded write pointer → synchronized into `rclk` domain
- Gray-coded read pointer → synchronized into `wclk` domain
- Two cascaded flip-flop stages each

### 5. Full / Empty Flag Generation
- `empty`: synchronized write Gray pointer == current read Gray pointer
- `full`: top 2 bits of synchronized read Gray pointer are inverted vs. write pointer, remaining bits match

### 6. Resets
- `wrst_n` resets write-domain logic only
- `rrst_n` resets read-domain logic only
- No shared reset required

## Open Questions / Considerations

- **Read timing**: Testbench reads `q` one cycle after `rdreq` — FWFT (combinatorial read port) preferred.
- **Almost-full/empty**: Not in current port list; easy to add with a threshold offset on pointer comparison.
- **Memory inference**: Vivado will infer BRAM for large depths or distributed RAM for small depths automatically.
