from helper_classes.agent.base_agent import BaseAgent
from helper_classes.verification_event import VerificationEvent
from pyuvm import uvm_analysis_port
from common.events import EventKind
from .drivers import Sx1278ControlDriver
from .monitors import Sx1278ControlMonitor


class AgentSX1278Control(BaseAgent):
    """Maneja solamente la interfaz de control del controlador SX1278."""

    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut = dut

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.driver = Sx1278ControlDriver(self.dut)
        self.monitor = (Sx1278ControlMonitor(self.dut)
                        if hasattr(self.dut, "busy_o") else None)

    def start_monitor(self):
        if self.monitor is not None:
            self.monitor.start()

    async def configure(self, values):
        self.ap.write(VerificationEvent(EventKind.CONFIG_REQUESTED, tuple(values)))
        await self.driver.configure(values)
        await self.monitor.wait_done()
        selected = dict(values)
        observed = (selected[0], (selected[3] << 4) | (selected[4] << 1))
        self.ap.write(VerificationEvent(EventKind.CONFIG_OBSERVED, observed))

    async def transmit(self, payload):
        self.ap.write(VerificationEvent(EventKind.TX_REQUESTED, bytes(payload)))
        await self.monitor.wait_idle()
        await self.driver.begin_tx()
        await self.driver.write_payload(payload)
        await self.monitor.wait_idle()
        await self.driver.start_tx()
        await self.monitor.wait_done()

    async def start_receive(self):
        await self.monitor.wait_idle()
        await self.driver.start_receive()
        await self.monitor.wait_done()

    async def read_received(self, length):
        observed = await self.monitor.read_received(length)
        self.ap.write(VerificationEvent(EventKind.RX_OBSERVED, observed))
