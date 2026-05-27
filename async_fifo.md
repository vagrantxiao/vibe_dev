# Asynchronous FIFO Design Document

## Interface Summary

| Port       | Direction | Width            | Domain | Description                  |
|------------|-----------|------------------|--------|------------------------------|
| `wclk`     | input     | 1                | write  | Write clock                  |
| `wrst_n`   | input     | 1                | write  | Write-domain active-low reset|
| `wrreq`    | input     | 1                | write  | Write request                |
| `data`     | input     | DATAWIDTH        | write  | Write data                   |
| `full`     | output    | 1                | write  | FIFO full flag               |
| `rclk`     | input     | 1                | read   | Read clock                   |
| `rrst_n`   | input     | 1                | read   | Read-domain active-low reset |
| `rdreq`    | input     | 1                | read   | Read request                 |
| `q`        | output    | DATAWIDTH        | read   | Read data output             |
| `empty`    | output    | 1                | read   | FIFO empty flag              |

### Parameters

| Parameter   | Default | Description                                |
|-------------|---------|--------------------------------------------|
| `DATAWIDTH` | 8       | Data bus width                             |
| `ADDRWIDTH` | 4       | Address width → FIFO depth = 2^ADDRWIDTH   |

---

## Architecture: Gray-Code Pointer Async FIFO

This design follows the classic Cliff Cummings approach (SNUG 2002) using Gray-code
pointers synchronized across clock domains.

### Block Diagram

```
  wclk domain                                rclk domain
 ┌──────────────┐                          ┌──────────────┐
 │  wptr_full   │──wptr_gray──►sync_w2r───►│  rptr_empty  │
 │  (wr pointer │◄──sync_r2w◄──rptr_gray───│  (rd pointer │
 │   + full)    │                          │   + empty)   │
 └──────┬───────┘                          └──────┬───────┘
        │ waddr                                   │ raddr
        ▼                                         ▼
 ┌─────────────────────────────────────────────────────────┐
 │                  fifo_mem (dual-port RAM)                │
 └─────────────────────────────────────────────────────────┘
```

### Sub-Modules

| Module       | Clock Domain | Responsibility                                      |
|--------------|--------------|------------------------------------------------------|
| `fifo_mem`   | both         | Dual-port RAM (write on `wclk`, read on `rclk`)     |
| `wptr_full`  | `wclk`       | Write pointer (binary & Gray), full flag generation  |
| `rptr_empty` | `rclk`       | Read pointer (binary & Gray), empty flag generation  |
| `sync_r2w`   | `wclk`       | 2-FF synchronizer: `rptr_gray` → write domain       |
| `sync_w2r`   | `rclk`       | 2-FF synchronizer: `wptr_gray` → read domain        |

---

## Detailed Design

### 1. Dual-Port RAM (`fifo_mem`)

- Size: `2^ADDRWIDTH` entries × `DATAWIDTH` bits.
- Write port: synchronous write on `wclk` when `wrreq && !full`.
- Read port: asynchronous (combinational) read addressed by `raddr`.
- No reset required for memory contents.

### 2. Write Pointer & Full Logic (`wptr_full`)

- Maintains an `(ADDRWIDTH+1)`-bit **binary** write pointer `wbin`.
- The extra MSB is used to distinguish full from empty.
- Converts `wbin` to Gray code: `wgray = wbin ^ (wbin >> 1)`.
- Increments `wbin` on `wrreq && !full`.
- **Full condition** (comparing Gray-code pointers):
  ```
  full = (wgray_next == {~rptr_gray_sync[ADDRWIDTH:ADDRWIDTH-1],
                          rptr_gray_sync[ADDRWIDTH-2:0]})
  ```
  The top two bits of the synchronized read Gray pointer are inverted;
  the remaining bits must match the next write Gray pointer.

### 3. Read Pointer & Empty Logic (`rptr_empty`)

- Maintains an `(ADDRWIDTH+1)`-bit **binary** read pointer `rbin`.
- Converts `rbin` to Gray code: `rgray = rbin ^ (rbin >> 1)`.
- Increments `rbin` on `rdreq && !empty`.
- **Empty condition**:
  ```
  empty = (rgray_next == wptr_gray_sync)
  ```
  The read and (synchronized) write Gray pointers are identical.

### 4. Clock-Domain Crossing Synchronizers

Each synchronizer is a simple 2-flop chain:

```systemverilog
always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        sync1 <= '0;
        sync2 <= '0;
    end else begin
        sync1 <= din;
        sync2 <= sync1;
    end
```

