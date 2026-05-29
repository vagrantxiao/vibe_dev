# Async FIFO Design Notes

## 1. Interface Summary

```
async_fifo #(DATAWIDTH, ADDRWIDTH) (
  // Write domain
  wclk, wrst_n, wrreq, data[DATAWIDTH-1:0], full,
  // Read domain
  rclk, rrst_n, rdreq, q[DATAWIDTH-1:0], empty
)
```

- FIFO depth = `2^ADDRWIDTH`
- Testbench uses: `DATAWIDTH=32`, `ADDRWIDTH=10` → **1024 entries × 32b = 32 Kbits**
- Write clock: period 6 ns; Read clock: period 10 ns → **write is faster**

---

## 2. High-Level Architecture

```
         wclk domain                         rclk domain
  ┌──────────────────────┐           ┌──────────────────────┐
  │  wbin (binary ctr)   │           │  rbin (binary ctr)   │
  │  wgray (gray encode) │──sync──►  │  wgray_sync (2-FF)   │
  │  full logic          │           │  empty logic          │
  └──────────┬───────────┘           └──────────┬───────────┘
             │  write port                read port │
             └──────────► dual-port RAM ◄───────────┘
  ┌──────────────────────┐           ┌──────────────────────┐
  │  rgray_sync (2-FF)  ◄──sync──── │  rbin (binary ctr)   │
  │  full logic uses it  │           │  rgray (gray encode) │
  └──────────────────────┘           └──────────────────────┘
```

Key insight: **pointers are the only signals that cross clock domains**, and they are Gray-encoded before crossing.

---

## 3. Pointer Design

### 3.1 Width
Pointers are `ADDRWIDTH+1` bits wide:
- Lower `ADDRWIDTH` bits → actual memory address
- MSB (bit `ADDRWIDTH`) → **wrap/toggle bit** to distinguish Full vs Empty

### 3.2 Binary Counter
Standard synchronous up-counter, increments when:
- Write side: `wrreq & ~full`
- Read side:  `rdreq & ~empty`

### 3.3 Gray Encoding
$$\text{gray}[i] = \text{bin}[i] \oplus \text{bin}[i+1]$$

Equivalently in RTL: `gray = (bin >> 1) ^ bin`

Only **1 bit changes per step** → safe to sample across clock domains via 2-FF synchronizer.

### 3.4 Gray-to-Binary (needed for empty/full logic alternatives)
$$\text{bin}[N] = \text{gray}[N]$$
$$\text{bin}[i] = \text{bin}[i+1] \oplus \text{gray}[i]$$

> Note: For this design, full/empty are computed purely in Gray code, so explicit Gray→Binary conversion is **not required**.

---

## 4. Clock Domain Crossing — 2-FF Synchronizer

```
                 src_clk domain        dst_clk domain
  gray_ptr  ──────────────────► FF1 ──► FF2 ──► gray_ptr_sync
                                 (both FFs in dst_clk domain)
```

- Resolves metastability with high probability
- **Latency**: 2 destination clock cycles (acceptable; only affects when full/empty de-assert)
- One synchronizer per direction: `sync_r2w` and `sync_w2r`

---

## 5. Full Flag Logic

Computed in the **write clock domain** using the synchronized read pointer (`rgray_sync`).

**Condition**: write pointer has "lapped" the read pointer — they point to the same address but the wrap bits differ.

In Gray code, full is detected when the next write Gray pointer (`wgray_next`) equals the synchronized read Gray pointer with the **top 2 bits inverted**:

```
full = (wgray_next[N]   != rgray_sync[N]  ) &&
       (wgray_next[N-1] != rgray_sync[N-1]) &&
       (wgray_next[N-2:0] == rgray_sync[N-2:0])
```

> The 2-bit inversion property holds because of how Gray codes wrap: inverting the top 2 bits of a Gray pointer is equivalent to adding exactly `2^N` in binary (half-depth offset), which is the full condition.

- **Registered** output → no combinational glitch on `full`
- Conservative: `full` may assert 1–2 cycles **later** than strictly necessary (safe — never falsely indicates not-full)

---

## 6. Empty Flag Logic

Computed in the **read clock domain** using the synchronized write pointer (`wgray_sync`).

**Condition**: the next read pointer equals the synchronized write pointer — no more data to read.

```
empty = (rgray_next == wgray_sync)
```

- **Registered** output → clean, glitch-free
- Initialized to `1` on reset
- Conservative: `empty` may de-assert 1–2 cycles **later** than data actually arrives (safe — never falsely indicates data available)

