import cocotb
from cocotb.triggers import Timer
from cocotb_helpers import grace_period


@cocotb.test()
async def test_adder_1_bit(dut):
    for a in range(2):
        for b in range(2):
            for ci in range(2):
                dut.a.value = a
                dut.b.value = b
                dut.ci.value = ci
                await Timer(10, units="ns")
                total = a + b + ci
                assert int(dut.s.value) == total % 2
                assert int(dut.co.value) == total // 2
    await grace_period()
