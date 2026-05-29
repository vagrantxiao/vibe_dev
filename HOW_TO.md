# How to Design an Asynchronous FIFO from Scratch

A step-by-step walkthrough of how this async FIFO was designed, implemented, and verified — from blank module to full regression pass.

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| Vivado 2023.2 | Simulation (via `source /tools/Xilinx/Vitis/2023.2/settings64.sh`) |
| Git | Version control |
| A text editor / VS Code | RTL editing |

---

## Step 1 — Understand the Interface

Start by reading the module skeleton and the testbench before writing a single line of RTL.

```
async_fifo #(DATAWIDTH, ADDRWIDTH) (
    wclk, wrst_n, wrreq, data  → full       // write domain
    rclk, rrst_n, rdreq, q    ← empty      // read domain
)
```

Key observations from the testbench (`tb_top.sv`):
- Write clock period = **6 ns**, read clock period = **10 ns** → write is faster → back-pressure is likely
- `q` is sampled **before** `rdreq` is pulsed → requires **FWFT (First-Word Fall-Through)** read style
- Independent `wrst_n` / `rrst_n` → resets must be handled per domain

---

## Step 2 — Write a Design Document Before Any RTL

Capture all design decisions in a Markdown file (`DESIGN.md`) before coding. Key topics to cover:

### Architecture
```
wclk domain          shared memory         rclk domain
  wbin → wgray ──sync──►               ◄──sync── rgray ← rbin
  full (registered)    dual-port RAM    empty (registered)
```

### Pointer Strategy
- Use `ADDRWIDTH+1` bit pointers — the extra MSB is a **wrap bit** to distinguish full from empty
- Encode pointers in **Gray code** before crossing clock domains (only 1 bit changes per step)

### Full / Empty Conditions (in Gray code)
- **Empty**: `rgray_next == wgray_sync2` — read pointer caught up to write pointer
- **Full**: top 2 bits inverted, lower bits equal — write pointer lapped read pointer:
  ```
  full = { wgray_next[N] != rgray_sync2[N]     }
       & { wgray_next[N-1] != rgray_sync2[N-1] }
       & { wgray_next[N-2:0] == rgray_sync2[N-2:0] }
  ```

### Gray Encoding
$$\text{gray} = \text{bin} \oplus (\text{bin} >> 1)$$

### 2-FF Synchronizer
Each Gray-coded pointer crosses clock domains through two flip-flops clocked in the **destination** domain:
```
gray_ptr → [FF1] → [FF2] → gray_ptr_sync
              (both in destination clock domain)
```

> Commit: `Add async FIFO design notes and milestones` (`6bb3768`)

---

## Step 3 — Define Milestones

Break implementation into incremental steps. Each milestone must be independently runnable and verifiable.

| Milestone | Scope |
|-----------|-------|
| **MS1** | Single-clock functional core — memory, binary counters, FWFT read, stub flags |
| **MS2** | Full CDC — Gray encoding, 2-FF synchronizers, registered full/empty, dual resets |
| **MS3** | Corner case regression — fill-to-full, simultaneous rw, main 2000-item test |

---

## Step 4 — Set Up the Build System

Since Vivado is not on `PATH` by default, source its environment inside the Makefile using `bash -c`:

```makefile
all:
    mkdir -p build
    bash -c "source /tools/Xilinx/Vitis/2023.2/settings64.sh && \
             cd build && vivado -mode batch -source ../run.tcl"
```

The `run.tcl` script creates a project, adds sources, and runs simulation:

```tcl
create_project project_1 project_1 -part xczu9eg-ffvb1156-2-e -force
add_files ../async_fifo.sv
add_files -fileset sim_1 ../tb_top.sv
set_property top tb_top [get_filesets sim_1]
launch_simulation
run all
close_sim
```

Run regression at any time with:
```bash
make all
```

---

## Step 5 — Implement MS1 (Single-Clock Core)

Goal: prove data flows correctly with no CDC complexity.

**Key RTL pieces:**
```systemverilog
// (ADDRWIDTH+1)-bit binary pointers — MSB is wrap bit
logic [ADDRWIDTH:0] wptr, rptr;

// Stub full/empty via direct binary comparison (safe on one clock)
assign empty = (wptr == rptr);
assign full  = (wptr[ADDRWIDTH] != rptr[ADDRWIDTH]) &&
               (wptr[ADDRWIDTH-1:0] == rptr[ADDRWIDTH-1:0]);

// FWFT: combinational read
assign q = mem[rptr[ADDRWIDTH-1:0]];
```

- Write port: synchronous on `wclk`, advances `wptr` when `wrreq & ~full`
- Read port: advances `rptr` on `rclk` when `rdreq & ~empty`
- No Gray code, no synchronizers yet

