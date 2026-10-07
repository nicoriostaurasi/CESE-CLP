import cocotb
from cocotb.triggers import FallingEdge, RisingEdge
from helper_classes.agent.base_agent import BaseAgent
from helper_classes.verification_event import VerificationEvent
from pyuvm import uvm_analysis_port
from common.events import EventKind
from .monitors import UartOutputMonitor


class AgentUartOutput(BaseAgent):
    """Presenta respuestas o paquetes y consume la interfaz UART byte a byte."""

    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut = dut

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.monitor = UartOutputMonitor(self.dut)

    def start_monitor(self):
        self.monitor.start()

    async def send_response(self, command, status, data):
        self.monitor.start()
        expected = (command, status, data)
        self.ap.write(VerificationEvent(EventKind.RESPONSE_REQUESTED, expected))
        await FallingEdge(self.dut.clk)
        self.dut.response_command_i.value = command
        self.dut.response_status_i.value = status
        self.dut.response_data_i.value = data
        self.dut.response_start_i.value = 1
        await RisingEdge(self.dut.clk)
        await FallingEdge(self.dut.clk)
        self.dut.response_start_i.value = 0
        frame = await self.monitor.capture(6)
        self.ap.write(VerificationEvent(EventKind.UART_FRAME_OBSERVED, frame))

    async def send_rx_packet(self, payload):
        self.monitor.start()
        self.ap.write(VerificationEvent(EventKind.RX_PACKET_REQUESTED, bytes(payload)))
        self._payload = bytes(payload)
        self.dut.rx_packet_length_i.value = len(payload)
        self.dut.rx_packet_valid_i.value = 1
        task = cocotb.start_soon(self._serve_payload())
        frame = await self.monitor.capture(len(payload) + 5)
        self.dut.rx_packet_valid_i.value = 0
        task.kill()
        self.ap.write(VerificationEvent(EventKind.UART_FRAME_OBSERVED, frame))

    async def _serve_payload(self):
        while True:
            # El indice queda registrado en el flanco ascendente. Se actualiza
            # el dato en el flanco opuesto para que sea estable antes de que
            # el serializador solicite el siguiente byte.
            await FallingEdge(self.dut.clk)
            index = int(self.dut.rx_packet_index_o.value)
            self.dut.rx_packet_data_i.value = self._payload[index] if index < len(self._payload) else 0
