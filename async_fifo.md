# Async FIFO Design Notes

## Overview

Designing an asynchronous FIFO from scratch in SystemVerilog, targeting Xilinx ZCU102 (xczu9eg), simulated with Vivado. The DUT is `async_fifo.sv` with parameterizable `DATAWIDTH` and `ADDRWIDTH`. The testbench (`tb_top.sv`) sends 2000 random 32-bit words and verifies read-back correctness across two independent clocks (wclk period=6ns, rclk period=10ns).

## System Diagram

### Top-Level Block Diagram

```
        WRITE CLOCK DOMAIN                              READ CLOCK DOMAIN
  ┌──────────────────────────────────┐          ┌──────────────────────────────────┐
  │                                  │          │                                  │
  │  wrreq ──►┌──────────────────┐   │          │  ┌──────────────────┐◄── rdreq   │
  │  data  ──►│   Write Pointer  │   │          │  │   Read Pointer   │            │
  │           │   Counter(wclk)  │   │          │  │   Counter(rclk)  │──► q       │
  │           └───┬──────────────┘   │          │  └──────────────┬───┘            │
  │               │ wptr[AW:0]       │          │    rptr[AW:0]   │                │
  │               │ (binary)         │          │    (binary)     │                │
  │               │                  │  ┌─────┐ │                 │                │
  │               ▼                  │  │     │ │                 ▼                │
  │          ┌──────────┐            │  │  D  │ │         ┌──────────┐             │
  │          │ Bin→Gray │            │  │  u  │ │         │ Bin→Gray │             │
  │          └────┬─────┘            │  │  a  │ │         └────┬─────┘             │
  │               │ wptr_g[AW:0]     │  │  l  │ │  rptr_g[AW:0]│                   │
  │         ┌─────┤                  │  │     │ │              ├──────┐            │
  │         │     │                  │  │  P  │ │              │      │            │
  │         │     │  ┌───────────────┼──┼─────┼─┼──────────►   │      │            │
  │         │     │  │ wptr_g        │  │  o  │ │  (2-FF sync  │      │            │
  │         │     │  │ →rclk dom     │  │  r  │ │   into rclk) │      │            │
  │         │     │  │               │  │  t  │ │              ▼      │            │
  │         │     │  │               │  │     │ │        wptr_g_sync  │            │
  │         │     │  │               │  │  M  │ │              │      │            │
  │         │     │◄─┼───────────────┼──┼─────┼─┼────────────  │      │            │
  │         │     │  │ rptr_g        │  │  e  │ │  (2-FF sync  │      │            │
  │         │     │  │ →wclk dom     │  │  m  │ │   into wclk) │      │            │
  │         │     │  │               │  │     │ │              │      │            │
  │         │     ▼  ▼               │  └─────┘ │              ▼      ▼            │
  │         │  rptr_g_sync           │          │        wptr_g_sync  │            │
  │         │     │                  │          │              │      │            │
  │         │     ▼                  │          │              ▼      │            │
  │         │  ┌──────────────┐      │          │   ┌──────────────────┐           │
  │         └─►│  Full Flag   │      │          │   │   Empty Flag     │◄──────────┘
  │            │  Comparator  │      │          │   │   Comparator     │           │
  │            └──────┬───────┘      │          │   └────────┬─────────┘           │
  │                   │              │          │            │                     │
  │              full ▼              │          │            ▼ empty               │
  └──────────────────────────────────┘          └──────────────────────────────────┘
                  wptr[AW-1:0] ──────────────────────────────► mem write addr
                  rptr[AW-1:0] ──────────────────────────────► mem read addr
```

### Pointer & Flag Logic Detail

```
  WRITE CLOCK DOMAIN                              READ CLOCK DOMAIN
  ══════════════════════════════                  ══════════════════════════════

  wptr[AW:0] (binary)                             rptr[AW:0] (binary)
       │                                                │
       │ bin2gray: gray = bin ^ (bin >> 1)              │ bin2gray: gray = bin ^ (bin >> 1)
       ▼                                                ▼
  wptr_g[AW:0] (Gray)                             rptr_g[AW:0] (Gray)
       │                                                │
       │  ┌─────────────────────────────────────────►  │
       │  │       2-FF sync (wptr_g → rclk)            │
       │  │    FF1(rclk) → FF2(rclk) = wptr_g_sync     ▼
       │  │                                       wptr_g_sync[AW:0]  (in rclk domain)
       │  │                                                │
       │  │                                               ─┴──────────────────────────┐
       │  │                                               │    EMPTY comparator        │
       │  │                                               │  (all bits equal?)         │
       │  │                                rptr_g ───────►│  empty = (rptr_g ==        │
       │  │                                               │           wptr_g_sync)     │
       │  │                                               └────────────────────────────┘
       │  │
       │  │  ┌─────────────────────────────────────────
       │  │  │       2-FF sync (rptr_g → wclk)
       │  │  │    FF1(wclk) → FF2(wclk) = rptr_g_sync
       │  │  ▼
       │  rptr_g_sync[AW:0]  (in wclk domain)
       │       │
  ─────┴───────┴──────────────────────────────────────┐
  │         FULL comparator                            │
  │                                                    │
  │  full = (wptr_g[AW]   != rptr_g_sync[AW]  )  &   │  ← top bit inverted
  │         (wptr_g[AW-1] != rptr_g_sync[AW-1])  &   │  ← 2nd bit inverted
  │         (wptr_g[AW-2:0] == rptr_g_sync[AW-2:0])  │  ← lower bits equal
  └────────────────────────────────────────────────────┘

  Note: wptr[AW-1:0] → memory write address  (stays in wclk domain, never crosses CDC)
        rptr[AW-1:0] → memory read address   (stays in rclk domain, never crosses CDC)
        Only Gray-coded pointers cross the clock domain boundary via 2-FF synchronizers.
```

