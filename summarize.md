# Project Summary: tt-rv32-vga

## What it is
A Tiny Tapeout chip with:

- a small RV32I CPU
- SPI instruction fetch from an external controller
- a tiny direct-mapped instruction cache
- VGA sync generation for 640x480 @ 60 Hz
- an 80x60 logical canvas with 6-bit color

The current Tiny Tapeout top module is `tt_um_rv32_vga`.

## Current verification status

- VGA sync timing — PASSES
- CPU arithmetic — PASSES
- CPU load/store — PASSES
- CPU branch control flow — PASSES
- Line buffer to VGA output — PASSES

The cocotb regression suite currently passes end-to-end with:

```sh
cd test
PATH=/Users/siriboi/github/tt-stochastic-systolic-vga/.venv312/bin:$PATH make -B SIM=icarus
```

## Architecture notes

- Instructions are fetched over SPI on misses.
- Repeated instruction fetches can hit in the local instruction cache.
- The CPU can write pixels through a memory-mapped line-buffer path.
- Scratchpad RAM is used for local loads/stores.

## Files of interest

| File | Role |
|------|------|
| `src/tt_um_rv32_vga.v` | Top-level integration |
| `src/riscv_cpu.v` | RV32I pipeline |
| `src/spi_instr_fetch.v` | SPI fetch + instruction cache |
| `src/vga_sync.v` | VGA timing |
| `src/line_buffer.v` | Double-buffered scanline storage |
| `test/test.py` | cocotb verification and SPI slave model |
