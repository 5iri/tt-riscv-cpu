import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

N = 8
H_TOTAL = 800
V_TOTAL = 525
CELL_CENTER_X = [5, 15, 25, 35, 45, 55, 65, 75]
CELL_CENTER_Y = [4, 11, 19, 26, 34, 41, 49, 56]
TOP_CLK_PER_PIXEL = 2
FRAME_TOP_CYCLES = H_TOTAL * V_TOTAL * TOP_CLK_PER_PIXEL


async def do_reset(dut, ui=0, cycles=5):
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = ui
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, cycles)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 4)


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


def a_coeff(sel, row, col):
    if sel == 0:
        return 1 if row == col else 0
    if sel == 1:
        return 1 if (row + col) == (N - 1) else 0
    if sel == 2:
        return 1 if ((row + col) & 1) == 0 else 0
    if sel == 3:
        return 1 if row <= col else 0
    raise ValueError(sel)


def b_coeff(sel, row, col):
    if sel in (0, 1):
        if row == col:
            return 1
        if (row + col) == (N - 1):
            return -1
        return 0
    if sel == 2:
        return 1 if row == col else 0
    if sel == 3:
        return -1 if ((row + col) & 1) == 0 else 1
    raise ValueError(sel)


def expected_matrix(sel):
    a = [[a_coeff(sel, row, col) for col in range(N)] for row in range(N)]
    b = [[b_coeff(sel, row, col) for col in range(N)] for row in range(N)]
    c = [[0 for _ in range(N)] for _ in range(N)]

    for row in range(N):
        for col in range(N):
            c[row][col] = sum(a[row][k] * b[k][col] for k in range(N))

    return c


async def wait_until_cycle(dut, current_cycle, target_cycle):
    delta = target_cycle - current_cycle
    assert delta >= 0, f"target cycle {target_cycle} is behind current cycle {current_cycle}"
    if delta:
        await ClockCycles(dut.clk, delta)
    return target_cycle


async def wait_for_display_ready(dut, expected_mode, timeout_cycles=FRAME_TOP_CYCLES * 3):
    for _ in range(timeout_cycles):
        if (
            int(dut.user_project.mode_latched.value) == expected_mode
            and int(dut.user_project.matrix_ready.value)
            and int(dut.user_project.line_initialized.value)
        ):
            return
        await RisingEdge(dut.clk)

    assert False, "display pipeline never became ready"


async def wait_for_frame_origin(dut, timeout_cycles=FRAME_TOP_CYCLES * 2):
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if (
            int(dut.user_project.vga_active.value)
            and int(dut.user_project.vga_px.value) == 0
            and int(dut.user_project.vga_py.value) == 0
        ):
            return 0

    assert False, "never reached active frame origin"


async def wait_for_pin_edge(dut, bit_index, from_level, to_level, timeout_cycles):
    previous = (int(dut.uo_out.value) >> bit_index) & 1

    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        current = (int(dut.uo_out.value) >> bit_index) & 1
        if previous == from_level and current == to_level:
            return
        previous = current

    assert False, f"pin {bit_index} never transitioned {from_level}->{to_level}"


async def wait_for_canvas_position(dut, target_x, target_y, timeout_cycles=FRAME_TOP_CYCLES):
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if (
            int(dut.user_project.vga_active.value)
            and int(dut.user_project.canvas_x.value) == target_x
            and int(dut.user_project.canvas_y.value) == target_y
        ):
            return

    assert False, f"never reached canvas position ({target_x}, {target_y})"


async def sample_matrix(dut):
    observed = []

    for py in CELL_CENTER_Y:
        row_values = []
        for px in CELL_CENTER_X:
            await wait_for_canvas_position(dut, px, py)
            row_values.append(uo_color(dut.uo_out))
        observed.append(row_values)

    return observed


@cocotb.test()
async def test_vga_sync_timing(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut)

    await wait_for_pin_edge(dut, bit_index=3, from_level=1, to_level=0, timeout_cycles=FRAME_TOP_CYCLES * 2)

    vsync_low = 0
    while True:
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 3) & 1:
            break
        vsync_low += 1

    assert 3196 <= vsync_low <= 3204, f"VSYNC pulse {vsync_low} clocks"

    await wait_for_pin_edge(dut, bit_index=7, from_level=1, to_level=0, timeout_cycles=H_TOTAL * TOP_CLK_PER_PIXEL * 2)

    hsync_low = 0
    while True:
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 7) & 1:
            break
        hsync_low += 1

    assert 188 <= hsync_low <= 196, f"HSYNC pulse {hsync_low} clocks"


@cocotb.test()
async def test_mode0_result(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut, ui=0)
    await wait_for_display_ready(dut, expected_mode=0)
    await wait_for_frame_origin(dut)

    observed = await sample_matrix(dut)
    expected = expected_matrix(0)

    for row in range(N):
        for col in range(N):
            assert observed[row][col] == expected_color(expected[row][col]), (
                f"mode0 cell ({row},{col}) expected {expected[row][col]} "
                f"got color 0b{observed[row][col]:06b}"
            )


@cocotb.test()
async def test_mode_switch_recomputes(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut, ui=0)
    await wait_for_display_ready(dut, expected_mode=0)

    dut.ui_in.value = 1
    await wait_for_display_ready(dut, expected_mode=1)
    await wait_for_frame_origin(dut)

    observed = await sample_matrix(dut)
    expected = expected_matrix(1)

    for row in range(N):
        for col in range(N):
            assert observed[row][col] == expected_color(expected[row][col]), (
                f"mode1 cell ({row},{col}) expected {expected[row][col]} "
                f"got color 0b{observed[row][col]:06b}"
            )
