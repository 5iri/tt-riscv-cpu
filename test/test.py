import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

H_TOTAL = 800
CELL_CENTER_X = [80, 240, 400, 560]
CELL_CENTER_Y = [60, 180, 300, 420]


async def do_reset(dut, ui=0, cycles=5):
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = ui
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, cycles)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


def signed(sig):
    return sig.value.signed_integer


def uo_color(uo_out):
    value = int(uo_out.value)
    return (
        ((value >> 0) & 1) << 5 |
        ((value >> 1) & 1) << 4 |
        ((value >> 2) & 1) << 3 |
        ((value >> 4) & 1) << 2 |
        ((value >> 5) & 1) << 1 |
        ((value >> 6) & 1)
    )


def expected_color(entry):
    if entry > 0:
        return 0b000010
    if entry < 0:
        return 0b000100
    return 0b000001


async def wait_until_cycle(dut, current_cycle, target_cycle):
    delta = target_cycle - current_cycle
    assert delta >= 0, f"target cycle {target_cycle} is behind current cycle {current_cycle}"
    if delta:
        await ClockCycles(dut.clk, delta)
    return target_cycle


async def sample_matrix(dut, current_cycle):
    observed = []

    for row, py in enumerate(CELL_CENTER_Y):
        row_values = []
        for col, px in enumerate(CELL_CENTER_X):
            target = py * H_TOTAL + px
            current_cycle = await wait_until_cycle(dut, current_cycle, target)
            row_values.append(uo_color(dut.uo_out))
        observed.append(row_values)

    return observed, current_cycle


@cocotb.test()
async def test_vga_sync_timing(dut):
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut)

    for _ in range(840 * 530):
        await RisingEdge(dut.clk)
        if not ((int(dut.uo_out.value) >> 3) & 1):
            break
    else:
        assert False, "VSYNC never asserted within one frame"

    vsync_low = 0
    while True:
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 3) & 1:
            break
        vsync_low += 1

    assert 1598 <= vsync_low <= 1602, f"VSYNC pulse {vsync_low} clocks"

    for _ in range(1000):
        await RisingEdge(dut.clk)
        if not ((int(dut.uo_out.value) >> 7) & 1):
            break

    hsync_low = 0
    while True:
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 7) & 1:
            break
        hsync_low += 1

    assert 94 <= hsync_low <= 98, f"HSYNC pulse {hsync_low} clocks"


@cocotb.test()
async def test_mode0_identity_result(dut):
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut, ui=0)
    current_cycle = 2

    await ClockCycles(dut.clk, 12)
    current_cycle += 12

    observed, _ = await sample_matrix(dut, current_cycle)
    expected = [
        [1, 0, -1, 1],
        [0, 1, 1, -1],
        [-1, 1, 1, 0],
        [1, -1, 0, 1],
    ]

    for row in range(4):
        for col in range(4):
            assert observed[row][col] == expected_color(expected[row][col]), (
                f"mode0 cell ({row},{col}) expected {expected[row][col]} "
                f"got color 0b{observed[row][col]:06b}"
            )


@cocotb.test()
async def test_mode_switch_recomputes(dut):
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut, ui=0)
    current_cycle = 2
    await ClockCycles(dut.clk, 12)
    current_cycle += 12

    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 12)
    current_cycle += 12

    observed, _ = await sample_matrix(dut, current_cycle)
    expected = [
        [1, -1, 0, 1],
        [-1, 1, 1, 0],
        [0, 1, 1, -1],
        [1, 0, -1, 1],
    ]

    for row in range(4):
        for col in range(4):
            assert observed[row][col] == expected_color(expected[row][col]), (
                f"mode1 cell ({row},{col}) expected {expected[row][col]} "
                f"got color 0b{observed[row][col]:06b}"
            )
