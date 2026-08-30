import cocotb
from cocotb.triggers import Timer
from cocotb_helpers import grace_period


@cocotb.test()
async def test_mux_2_a_1(dut):
    for sel in range(2):
        for a in range(2):
            for b in range(2):
                dut.a.value = a
                dut.b.value = b
                dut.sel.value = sel
                await Timer(10, units="ns")
                assert int(dut.mux.value) == (a if sel == 0 else b)
    await grace_period()
