import cocotb
from cocotb.triggers import Timer
from cocotb_helpers import grace_period


CASES = [
    (0, 0, 0), (1, 1, 0), (5, 3, 0), (5, 3, 1),
    (7, 1, 0), (15, 0, 1), (9, 9, 0), (15, 15, 1),
]


@cocotb.test()
async def test_adder_4_bits(dut):
    for a, b, ci in CASES:
        dut.a.value = a
        dut.b.value = b
        dut.ci.value = ci
        await Timer(10, units="ns")
        total = a + b + ci
        assert int(dut.s.value) == total & 0xF
        assert int(dut.co.value) == (total >> 4) & 1
    await grace_period()
