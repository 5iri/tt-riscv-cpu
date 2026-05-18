# Project Summary: Systolic Array VGA System

## What it is
A Tiny Tapeout chip with:

- an 8x8 ternary systolic array computed through a 32-PE pipeline
- VGA sync generation for 640x480 @ 60 Hz
- an 80x60 logical canvas with 6-bit color
- direct rendering of the 8x8 output matrix as a fullscreen heatmap

The current Tiny Tapeout top module is `tt_um_rv32_vga`.

## Current verification status

- VGA sync timing — PASSES
- Mode 0 systolic result matrix — PASSES in cocotb
- Mode switch recompute path — PASSES in cocotb source expectations

The reduced RTL source set compiles locally with:

```sh
iverilog -g2012 -Isrc -s tt_um_rv32_vga src/tt_um_rv32_vga.v src/vga_sync.v src/systolic_array.v src/pe.v
verilator --lint-only -Wall src/tt_um_rv32_vga.v src/vga_sync.v src/systolic_array.v src/pe.v
```

## Architecture notes

- The array uses ternary inputs `{-1,0,1}` with a small signed accumulator.
- A tiny feed controller injects the hardcoded matrices over 7 cycles.
- `ui_in[1:0]` selects the demo matrix pair and retriggers computation.
- The top-level clock target is 50 MHz and is divided internally to 25 MHz for VGA timing.
- Positive outputs map to green, negative outputs to red, and zero outputs to blue.

## Files of interest

| File | Role |
|------|------|
| `src/tt_um_rv32_vga.v` | Top-level integration |
| `src/systolic_array.v` | 4x8 systolic slice used across two passes |
| `src/pe.v` | Processing element |
| `src/vga_sync.v` | VGA timing |
| `test/test.py` | cocotb verification |