> Commit: `MS1: single-clock functional core with binary pointers and FWFT read` (`27c2186`)

---

## Step 6 — Implement MS2 (Full CDC)

Goal: replace stub logic with real Gray-code CDC.

**Key changes from MS1:**

1. **Split pointer into binary + Gray:**
```systemverilog
assign wgray_next = (wbin_next >> 1) ^ wbin_next;
```

2. **Add 2-FF synchronizers:**
```systemverilog
// rgray → wclk domain
always_ff @(posedge wclk or negedge wrst_n)
    {rgray_sync2, rgray_sync1} <= {rgray_sync1, rgray};

// wgray → rclk domain
always_ff @(posedge rclk or negedge rrst_n)
    {wgray_sync2, wgray_sync1} <= {wgray_sync1, wgray};
```

3. **Replace stub flags with Gray-based registered flags:**
```systemverilog
// Full (wclk domain)
always_ff @(posedge wclk or negedge wrst_n)
    full <= (wgray_next == {~rgray_sync2[N:N-1], rgray_sync2[N-2:0]});

// Empty (rclk domain), init to 1
always_ff @(posedge rclk or negedge rrst_n)
    empty <= (rgray_next == wgray_sync2);
```

4. **Apply independent async resets** — write-domain FFs use `wrst_n`, read-domain FFs use `rrst_n`

> Commit: `MS2: full CDC implementation with Gray pointers and 2-FF synchronizers` (`6b043b3`)

---

## Step 7 — Implement MS3 (Corner Case Regression)

Extend the testbench with three sequential test cases in a single `initial` block:

### TC1 — Fill-to-full → drain-to-empty
```
1. Disable reader
2. Write DEPTH items → verify full asserts
3. Attempt one extra write → verify it is blocked
4. Enable reader, drain all → verify empty asserts
```

### TC2 — Simultaneous write + read with 1 entry
```
1. Write 1 item (reader off)
2. Assert wrreq and rdreq concurrently
3. Verify no data loss and no spurious empty/full
```

### TC3 — Main regression (2000 random items, wclk > rclk)
```
1. Enable reader
2. Stream 2000 random 32-bit words through FIFO
3. Verify all words arrive in order
4. Verify FIFO is empty at end
```

**Useful testbench patterns:**
- Use a `logic rd_en` flag to start/stop the reader thread between test cases
- Use a `logic [DATAWIDTH-1:0] expected_data[$]` queue to track in-order expected values
- Use a global timeout (`#500_000; $fatal(...)`) to catch deadlocks

> Commit: `MS3: add corner case tests - fill-to-full, simultaneous rw, main regression` (`7642afd`)

---

## Step 8 — Verify Results

```
make all 2>&1 | grep -E "TC|PASS|FAIL|MISMATCH|successfully"
```

Expected output:
```
[165000]    === TC1: Fill-to-full → drain-to-empty ===
[12454000]  TC1: full asserted correctly after 1024 writes
[12460000]  TC1: back-pressure write correctly blocked
[22805000]  TC1: empty asserted correctly after full drain
[22805000]  TC1 PASSED
[22805000]  === TC2: Simultaneous write+read with 1 entry ===
[22995000]  TC2 PASSED
[22995000]  === TC3: Main regression (2000 items) ===
[47525000]  TC3 PASSED
[47525000]  *** All tests completed successfully! sent=3026 rcvd=3026 ***
```

---

## Final Git History

```
7642afd  MS3: add corner case tests - fill-to-full, simultaneous rw, main regression
6b043b3  MS2: full CDC implementation with Gray pointers and 2-FF synchronizers
27c2186  MS1: single-clock functional core with binary pointers and FWFT read
6bb3768  Add async FIFO design notes and milestones
```

---

## Key Lessons

1. **Design before coding** — writing `DESIGN.md` first forces you to resolve Gray-code full/empty logic on paper before debugging it in simulation.
2. **Incremental CDC** — MS1 validates the data path without CDC noise; MS2 adds CDC cleanly on top of a known-good foundation.
3. **FWFT read style** — match the memory read style to your testbench access pattern early; retrofitting it later is painful.
4. **Independent resets** — `wrst_n` and `rrst_n` must only reset FFs in their own clock domain. Crossing reset domains is just as dangerous as crossing data domains.
5. **Gray code only needs 1 bit to change** — this is the entire reason the 2-FF synchronizer is safe. If you use binary pointers across a CDC boundary, you will get metastability.

---

## References

- Clifford Cummings, *"Simulation and Synthesis Techniques for Asynchronous FIFO Design"*, SNUG 2002
- Clifford Cummings, *"Simulation and Synthesis Techniques for Asynchronous FIFO Design with Asynchronous Pointer Comparisons"*, SNUG 2002
