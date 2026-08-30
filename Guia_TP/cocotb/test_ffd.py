import cocotb

from cocotb_helpers import clock_cycles, grace_period, start_clock, synchronous_reset


@cocotb.test()
async def test_ffd(dut):
    await start_clock(dut)
    dut.d.value = 0
    dut.ena.value = 0
    await synchronous_reset(dut)
    assert int(dut.q.value) == 0

    dut.d.value = 1
    dut.ena.value = 1
    await clock_cycles(dut, 1)
    assert int(dut.q.value) == 1
    await grace_period()

    dut.d.value = 0
    dut.ena.value = 0
    await clock_cycles(dut, 1)
    assert int(dut.q.value) == 1

    dut.ena.value = 1
    await clock_cycles(dut, 1)
    assert int(dut.q.value) == 0

    dut.d.value = 1
    await clock_cycles(dut, 1)
    assert int(dut.q.value) == 1
