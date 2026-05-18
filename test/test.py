"""
Simulation for the RV32I + VGA Tiny Tapeout design.

Tests:
  1. VGA sync timing  — verify hsync/vsync pulse widths.
  2. CPU arithmetic   — x1=5, x2=10, add x3=15 via SPI.
  3. Load/store       — SW then LW round-trip via scratchpad.
  4. Branch taken     — BEQ skips an instruction.
  5. Line buffer/VGA  — CPU writes white to pixel 0, VGA outputs it.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, First

# Cycles per SPI instruction fetch (128 clocks = 64 SCK cycles)
FETCH_CYCLES = 130


# ---------------------------------------------------------------------------
# RISC-V instruction encoders
# ---------------------------------------------------------------------------

def _u32(v):
    return v & 0xFFFFFFFF

def addi(rd, rs1, imm):
    return _u32(((imm & 0xFFF) << 20) | (rs1 << 15) | (rd << 7) | 0x13)

def add(rd, rs1, rs2):
    return _u32((rs2 << 20) | (rs1 << 15) | (rd << 7) | 0x33)

def sw(rs2, imm, rs1):
    hi = (imm >> 5) & 0x7F
    lo = imm & 0x1F
    return _u32((hi << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | (lo << 7) | 0x23)

def sb(rs2, imm, rs1):
    hi = (imm >> 5) & 0x7F
    lo = imm & 0x1F
    return _u32((hi << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (lo << 7) | 0x23)

def lw(rd, imm, rs1):
    return _u32(((imm & 0xFFF) << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0x03)

def beq(rs1, rs2, offset):
    imm = offset & 0x1FFF
    return _u32(((imm >> 12 & 1) << 31) | ((imm >> 5 & 0x3F) << 25) |
                (rs2 << 20) | (rs1 << 15) | ((imm >> 1 & 0xF) << 8) |
                ((imm >> 11 & 1) << 7) | 0x63)

def jal(rd, offset):
    imm = offset & 0x1FFFFF
    return _u32(((imm >> 20 & 1) << 31) | ((imm >> 1 & 0x3FF) << 21) |
                ((imm >> 11 & 1) << 20) | ((imm >> 12 & 0xFF) << 12) |
                (rd << 7) | 0x6F)

def lui(rd, imm):
    return _u32((imm & 0xFFFFF000) | (rd << 7) | 0x37)

def nop():
    return 0x00000013


# ---------------------------------------------------------------------------
# SPI slave: serves instructions from {byte_addr: instr_word} dict
# ---------------------------------------------------------------------------

def _uio(dut, default=0):
    """Read uio_out as int; return default if X/Z values present."""
    try:
        return int(dut.uio_out.value)
    except ValueError:
        return default

def _bit(sig, default=0):
    """Read a 1-bit signal as int; return default if X/Z values present."""
    try:
        return int(sig.value)
    except ValueError:
        return default

async def spi_slave(dut, mem, max_transactions=500):
    """
    Emulates the RP2040 as SPI slave.
    Matches spi_instr_fetch.v protocol:
      - CS_N = uio_out[1]
      - SCK   = uio_out[0]
      - MOSI  = uio_out[2]
      - MISO  = uio_in[3]  (we drive this)

    Address phase (cnt 0..63, 32 SCK rising edges):
      MOSI sampled on rising SCK.
    Data phase (cnt 64..127, 32 SCK rising edges):
      MISO must be stable before rising SCK.
    """
    dut.uio_in.value = 0
    txn = 0
    spi_sck = dut.user_project.spi_fetch.spi_sck
    spi_cs_n = dut.user_project.spi_fetch.spi_cs_n
    spi_mosi = dut.user_project.spi_fetch.spi_mosi

    for _ in range(max_transactions):
        # Wait for the master to start a transaction.
        while _bit(spi_cs_n, default=1) != 0:
            await FallingEdge(spi_cs_n)

        # Receive the 32-bit address exactly on SCK rising edges.
        addr = 0
        addr_aborted = False
        for _ in range(32):
            cs_rise = RisingEdge(spi_cs_n)
            sck_rise = RisingEdge(spi_sck)
            evt = await First(cs_rise, sck_rise)
            if evt is cs_rise:
                addr_aborted = True
                break
            addr = (addr << 1) | _bit(spi_mosi)

        if addr_aborted:
            dut.uio_in.value = 0
            continue

        instr = mem.get(addr, 0x00000013)
        txn += 1
        dut._log.info(f"SPI txn {txn}: addr=0x{addr:08X} -> 0x{instr:08X}")

        # Present bit 31 immediately after the final address edge so it is
        # already stable when the RTL samples on the next SCK rising edge.
        dut.uio_in.value = ((instr >> 31) & 1) << 3

        # Hold each bit through its sampling edge, then advance on the
        # following falling edge to prepare the next bit.
        aborted = False
        for i in range(31):
            cs_rise = RisingEdge(spi_cs_n)
            sck_rise = RisingEdge(spi_sck)
            evt = await First(cs_rise, sck_rise)
            if evt is cs_rise:
                aborted = True
                break

            cs_rise = RisingEdge(spi_cs_n)
            sck_fall = FallingEdge(spi_sck)
            evt = await First(cs_rise, sck_fall)
            if evt is cs_rise:
                aborted = True
                break

            dut.uio_in.value = ((instr >> (30 - i)) & 1) << 3

        # Hold the last bit through the final sample edge, then release MISO
        # once the master ends the transaction.
        while not aborted and _bit(spi_cs_n) == 0:
            await RisingEdge(spi_cs_n)
        dut.uio_in.value = 0


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

async def do_reset(dut, cycles=5):
    dut.rst_n.value  = 0
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, cycles)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

def regfile(dut, n):
    return int(dut.user_project.cpu.rf_inst.register_file[n].value)


# ---------------------------------------------------------------------------
# Test 1: VGA sync timing
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_vga_sync_timing(dut):
    """Verify VSYNC and HSYNC pulse widths (640×480 @ 60 Hz, 25 MHz)."""
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    await do_reset(dut)

    # Wait for VSYNC falling edge (bit 3 of uo_out, active low)
    for _ in range(840 * 530):
        await RisingEdge(dut.clk)
        if not ((int(dut.uo_out.value) >> 3) & 1):
            break
    else:
        assert False, "VSYNC never asserted within one frame"

    # Count VSYNC low duration
    vsync_low = 0
    while True:
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 3) & 1:
            break
        vsync_low += 1

    # 2 lines × 800 pixels/line = 1600 clocks
    assert 1598 <= vsync_low <= 1602, f"VSYNC pulse {vsync_low} clocks (expected 1600)"

    # Find HSYNC falling edge (bit 7, active low)
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

    # 96 pixel clocks
    assert 94 <= hsync_low <= 98, f"HSYNC pulse {hsync_low} clocks (expected 96)"
    dut._log.info(f"VGA OK — VSYNC={vsync_low} HSYNC={hsync_low} clocks")


# ---------------------------------------------------------------------------
# Test 2: CPU arithmetic via SPI
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cpu_arithmetic(dut):
    """addi x1,x0,5 / addi x2,x0,10 / add x3,x1,x2 → expect x3=15."""
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    prog = {
        0x00: addi(1, 0, 5),
        0x04: addi(2, 0, 10),
        0x08: add(3, 1, 2),
        0x0C: jal(0, 0),       # spin
    }
    cocotb.start_soon(spi_slave(dut, prog))
    await do_reset(dut)

    # Monitor RF write port and pipeline stage register values
    prev_rd = -1
    for cyc in range(FETCH_CYCLES * 6 + 20):
        await RisingEdge(dut.clk)
        try:
            wr_en   = int(dut.user_project.cpu.rf_wr_en.value)
            rf_rd   = int(dut.user_project.cpu.rf_rd.value)
            mwb_rd  = int(dut.user_project.cpu.mem_wb_inst.rd_addr_out.value)
            ex_rd   = int(dut.user_project.cpu.ex_mem_inst.rd_addr_out.value)
            idex_rd = int(dut.user_project.cpu.id_ex_inst.rd_addr_out.value)
            if mwb_rd != prev_rd:
                dut._log.info(f"cycle {cyc+1}: wr_en={wr_en} rf_rd={rf_rd} mwb_rd={mwb_rd} ex_rd={ex_rd} idex_rd={idex_rd}")
                prev_rd = mwb_rd
        except Exception as e:
            dut._log.warning(f"signal read error: {e}")
            break

    # Diagnostic: check various signals to identify VPI access issues
    diag = {}
    checks = [
        ("rf_rd",            lambda: int(dut.user_project.cpu.rf_rd.value)),
        ("mwb_rd_addr",      lambda: int(dut.user_project.cpu.mem_wb_inst.rd_addr_out.value)),
        ("idex_rd_addr",     lambda: int(dut.user_project.cpu.id_ex_inst.rd_addr_out.value)),
        ("idex_opcode",      lambda: int(dut.user_project.cpu.id_ex_inst.opcode_out.value)),
        ("pc_out",           lambda: int(dut.user_project.cpu.pc_inst.next_pc.value)),
        ("fetch_busy",       lambda: int(dut.user_project.fetch_busy.value)),
        ("spi_instr",        lambda: int(dut.user_project.spi_fetch.instr.value)),
        ("spi_data_sr",      lambda: hex(int(dut.user_project.spi_fetch.data_sr.value))),
        ("if_id_instr",      lambda: hex(int(dut.user_project.cpu.if_id_inst.instruction_out.value))),
        ("rf_x3",            lambda: int(dut.user_project.cpu.rf_inst.register_file[3].value)),
    ]
    for name, fn in checks:
        try:
            diag[name] = fn()
        except Exception as e:
            diag[name] = f"ERR:{e}"
    dut._log.info(f"Final diagnostics: {diag}")

    x3 = regfile(dut, 3)
    assert x3 == 15, f"Expected x3=15, got {x3}"
    dut._log.info("Arithmetic PASSED: x3=15")


# ---------------------------------------------------------------------------
# Test 3: Load/store round-trip
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cpu_load_store(dut):
    """SW 0x5A → mem[0], LW mem[0] → x2; expect x2=0x5A."""
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    prog = {
        0x00: addi(1, 0, 0x5A),
        0x04: sw(1, 0, 0),
        0x08: lw(2, 0, 0),
        0x0C: jal(0, 0),
    }
    cocotb.start_soon(spi_slave(dut, prog))
    await do_reset(dut)
    await ClockCycles(dut.clk, FETCH_CYCLES * 8 + 30)

    x2 = regfile(dut, 2)
    assert x2 == 0x5A, f"Expected x2=0x5A, got 0x{x2:08X}"
    dut._log.info("Load/store PASSED: x2=0x5A")


# ---------------------------------------------------------------------------
# Test 4: Branch taken
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cpu_branch(dut):
    """BEQ x1,x2 should skip addi x3,x0,0xFF and execute addi x4,x0,1."""
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    prog = {
        0x00: addi(1, 0, 7),
        0x04: addi(2, 0, 7),
        0x08: beq(1, 2, 8),       # branch +8 → 0x10
        0x0C: addi(3, 0, 0xFF),   # skipped
        0x10: addi(4, 0, 1),
        0x14: jal(0, 0),
    }
    cocotb.start_soon(spi_slave(dut, prog))
    await do_reset(dut)
    await ClockCycles(dut.clk, FETCH_CYCLES * 10 + 40)

    x3 = regfile(dut, 3)
    x4 = regfile(dut, 4)
    assert x3 == 0,  f"x3 should be 0 (skipped), got {x3}"
    assert x4 == 1,  f"x4 should be 1, got {x4}"
    dut._log.info("Branch PASSED: branch taken, x3=0 x4=1")


# ---------------------------------------------------------------------------
# Test 5: CPU writes to line buffer, VGA outputs correct color
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_linebuffer_vga(dut):
    """
    CPU writes color 0x3F (full white, 6-bit) to pixel 0 of the line buffer
    at address 0x10000000 via SB. After a canvas-row swap the VGA should
    output 0x3F during the first active pixels.
    """
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    # lui x2, 0x10000000 → x2 = 0x10000000 (line-buffer base)
    prog = {
        0x00: addi(1, 0, 0x3F),
        0x04: lui(2, 0x10000000),
        0x08: sb(1, 0, 2),          # mem[0x10000000] = 0x3F (pixel 0)
        0x0C: jal(0, 0),
    }
    cocotb.start_soon(spi_slave(dut, prog))
    await do_reset(dut)

    # Wait for the CPU to complete the store
    await ClockCycles(dut.clk, FETCH_CYCLES * 5 + 30)

    # Wait for the next buffer swap after the CPU write, then find the first
    # active pixel of the next visible line at canvas_x == 0.
    for _ in range(20_000):
        await RisingEdge(dut.clk)
        if int(dut.user_project.swap.value):
            break
    else:
        assert False, "Timed out waiting for line-buffer swap"

    found_active = False
    for _ in range(10_000):
        await RisingEdge(dut.clk)
        if int(dut.user_project.vga_active.value) and int(dut.user_project.canvas_x.value) == 0:
            # Reconstruct 6-bit color: {R1,G1,B1,R0,G0,B0}
            uo = int(dut.uo_out.value)
            r1 = (uo >> 0) & 1
            g1 = (uo >> 1) & 1
            b1 = (uo >> 2) & 1
            r0 = (uo >> 4) & 1
            g0 = (uo >> 5) & 1
            b0 = (uo >> 6) & 1
            color = (r1 << 5) | (g1 << 4) | (b1 << 3) | (r0 << 2) | (g0 << 1) | b0
            assert color == 0x3F, f"Expected color 0x3F at pixel 0, got 0x{color:02X}"
            found_active = True
            break

    assert found_active, "Never entered active VGA region"
    dut._log.info("Line-buffer PASSED: pixel 0 = 0x3F (white)")
