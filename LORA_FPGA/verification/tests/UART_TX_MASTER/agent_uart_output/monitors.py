from enum import IntEnum

from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge
from helper_classes.monitor import SignalEdgeMonitor


class UartOutputSignalIndex(IntEnum):
    WRITE = 0


class UartOutputMonitor:
    """Captura bytes solicitados por el master y confirma cada transferencia."""

    def __init__(self, dut):
        self.dut = dut
        self.edge_monitor = SignalEdgeMonitor({
            UartOutputSignalIndex.WRITE: dut.uart_wr_o,
        })
        self.started = False

    def start(self):
        if not self.started:
            self.edge_monitor.start()
            self.started = True

    async def capture(self, expected_length):
        self.start()
        data = []
        while len(data) < expected_length:
            edge_event = await self.edge_monitor.get()
            if edge_event.value != 1:
                continue
            # El flanco de uart_wr_o y el nuevo dato pueden resolverse en el
            # mismo delta de simulacion. ReadOnly espera a que se estabilicen
            # todas las asignaciones combinacionales antes de muestrear.
            await ReadOnly()
            data.append(int(self.dut.uart_data_o.value))
            # uart_wr_o se activa en ST_SEND_BYTE. Se espera el siguiente
            # flanco para que el serializador ingrese en ST_WAIT_BYTE antes
            # de devolver la confirmacion uart_ready_i.
            await RisingEdge(self.dut.clk)
            await FallingEdge(self.dut.clk)
            self.dut.uart_ready_i.value = 1
            await RisingEdge(self.dut.clk)
            await FallingEdge(self.dut.clk)
            self.dut.uart_ready_i.value = 0
        return bytes(data)
