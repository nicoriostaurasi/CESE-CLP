from cocotb.triggers import FallingEdge, RisingEdge


class Sx1278ControlDriver:
    """Conduce la interfaz paralela de control del sx1278_controller."""

    def __init__(self, dut):
        self.dut = dut

    async def _pulse(self, name):
        await FallingEdge(self.dut.clk)
        getattr(self.dut, name).value = 1
        await RisingEdge(self.dut.clk)
        await FallingEdge(self.dut.clk)
        getattr(self.dut, name).value = 0

    async def configure(self, values):
        for address, value in values:
            self.dut.config_addr_i.value = address
            self.dut.config_data_i.value = value
            await self._pulse("config_wr_ena_i")
        await self._pulse("start_config_i")

    async def begin_tx(self):
        await self._pulse("tx_begin_i")

    async def write_payload(self, payload):
        for value in payload:
            self.dut.tx_data_i.value = value
            await self._pulse("tx_data_valid_i")

    async def start_tx(self):
        await self._pulse("start_tx_i")

    async def start_receive(self):
        await self._pulse("start_rx_i")
