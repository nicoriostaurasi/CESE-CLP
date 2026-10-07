import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_sequence


class ResetSequence(uvm_sequence):
    """Aplica el reset global sin requerir un agente dedicado."""

    def __init__(self, name="reset_sequence", cycles=5):
        super().__init__(name)
        self.cycles = cycles

    async def body(self):
        cocotb.top.rst.value = 1
        for _ in range(self.cycles):
            await RisingEdge(cocotb.top.clk)
        cocotb.top.rst.value = 0
        await RisingEdge(cocotb.top.clk)
