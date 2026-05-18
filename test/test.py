import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


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

    await ClockCycles(dut.clk, 12)

    assert signed(dut.user_project.c00) == 1
    assert signed(dut.user_project.c01) == 0
    assert signed(dut.user_project.c02) == -1
    assert signed(dut.user_project.c03) == 1
    assert signed(dut.user_project.c10) == 0
    assert signed(dut.user_project.c11) == 1
    assert signed(dut.user_project.c12) == 1
    assert signed(dut.user_project.c13) == -1
    assert signed(dut.user_project.c20) == -1
    assert signed(dut.user_project.c21) == 1
    assert signed(dut.user_project.c22) == 1
    assert signed(dut.user_project.c23) == 0
    assert signed(dut.user_project.c30) == 1
    assert signed(dut.user_project.c31) == -1
    assert signed(dut.user_project.c32) == 0
    assert signed(dut.user_project.c33) == 1


@cocotb.test()
async def test_mode_switch_recomputes(dut):
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut, ui=0)
    await ClockCycles(dut.clk, 12)

    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 12)

    assert signed(dut.user_project.c00) == 1
    assert signed(dut.user_project.c01) == -1
    assert signed(dut.user_project.c02) == 0
    assert signed(dut.user_project.c03) == 1
    assert signed(dut.user_project.c10) == -1
    assert signed(dut.user_project.c11) == 1
    assert signed(dut.user_project.c12) == 1
    assert signed(dut.user_project.c13) == 0
    assert signed(dut.user_project.c20) == 0
    assert signed(dut.user_project.c21) == 1
    assert signed(dut.user_project.c22) == 1
    assert signed(dut.user_project.c23) == -1
    assert signed(dut.user_project.c30) == 1
    assert signed(dut.user_project.c31) == 0
    assert signed(dut.user_project.c32) == -1
    assert signed(dut.user_project.c33) == 1
