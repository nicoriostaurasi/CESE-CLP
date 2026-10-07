import cocotb
from enum import IntEnum
from cocotb.queue import Queue
from cocotb.triggers import Timer

from common.events import EventKind
from helper_classes.monitor import SignalEdgeMonitor


class UartSignalIndex(IntEnum):
    TX = 0
    DATA_READ = 1


class UartLineMonitor:
    """Reconstruye continuamente los bytes observados sobre TX."""

    def __init__(self, tx, callback, data_period_ns):
        self.tx = tx
        self.callback = callback
        self.data_period_ns = data_period_ns
        self.received = Queue()
        self.edge_monitor = SignalEdgeMonitor({UartSignalIndex.TX: tx})

    def start(self):
        self.edge_monitor.start()
        cocotb.start_soon(self.run())

    async def receive_byte(self):
        return await self.received.get()

    async def run(self):
        while True:
            edge_event = await self.edge_monitor.get()
            if edge_event.value != 0:
                continue
            await Timer(self.data_period_ns + self.data_period_ns // 2,
                        units="ns")
            value = 0
            for bit in range(8):
                value |= int(self.tx.value) << bit
                await Timer(self.data_period_ns, units="ns")
            assert int(self.tx.value) == 1, "Stop bit UART invalido"
            await self.received.put(value)
            self.callback(EventKind.UART_LINE_OUTPUT, value)
            # Durante el muestreo se acumulan los flancos internos de los
            # bits. Ya forman parte del byte reconstruido y no pueden
            # interpretarse como nuevos bits de inicio.
            self.edge_monitor.flush()


class UartParallelMonitor:
    """Observa continuamente dataRd/dataRx del receptor UART."""

    def __init__(self, dut, callback):
        self.dut = dut
        self.callback = callback
        self.received = Queue()
        self.edge_monitor = SignalEdgeMonitor({
            UartSignalIndex.DATA_READ: dut.dataRd,
        })

    def start(self):
        self.edge_monitor.start()
        cocotb.start_soon(self.run())

    async def receive_byte(self):
        return await self.received.get()

    async def run(self):
        while True:
            edge_event = await self.edge_monitor.get()
            if edge_event.value != 1:
                continue
            value = int(self.dut.dataRx.value)
            await self.received.put(value)
            self.callback(EventKind.UART_PARALLEL_OUTPUT, value)
