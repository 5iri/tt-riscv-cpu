<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This repository is currently a Tiny Tapeout scaffold for a planned stochastic dynamic-programming accelerator using a systolic array.

The placeholder RTL does one simple thing:

- Latches `ui_in[7:0]` into `uo_out[7:0]` on each clock when `ena` is high.
- Drives all bidirectional pins as inputs.

This is only here to keep the repository buildable while the real architecture is being defined.

## How to test

Run the cocotb smoke test:

```sh
cd test
make -B
```

The current test checks that:

- reset clears outputs
- enabled clocking latches `ui_in` into `uo_out`
- bidirectional pins remain disabled

## External hardware

None for the placeholder design.
