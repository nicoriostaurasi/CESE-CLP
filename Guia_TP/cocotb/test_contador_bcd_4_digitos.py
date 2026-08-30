import cocotb

from cocotb_helpers import clock_cycles, grace_period, start_clock, synchronous_reset


@cocotb.test()
async def test_contador_bcd_4_digitos(dut):
    await start_clock(dut)
    dut.ena.value = 0
    await synchronous_reset(dut)
    assert all(int(signal.value) == 0 for signal in (dut.bcd0, dut.bcd1, dut.bcd2, dut.bcd3))

    await clock_cycles(dut, 1)
    assert all(int(signal.value) == 0 for signal in (dut.bcd0, dut.bcd1, dut.bcd2, dut.bcd3))

    dut.ena.value = 1
    for expected in range(1, 1001):
        await clock_cycles(dut, 1)
        assert int(dut.bcd0.value) == expected % 10
        assert int(dut.bcd1.value) == (expected // 10) % 10
        assert int(dut.bcd2.value) == (expected // 100) % 10
        assert int(dut.bcd3.value) == (expected // 1000) % 10
        assert int(dut.co.value) == 0

    dut.ena.value = 0
    await clock_cycles(dut, 1)
    assert int(dut.bcd3.value) == 1
    assert int(dut.bcd2.value) == 0
    assert int(dut.bcd1.value) == 0
    assert int(dut.bcd0.value) == 0
    await grace_period()
