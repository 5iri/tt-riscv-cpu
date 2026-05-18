![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Systolic Array VGA System

Tiny Tapeout project for an 8x8 ternary systolic array computed through a 32-PE pipeline and displayed over VGA.

- Project datasheet source: [docs/info.md](docs/info.md)
- Project metadata: [info.yaml](info.yaml)

## Current state

This repo now contains a much smaller design aimed at fitting a 4-tile Tiny Tapeout budget:

- `tt_um_rv32_vga` is the Tiny Tapeout top module.
- The compute block is a two-pass 8x8 ternary systolic array using a 4x8 slice with 32 live PEs.
- The project clock target is 50 MHz, divided by 2 internally to generate the 25 MHz VGA pixel clock.
- VGA output is 640x480 @ 60 Hz with an 80x60 logical canvas and 6-bit color.
- The 64 array outputs are rendered directly as a fullscreen 8x8 heatmap.
- `ui_in[1:0]` select different hardcoded matrix demos.
- The cocotb suite covers VGA timing and array result generation.

## How to test

```sh
cd test
PATH=/Users/siriboi/github/tt-stochastic-systolic-vga/.venv312/bin:$PATH make -B SIM=icarus
```

## External interface

- `uo_out[7:0]` carries the Tiny Tapeout VGA PMOD pinout.
- `ui_in[1:0]` select the matrix demo mode.
- `uio[7:0]` are currently unused.
