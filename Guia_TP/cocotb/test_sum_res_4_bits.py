import cocotb
from cocotb.triggers import Timer
from cocotb_helpers import grace_period


SUM_CASES = [(0, 0), (1, 1), (5, 3), (7, 8), (15, 0), (15, 1), (9, 9), (15, 15)]
SUB_CASES = [(0, 0), (7, 3), (15, 1), (8, 8), (3, 5), (0, 1), (2, 9), (15, 0)]


@cocotb.test()
async def test_sum_res_4_bits(dut):
    for sr, cases in ((0, SUM_CASES), (1, SUB_CASES)):
        for a, b in cases:
            dut.sr.value = sr
            dut.a.value = a
            dut.b.value = b
            await Timer(10, units="ns")
            raw = a + b if sr == 0 else a + ((~b) & 0xF) + 1
            assert int(dut.s.value) == raw & 0xF
            assert int(dut.co.value) == (raw >> 4) & 1
    await grace_period()