---

## 7. Memory Array

- Simple `reg [DATAWIDTH-1:0] mem [0:DEPTH-1]`
- **Write port**: synchronous, clocked on `wclk`
- **Read port**: two options:

| Style | Read port | `q` updates | TB compatibility |
|-------|-----------|-------------|-----------------|
| **FWFT** (First-Word Fall-Through) | Combinational (`assign q = mem[rbin]`) | Immediately when empty de-asserts | ✅ TB samples `q` before pulsing `rdreq` |
| Standard | Registered (clocked on `rclk`) | 1 cycle after `rdreq` | ❌ Needs TB adjustment |

**→ Use FWFT** to match the testbench read sequence.

---

## 8. Reset Strategy

- `wrst_n` and `rrst_n` are **independent asynchronous active-low resets**
- Write-domain FFs reset by `wrst_n`: `wbin`, `wgray`, `full`, `rgray_sync1/2`
- Read-domain FFs reset by `rrst_n`: `rbin`, `rgray`, `empty`, `wgray_sync1/2`
- Memory contents are **not reset** (don't-care; valid data is gated by pointers)
- TB applies `wrst_n` and `rrst_n` independently — design must handle this correctly

---

## 9. Timing / Latency Analysis

| Event | Latency |
|-------|---------|
| Write → `full` de-asserts after read drains | 2 rclk cycles (sync) + 1 wclk cycle (register) |
| Read → `empty` de-asserts after write fills | 2 wclk cycles (sync) + 1 rclk cycle (register) |
| Write → data appears on `q` (FWFT) | 0 extra rclk cycles (combinational read) |

---

## 10. Edge Cases to Verify

1. **Reset with both domains in reset simultaneously** — all pointers zero, `empty=1`, `full=0`
2. **Fill completely full** — write stops, `full` stays asserted until read pointer advances
3. **Drain completely empty** — `empty` stays asserted until write pointer advances
4. **Single entry FIFO** (`ADDRWIDTH=1`) — full and empty in the same cycle
5. **Simultaneous wrreq + rdreq** — both can proceed when neither full nor empty
6. **Clock ratio stress** — wclk >> rclk causes back-pressure; rclk >> wclk causes underflow risk

---

## 11. Implementation Checklist

- [ ] Dual-port memory array
- [ ] Write binary counter + Gray encoder
- [ ] 2-FF synchronizer: `rgray → wclk`
- [ ] Full flag register (wclk domain)
- [ ] Read binary counter + Gray encoder
- [ ] 2-FF synchronizer: `wgray → rclk`
- [ ] Empty flag register (rclk domain)
- [ ] FWFT combinational read port
- [ ] Lint / simulation clean with testbench

---

## 12. Milestones

### Milestone 1 — Single-Clock Functional Core
**Goal**: Get data flowing correctly before touching CDC at all. Use `wclk` for both domains.
- Dual-port memory array
- Write & read binary counters (no Gray yet)
- FWFT combinational read port (`assign q = mem[rbin]`)
- Stub full/empty with simple binary pointer comparison
- **Done when**: directed simulation shows correct in-order data with no mismatches

---

### Milestone 2 — Full CDC Implementation
**Goal**: Make it a true async FIFO — Gray pointers, 2-FF synchronizers, correct full/empty flags.
- Add Gray encoding to both pointers
- Add 2-FF synchronizers in each direction (`rgray → wclk`, `wgray → rclk`)
- Replace stub flags with proper Gray-based full (top-2-bit inversion) and empty (equality) logic
- Apply independent `wrst_n` / `rrst_n` to correct domains
- **Done when**: simulation is clean with two independent clocks and independent resets

---

### Milestone 3 — Pass Regression & Corner Cases
**Goal**: Validate robustness with the full testbench and stress scenarios.
- Pass `tb_top.sv`: 2000 items, `DATAWIDTH=32`, `ADDRWIDTH=10`, wclk faster than rclk
- Verify fill-to-full → drain-to-empty sequence
- Verify simultaneous `wrreq` + `rdreq` with 1 entry in FIFO
- **Done when**: simulation prints `Test completed successfully!` with no timeouts or mismatches

---

## 13. References

- Clifford Cummings, *"Simulation and Synthesis Techniques for Asynchronous FIFO Design"*, SNUG 2002
- Clifford Cummings, *"Simulation and Synthesis Techniques for Asynchronous FIFO Design with Asynchronous Pointer Comparisons"*, SNUG 2002