- `sync_r2w`: Synchronizes `rptr_gray` into `wclk` domain → `rptr_gray_sync`.
- `sync_w2r`: Synchronizes `wptr_gray` into `rclk` domain → `wptr_gray_sync`.

Gray code ensures only one bit toggles per pointer increment, making
the 2-FF synchronizer safe (no multi-bit glitch risk).

---

## Why Gray Code?

Binary counters can change multiple bits simultaneously (e.g., `0111 → 1000`
flips all 4 bits). If sampled mid-transition by a synchronizer, an incorrect
intermediate value could be captured. Gray code guarantees exactly **one bit
changes per increment**, eliminating this hazard.

---

## CDC Strategy: Pointer Synchronization In Depth

### The Problem

The write pointer lives in the `wclk` domain, but the **read side** needs it to
compute `empty`. Similarly, the read pointer lives in the `rclk` domain, but the
**write side** needs it to compute `full`. Naively transferring a multi-bit binary
counter across clock domains is **unsafe** because multiple bits can change
simultaneously (e.g., `0111 → 1000` flips all 4 bits), and a synchronizer could
capture a glitched intermediate value.

### The Solution: Gray-Code + 2-FF Synchronizer

#### Step 1 — Gray-Code Encoding

Each pointer is maintained internally as a **binary** counter (for easy address
indexing), but a **Gray-code copy** is computed for CDC:

```
gray = binary ^ (binary >> 1)
```

Gray code guarantees **exactly one bit changes per increment**. This means even if
the synchronizer samples during a transition, it captures either the old value or
the new value — never a corrupted in-between value.

#### Step 2 — 2-FF Synchronizer

The Gray-coded pointer is passed through a **2-stage flip-flop synchronizer**
clocked in the destination domain:

```
  Source Domain            Destination Domain
  ┌──────────┐            ┌──────┐   ┌──────┐
  │ ptr_gray ├───────────►│ FF1  ├──►│ FF2  ├──► ptr_gray_sync
  └──────────┘            └──────┘   └──────┘
                           (dest clk) (dest clk)
```

- **FF1** may go metastable, but has a full clock period to resolve.
- **FF2** captures a stable value with very high probability (MTBF).

#### Step 3 — Use the Synchronized Pointer

- **Write domain** receives `rptr_gray_sync` → compares with `wptr_gray` to
  generate `full`.
- **Read domain** receives `wptr_gray_sync` → compares with `rptr_gray` to
  generate `empty`.

### Safety Analysis

| Concern                | How It's Handled                                                     |
|------------------------|----------------------------------------------------------------------|
| Multi-bit glitch       | Gray code: only 1 bit toggles per increment                         |
| Metastability          | 2-FF synchronizer: MTBF >> system lifetime at typical clock rates   |
| Stale pointer value    | Pessimistic by design (see below)                                   |
| Pointer wrap-around    | Extra `(ADDRWIDTH+1)`-th bit in Gray pointer disambiguates full vs. empty |

### Conservative (Pessimistic) Behavior

The 2-FF synchronizer introduces **2 clock cycles of latency** in the destination
domain. This means:

- `full` may stay asserted **1–2 `wclk` cycles** after space becomes available
  → **conservative, no data loss**.
- `empty` may stay asserted **1–2 `rclk` cycles** after data becomes available
  → **conservative, no underflow**.

A stale `rptr_gray_sync` makes `full` assert *earlier* than necessary (never later).
A stale `wptr_gray_sync` makes `empty` assert *earlier* than necessary (never later).
The FIFO may appear "more full" or "more empty" than reality, but **never overflows
or underflows**. This is a feature, not a bug — the design trades a tiny amount of
throughput for **guaranteed correctness**.

---

## Key Design Constraints

1. **FIFO depth must be a power of 2** — required for Gray-code pointer wrap-around.
2. **Pointer width is `ADDRWIDTH+1`** — the extra bit disambiguates full vs. empty.
3. **Metastability settling** — 2-FF synchronizers assume MTBF is acceptable for
   the target technology and clock frequencies.
4. **Write guard**: data is written only when `wrreq && !full`.
5. **Read guard**: pointer advances only when `rdreq && !empty`.

---

## Implementation Milestones

### Milestone 1 — RTL: Sub-Modules

Implement the five internal sub-modules inside `async_fifo.sv`:

| Task | Deliverable | Done |
|------|-------------|------|
| 1.1  Dual-port RAM (`fifo_mem`) | Parameterized memory with sync write, async read | ✅ |
| 1.2  Write pointer & full logic (`wptr_full`) | Binary/Gray pointer, full flag generation | ✅ |
| 1.3  Read pointer & empty logic (`rptr_empty`) | Binary/Gray pointer, empty flag generation | ✅ |
| 1.4  Synchronizer `sync_r2w` | 2-FF chain: `rptr_gray` → `wclk` domain | ✅ |
| 1.5  Synchronizer `sync_w2r` | 2-FF chain: `wptr_gray` → `rclk` domain | ✅ |
| 1.6  Top-level wiring | Instantiate and connect all sub-modules in `async_fifo` | ✅ |

**Exit criteria**: RTL compiles cleanly with zero errors/warnings. ✅

**Result**: Vivado simulation passed — 2000/2000 random 32-bit words verified
(DATAWIDTH=32, ADDRWIDTH=10, wclk=6ns, rclk=10ns). Zero data mismatches.

---

### Milestone 2 — Basic Testbench

Build a SystemVerilog testbench (`tb_top.sv`) with basic stimulus:

| Task | Deliverable | Done |
|------|-------------|------|
| 2.1  Clock generation | Independent `wclk` (6ns) and `rclk` (10ns) | ✅ |
| 2.2  Reset sequence | Assert both resets, release asynchronously, verify empty=1/full=0 | ✅ |
| 2.3  Write-then-read | Write 2000 words with concurrent reader, verify all data | ✅ |
| 2.4  Full flag test | Write 1024 words until `full` asserts, confirm no overflow | ✅ |
| 2.5  Empty flag test | Read 1024 words until `empty` asserts, confirm no underflow | ✅ |

**Exit criteria**: All basic tests pass with correct data and flag behavior. ✅

**Result**: 4/4 tests passed — reset flags, full flag (1024 writes), empty flag
(1024 reads with data verify), write-then-read (2000 words, zero mismatches).

---

### Milestone 3 — Stress & Corner-Case Testing

| Task | Deliverable | Done |
|------|-------------|------|
| 3.1  Simultaneous read/write | Concurrent R/W with random 0–3 cycle delays, 2000 words | ✅ |
| 3.2  Clock ratio sweep | 3 configs: wclk>>rclk, wclk<<rclk, wclk≈rclk — 1000 words each | ✅ |
| 3.3  Back-to-back full→empty | 4 rapid fill/drain cycles of 1024 words each | ✅ |
| 3.4  Reset during operation | Reset after 100 writes, verify flags, 50 words post-reset | ✅ |
| 3.5  Randomized stimulus | Random write/read timing, 3000 words | ✅ |

**Exit criteria**: Zero data corruption or flag errors across all scenarios. ✅

**Result**: 11/11 tests passed (4 from MS2 + 7 from MS3 including 3 clock-ratio sub-tests).
All scenarios: zero mismatches, correct full/empty flags, clean reset recovery.

---

### Milestone 4 — Lint & CDC Analysis

| Task | Deliverable | Done |
|------|-------------|------|
| 4.1  RTL lint clean | Vivado RTL DRC — 0 violations | ✅ |
| 4.2  CDC report clean | 10 crossings, all Safe, 0 Unsafe, 0 missing ASYNC_REG | ✅ |
| 4.3  Synthesis sanity check | ZCU102 (xczu9eg): 28 LUTs, 40 FFs, 0 BRAM | ✅ |

**Exit criteria**: Clean lint and CDC reports; synthesizable design. ✅

**Result**: 3/3 MS4 checks passed. `ASYNC_REG` attributes added to all synchronizer
FFs. Methodology advisories (22) are all missing I/O delay constraints — expected
for an IP-level module; to be constrained at top-level integration.
Reports: `reports/rtl_drc.rpt`, `reports/cdc_report.rpt`, `reports/synth_utilization.rpt`,
`reports/synth_timing_summary.rpt`, `reports/methodology.rpt`.

---

### Milestone 5 — Documentation & Wrap-Up

| Task | Deliverable | Done |
|------|-------------|------|
| 5.1  Update `async_fifo.md` | Final design doc with any deviations from plan | ☐ |
| 5.2  Update `README.md` | Build/run instructions, file inventory | ☐ |
| 5.3  Final commit & tag | Clean git history, version tag | ☐ |

**Exit criteria**: Complete, reviewable deliverable.

---

## Possible Extensions

- **Almost-full / almost-empty flags**: programmable thresholds for flow control.
- **FIFO occupancy count**: approximate word count (inherently imprecise across domains).
- **First-word-fall-through (FWFT)**: data appears on `q` before `rdreq` is asserted.
- **ECC protection**: error correction on the memory for high-reliability applications.
