<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design is a Tiny Tapeout SoC-style graphics demo built around a small RV32I CPU and a VGA generator.

Main blocks:

- A 5-stage RV32I CPU core.
- An SPI instruction fetch engine that reads 32-bit instructions from an external controller.
- A small direct-mapped instruction cache in front of the SPI fetch path.
- A VGA timing generator for 640x480 @ 60 Hz.
- A double-buffered 80x60 logical canvas with 6-bit color output.
- A small on-chip scratchpad RAM for loads and stores.

The CPU fetches code over SPI and can write pixel values into the line buffer memory-mapped display path. VGA output is exposed on the standard Tiny Tapeout PMOD pin mapping.

## How to test

Run the cocotb regression suite:

```sh
cd test
PATH=/Users/siriboi/github/tt-stochastic-systolic-vga/.venv312/bin:$PATH make -B SIM=icarus
```

The tests currently check:

- VGA sync pulse timing
- CPU arithmetic execution
- CPU load/store behavior
- Taken branch control flow
- CPU writes reaching VGA-visible line-buffer output

## External hardware

An external SPI instruction source is required in real hardware.

Current SPI usage:

- `uio[0]`: SPI `SCK` output
- `uio[1]`: SPI `CS_N` output
- `uio[2]`: SPI `MOSI` output
- `uio[3]`: SPI `MISO` input

The cocotb testbench emulates this instruction source directly.
