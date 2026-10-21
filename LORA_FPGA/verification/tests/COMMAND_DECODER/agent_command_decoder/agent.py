from cocotb.triggers import FallingEdge, RisingEdge
from helper_classes.agent.base_agent import BaseAgent
from helper_classes.verification_event import VerificationEvent
from pyuvm import uvm_analysis_port
from common.events import EventKind
from .monitors import CommandOutputMonitor


class AgentCommandDecoder(BaseAgent):
    """Excita bytes paralelos y observa la accion semantica del decoder."""

    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut = dut

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.monitor = CommandOutputMonitor(self.dut, self._publish)

    def _publish(self, kind, data):
        self.ap.write(VerificationEvent(kind, data))

    def start_monitor(self):
        self.monitor.start()

    async def send_frame(self, frame):
        self._publish(EventKind.COMMAND_REQUESTED, bytes(frame))
        for value in frame:
            await FallingEdge(self.dut.clk)
            self.dut.uart_data_rx_i.value = value
            self.dut.uart_data_rd_i.value = 1
            await RisingEdge(self.dut.clk)
            await FallingEdge(self.dut.clk)
            self.dut.uart_data_rd_i.value = 0

        await self.monitor.receive()
