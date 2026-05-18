![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Stochastic DP Systolic Array VGA Visualizer

Tiny Tapeout starter repository for a systolic-array string-distance accelerator project.

- Project datasheet source: [docs/info.md](docs/info.md)
- Project metadata: [info.yaml](info.yaml)

## Current state

This repo is intentionally a clean scaffold:

- Tiny Tapeout CI workflows are present.
- `info.yaml` points at a new top module.
- The HDL is a minimal placeholder that latches `ui_in` onto `uo_out`.
- The cocotb test is a smoke test only.

## Next steps

1. Replace the placeholder top module in `src/tt_um_siriboi_stochastic_dp.v`.
2. Define the real pinout in `info.yaml`.
3. Update `docs/info.md` with the final architecture.
4. Replace the smoke test with design-specific verification.
