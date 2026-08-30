import cocotb

from cocotb_helpers import clock_cycles, grace_period, start_clock, synchronous_reset


N = 5


@cocotb.test()
async def test_contador_n_clk(dut):
    await start_clock(dut)
    await synchronous_reset(dut)
    assert int(dut.s.value) == 0

    for cycle in range(1, 3 * N + 1):
        await clock_cycles(dut, 1)
        expected = 1 if cycle % N == N - 1 else 0
        assert int(dut.s.value) == expected
    await grace_period()
