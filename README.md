![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# RV32I VGA Visualizer

Tiny Tapeout project for a small RV32I CPU with SPI instruction fetch and VGA output.

- Project datasheet source: [docs/info.md](docs/info.md)
- Project metadata: [info.yaml](info.yaml)

## Current state

This repo contains a working design:

- `tt_um_rv32_vga` is the Tiny Tapeout top module.
- The CPU is a simple 5-stage RV32I core.
- Instructions are fetched over SPI from an external source.
- VGA output is 640x480 @ 60 Hz with an 80x60 logical canvas and 6-bit color.
- The instruction frontend includes a small direct-mapped cache to reduce SPI stalls.
- The cocotb suite covers VGA timing, arithmetic, load/store, branches, and line-buffer output.

## How to test

```sh
cd test
PATH=/Users/siriboi/github/tt-stochastic-systolic-vga/.venv312/bin:$PATH make -B SIM=icarus
```

## External interface

- `uo_out[7:0]` carries the Tiny Tapeout VGA PMOD pinout.
- `uio[0:3]` implement the SPI instruction interface:
  `SCK`, `CS_N`, `MOSI`, `MISO`.
- `ui_in[7:0]` are currently unused.
