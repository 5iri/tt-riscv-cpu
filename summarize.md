# Project Summary: tt-stochastic-systolic-vga

## What it is
A Tiny Tapeout chip: RV32I CPU + VGA sync generator (80×60 canvas @ 640×480 60Hz, 6-bit color). The CPU fetches instructions over SPI from an RP2040.

---

## Test status
- **VGA sync timing** — PASSES ✓ (VSYNC=1600, HSYNC=96 clocks)
- **All CPU tests** — FAILING ✗ (x3=0 instead of 15, etc.)

---

## Root cause (identified, not yet fixed)
All instructions received by the CPU are **right-shifted by 1 bit** (`received = original >> 1`).

**Why:** The SPI fetch module (spi_instr_fetch.v) samples MISO for the first data bit (MSB of instruction) at `cnt=65` (first odd count in data phase). The cocotb SPI slave sets MISO too late — after detecting the falling SCK at `cnt=64` — so the deposit may not propagate before the RTL samples at `cnt=65`.

**Evidence:** `spi_instr=9`, `if_id_instr=0x9` in diagnostics. NOP (0x13) received as 0x09 = 0x13 >> 1. Confirmed for all 6 SPI transactions.

---

## Attempted fix (didn't work)
Pre-set MISO for bit_31 inside the address phase loop when `bits_received == 32` (at rising SCK `cnt=63`), before waiting for falling SCK at `cnt=64`. The deposit still doesn't propagate in time.

---

## What's next
The real fix likely needs to look at the SPI slave from a different angle — possibly using `FallingEdge` triggers instead of polling, or pre-setting MISO even earlier (during the 31st address bit), or understanding why the cocotb deposit isn't being seen by the RTL despite appearing to have enough time.

---

## Files of interest
| File | Role |
|------|------|
| `test/test.py` | cocotb testbench + SPI slave emulator |
| `src/spi_instr_fetch.v` | SPI master (RTL side); samples MISO on odd `cnt` (65, 67, ..., 127) |
| `src/tt_um_siriboi_stochastic_dp.v` | Top level; `spi_miso = uio_in[3]` |
| `src/riscv_cpu.v` | 5-stage pipeline |
