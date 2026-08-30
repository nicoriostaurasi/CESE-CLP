from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


CLK_PERIOD_NS = 10


async def start_clock(dut):
    import cocotb

    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())


async def clock_cycles(dut, cycles):
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    await Timer(1, units="ns")


async def synchronous_reset(dut, cycles=5):
    dut.rst.value = 1
    await clock_cycles(dut, cycles)
    dut.rst.value = 0
    await Timer(1, units="ns")


async def grace_period():
    """Mantiene la simulacion activa 100 ns luego de la ultima prueba."""
    await Timer(100, units="ns")
