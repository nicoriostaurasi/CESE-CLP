import cocotb

from cocotb_helpers import clock_cycles, grace_period, start_clock, synchronous_reset


@cocotb.test()
async def test_reg_desp_comportamiento(dut):
    await start_clock(dut)
    dut.e.value = 0
    await synchronous_reset(dut)
    assert int(dut.s.value) == 0

    for bit, expected in zip((1, 0, 1, 1), (0, 0, 0, 1)):
        dut.e.value = bit
        await clock_cycles(dut, 1)
        assert int(dut.s.value) == expected
    dut.e.value = 0
    for expected in (0, 1, 1, 0):
        await clock_cycles(dut, 1)
        assert int(dut.s.value) == expected
    await grace_period()
