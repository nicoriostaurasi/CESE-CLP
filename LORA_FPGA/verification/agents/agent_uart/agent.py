from cocotb.triggers import FallingEdge, RisingEdge, Timer
from helper_classes.agent.base_agent import BaseAgent
from helper_classes.verification_event import VerificationEvent
from pyuvm import uvm_analysis_port
from common.events import EventKind
from .monitors import UartLineMonitor, UartParallelMonitor


class UartLineAgent:
    """Genera RX y observa TX sobre una UART 8N1."""

    def __init__(self, rx, tx, data_period_ns=9_000, start_period_ns=11_000):
        self.rx = rx
        self.tx = tx
        self.data_period_ns = data_period_ns
        self.start_period_ns = start_period_ns
        self.rx.value = 1

    async def send_byte(self, value):
        self.rx.value = 0
        await Timer(self.start_period_ns, units="ns")
        for bit in range(8):
            self.rx.value = (value >> bit) & 1
            await Timer(self.data_period_ns, units="ns")
        self.rx.value = 1
        await Timer(2 * self.data_period_ns, units="ns")



class UartParallelAgent:
    """Maneja dataWr/dataTx y observa dataRd/dataRx."""

    def __init__(self, dut):
        self.dut = dut

    async def send_byte(self, value):
        await FallingEdge(self.dut.clk)
        self.dut.dataTx.value = value
        self.dut.dataWr.value = 1
        await RisingEdge(self.dut.clk)
        await FallingEdge(self.dut.clk)
        self.dut.dataWr.value = 0
        await RisingEdge(self.dut.ready)



class AgentUART(BaseAgent):
    """Componente UVM con los BFMs serie y paralelo de myUart."""

    def __init__(self, name, parent, dut, line_timing=None):
        super().__init__(name, parent)
        self.dut = dut
        self.line_timing = line_timing

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.parallel = UartParallelAgent(self.dut)
        self.parallel_monitor = UartParallelMonitor(self.dut, self._publish)
        self.line = None
        self.line_monitor = None
        if self.line_timing is not None:
            self.line = UartLineAgent(self.dut.rx, self.dut.tx,
                                      *self.line_timing)
            self.line_monitor = UartLineMonitor(
                self.dut.tx, self._publish, self.line_timing[0])

    def _publish(self, kind, data):
        self.ap.write(VerificationEvent(kind, data))

    def start_monitors(self):
        self.parallel_monitor.start()
        if self.line_monitor is not None:
            self.line_monitor.start()

    async def send_line_and_capture_parallel(self, value):
        self._publish(EventKind.UART_LINE_INPUT, value)
        await self.line.send_byte(value)
        await self.parallel_monitor.receive_byte()

    async def send_parallel_and_capture_line(self, value):
        self._publish(EventKind.UART_PARALLEL_INPUT, value)
        await self.parallel.send_byte(value)
        await self.line_monitor.receive_byte()

    async def send_command(self, frame, response_length=6):
        self._publish(EventKind.UART_COMMAND, bytes(frame))
        for value in frame:
            await self.parallel.send_byte(value)
        response = bytes([await self.parallel_monitor.receive_byte()
                          for _ in range(response_length)])
        self._publish(EventKind.UART_RESPONSE, response)

    async def capture_event(self, length):
        event = bytes([await self.parallel_monitor.receive_byte()
                       for _ in range(length)])
        self._publish(EventKind.UART_ASYNC_EVENT, event)
