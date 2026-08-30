import cocotb
from cocotb.triggers import Timer
from cocotb_helpers import grace_period


@cocotb.test()
async def test_barrel_shifter_mux(dut):
    value = 0b10110101
    dut.a.value = value
    for shift in range(8):
        dut.des.value = shift
        await Timer(10, units="ns")
        assert int(dut.s.value) == value >> shift
    await grace_period()
