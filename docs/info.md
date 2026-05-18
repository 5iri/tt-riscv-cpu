<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design, Systolic Array VGA System, is a Tiny Tapeout graphics demo built around an 8x8 ternary systolic array that is computed in two passes using a 4x8 slice with 32 processing elements, plus a VGA generator.

Main blocks:

- A 4x8 systolic slice made of 32 small multiply-accumulate processing elements, reused across two passes to fill an 8x8 result matrix.
- A tiny control path that feeds hardcoded matrix rows and columns into the array.
- A clock divider so the project can accept a 50 MHz top-level clock while VGA still runs at an effective 25 MHz pixel rate.
- A VGA timing generator for 640x480 @ 60 Hz.
- A double line buffer that scan-converts one 80-pixel logical row at a time.
- Direct rendering of the 64 output values as a fullscreen 8x8 heatmap.

The array computes one of several tiny matrix demos selected by `ui_in[1:0]`. Positive outputs are shown in green, negative outputs in red, and zero outputs in blue. VGA output is exposed on the standard Tiny Tapeout PMOD pin mapping.

## How to test

Run the reduced RTL checks:

```sh
iverilog -g2012 -Isrc -s tt_um_rv32_vga src/tt_um_rv32_vga.v src/vga_sync.v src/systolic_array.v src/pe.v
verilator --lint-only -Wall src/tt_um_rv32_vga.v src/vga_sync.v src/systolic_array.v src/pe.v
```

The cocotb tests are intended to check:

- VGA sync pulse timing
- Mode 0 systolic-array output values
- Mode-switch recomputation behavior

## External hardware

No external hardware is required beyond the VGA PMOD connection.

Current user input usage:

- `ui_in[0]`: demo select bit 0
- `ui_in[1]`: demo select bit 1

All `uio` pins are unused in the current design.
