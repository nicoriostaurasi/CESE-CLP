from cocotb.triggers import FallingEdge, RisingEdge
from helper_classes.agent.base_agent import BaseAgent
from helper_classes.verification_event import VerificationEvent
from pyuvm import uvm_analysis_port
from common.events import EventKind
from models.sx1278_model import Sx1278Model

from .monitors import SpiMonitor


class SpiFrameHostAgent:
    """Aplica frames a la interfaz paralela del spi_frame_controller."""

    def __init__(self, dut):
        self.dut = dut

    async def send_frame(self, data):
        for value in data:
            await FallingEdge(self.dut.clk)
            self.dut.byte_i.value = value
            self.dut.charge_byte.value = 1
            await RisingEdge(self.dut.clk)
            await FallingEdge(self.dut.clk)
            self.dut.charge_byte.value = 0
        await FallingEdge(self.dut.clk)
        self.dut.start_spi_transfer.value = 1
        await RisingEdge(self.dut.clk)
        await FallingEdge(self.dut.clk)
        self.dut.start_spi_transfer.value = 0
        await RisingEdge(self.dut.done)


class AgentSPI(BaseAgent):
    """Componente UVM que agrupa driver de frames y monitor de pines SPI."""

    def __init__(self, name, parent, dut, radio_model=False, dio0=None,
                 publish_frames=True):
        super().__init__(name, parent)
        self.dut = dut
        self.radio_model_enabled = radio_model
        self.dio0 = dio0
        self.publish_frames = publish_frames

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.driver = SpiFrameHostAgent(self.dut)
        self.monitor = SpiMonitor(self.dut.spi_sclk_o, self.dut.spi_mosi_o,
                                  self.dut.spi_miso_i, self.dut.spi_nss_o,
                                  self._observed_frame)
        self.model = None
        if self.radio_model_enabled:
            self.model = Sx1278Model(
                self.dut.spi_sclk_o, self.dut.spi_mosi_o,
                self.dut.spi_miso_i, self.dut.spi_nss_o, self.dio0,
                tx_callback=self._radio_tx_observed)

    def _observed_frame(self, event):
        if self.publish_frames:
            self.ap.write(VerificationEvent(EventKind.SPI_OBSERVED,
                                            event.mosi))

    def _radio_tx_observed(self, payload):
        self.ap.write(VerificationEvent(EventKind.RADIO_TX_OBSERVED, payload))

    async def send_frame(self, frame):
        self.ap.write(VerificationEvent(EventKind.SPI_REQUESTED, bytes(frame)))
        await self.driver.send_frame(frame)

    async def inject_rx(self, payload, crc_error=False):
        if self.model is None:
            raise RuntimeError("El modelo SX1278 no esta habilitado")
        self.ap.write(VerificationEvent(EventKind.RADIO_RX_INJECTED,
                                        bytes(payload)))
        await self.model.inject_rx(bytes(payload), crc_error=crc_error)
