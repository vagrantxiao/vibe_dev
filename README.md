# Asynchronous FIFO

A parameterized, dual-clock asynchronous FIFO implemented in SystemVerilog,
using Gray-code pointers and 2-FF synchronizers for safe clock-domain crossing.

## Architecture

- **Gray-code pointer CDC** — only 1 bit toggles per increment, safe for 2-FF synchronization
- **Dual-port RAM** — synchronous write, asynchronous (combinational) read
- **Conservative flags** — `full`/`empty` may assert early, but never late (no overflow/underflow)
- **ASYNC_REG attributes** — all synchronizer FFs annotated for Vivado place & route

See [async_fifo.md](async_fifo.md) for the full design document.

## Parameters

| Parameter   | Default | Description                            |
|-------------|---------|----------------------------------------|
| `DATAWIDTH` | 8       | Data bus width (bits)                  |
| `ADDRWIDTH` | 4       | Address width → FIFO depth = 2^ADDRWIDTH |

## File Inventory

| File             | Description                                        |
|------------------|----------------------------------------------------|
| `async_fifo.sv`  | RTL — async FIFO with all sub-modules inline       |
| `tb_top.sv`      | SystemVerilog testbench (11 tests, MS2 + MS3)      |
| `run.tcl`        | Vivado TCL — simulation flow                       |
| `run_ms4.tcl`    | Vivado TCL — lint, CDC analysis, synthesis         |
| `Makefile`       | Build targets: `all`, `ms4`, `clean`               |
| `async_fifo.md`  | Design document with architecture, CDC, milestones |
| `reports/`       | Vivado-generated lint/CDC/synthesis reports         |

## Quick Start

### Prerequisites

- Xilinx Vivado 2023.2 (or compatible)
- Source the Vivado environment:
  ```bash
  source /tools/Xilinx/Vivado/2023.2/settings64.sh
  ```

### Run Simulation (11 tests)

```bash
make clean && make all
```

### Run Lint / CDC / Synthesis

```bash
make clean && make ms4
```

Reports are written to `reports/`.

## Test Summary

| Category                | Tests | Status |
|-------------------------|-------|--------|
| Reset sequence          | 1     | ✅     |
| Full flag               | 1     | ✅     |
| Empty flag              | 1     | ✅     |
| Write-then-read (2000w) | 1     | ✅     |
| Simultaneous R/W        | 1     | ✅     |
| Clock ratio sweep (×3)  | 3     | ✅     |
| Back-to-back full→empty | 1     | ✅     |
| Reset during operation  | 1     | ✅     |
| Randomized stimulus     | 1     | ✅     |
| **Total**               | **11**| **✅** |

## Synthesis Results (ZCU102, xczu9eg, default params)

| Resource | Count |
|----------|-------|
| LUTs     | 28    |
| FFs      | 40    |
| BRAM     | 0     |

## License

Internal project — no external license.