### Memory Read/Write Timing (FWFT)

```
  wclk   ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
           └─┘ └─┘ └─┘ └─┘ └─┘ └─┘
  wrreq  ──────┐     ┌─────┐
               └─────┘     └────────
  data   ──────╠══D0═╣══D1═╣════════
  full   _____________...____________  (goes high when wptr wraps around rptr)

  rclk   ───┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌
            └─┘  └─┘  └─┘  └─┘  └─┘
  empty  ──────────────────...──────  (goes low once wptr_g_sync ≠ rptr_g)
  q      ════════════╠══D0═╣══D1═╣══  (combinatorial, valid when !empty)
  rdreq  ────────────┐     ┌─────┐
                     └─────┘     └──
```

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

## Implementation Milestones

### ✅ Milestone 1 — Dual-Port Memory + Write Path *(DONE)*
- Declared `reg [DATAWIDTH-1:0] mem [0:2**ADDRWIDTH-1]`
- Implemented `wptr` binary counter (ADDRWIDTH+1 bits), increment on `wrreq & !full`
- Write `data` into `mem[wptr[ADDRWIDTH-1:0]]` on rising `wclk`
- Hard-wired `full = 0`, `empty = 1`, `q = 0` as stubs
- **Result**: All 2000 items sent successfully; elaboration clean; `rcvd_count == 0` expected (read side blocked by `empty` stub)

### ✅ Milestone 2 — Read Path *(DONE)*
- Implemented `rptr` binary counter (ADDRWIDTH+1 bits), increment on `rdreq & !empty`
- Drive `q = mem[rptr[ADDRWIDTH-1:0]]` combinatorially (FWFT)
- Kept `full`/`empty` as stubs
- **Result**: Elaboration clean; `rcvd_count == 0` expected (read side still blocked by `empty` stub)
- **Refactor**: Updated to proper SystemVerilog style — `logic` instead of `reg`/`wire`, `always_ff` instead of `always`, `parameter int`, typed port declarations

### ✅ Milestone 3 — Gray Code Conversion + 2-FF Synchronizers *(DONE)*
- Added `wptr_g = wptr ^ (wptr >> 1)` (combinatorial)
- Added `rptr_g = rptr ^ (rptr >> 1)` (combinatorial)
- Added 2-FF synchronizer for `wptr_g → rclk` domain → `wptr_g_sync`
- Added 2-FF synchronizer for `rptr_g → wclk` domain → `rptr_g_sync`
- **Result**: Vivado elaborates clean; all 2000 items sent; `rcvd_count == 0` expected (`empty` stub still `1`)

### Milestone 4 — Empty Flag
- Implement `empty = (rptr_g == wptr_g_sync)` in the read clock domain
- **Acceptance**: `make all` — simulation shows `empty` deasserts after first write and reasserts after last read

### Milestone 5 — Full Flag
- Implement `full` in the write clock domain:
  ```
  full = (wptr_g[AW]     != rptr_g_sync[AW]  ) &
         (wptr_g[AW-1]   != rptr_g_sync[AW-1]) &
         (wptr_g[AW-2:0] == rptr_g_sync[AW-2:0])
  ```
- **Acceptance**: `make all` — simulation shows `full` asserts when FIFO is filled and deasserts after reads; no data loss or mismatch across all 2000 transfers

### Milestone 6 — Full Regression & Cleanup
- Run `make all` end-to-end with `ADDRWIDTH=10`, `DATAWIDTH=32`, `TEST_NUM=2000`
- Confirm: `sent_count == 2000`, `rcvd_count == 2000`, `empty` at end, no data mismatch
- Review reset behaviour: ensure `wrst_n` and `rrst_n` independently reset their domains
- **Acceptance**: `$display("Test completed successfully!")` in simulation log
