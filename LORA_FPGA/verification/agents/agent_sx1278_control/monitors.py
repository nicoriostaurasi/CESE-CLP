import cocotb
from enum import IntEnum

from cocotb.queue import Queue
from cocotb.triggers import Timer

from helper_classes.monitor import SignalEdgeMonitor


class Sx1278ControlSignalIndex(IntEnum):
    BUSY = 0
    DONE = 1
    RX_PACKET_PENDING = 2


class Sx1278ControlMonitor:
    """Interpreta eventos de handshake del controlador SX1278."""

    def __init__(self, dut):
        self.dut = dut
        self.edge_monitor = SignalEdgeMonitor({
            Sx1278ControlSignalIndex.BUSY: dut.busy_o,
            Sx1278ControlSignalIndex.DONE: dut.done_o,
            Sx1278ControlSignalIndex.RX_PACKET_PENDING:
                dut.rx_packet_pending_o,
        })
        self.idle_events = Queue()
        self.done_events = Queue()
        self.rx_packet_events = Queue()

    def start(self):
        self.edge_monitor.start()
        cocotb.start_soon(self.run())

    async def run(self):
        while True:
            edge_event = await self.edge_monitor.get()
            if (edge_event.index == Sx1278ControlSignalIndex.BUSY and
                    edge_event.value == 0):
                await self.idle_events.put(edge_event)
            elif (edge_event.index == Sx1278ControlSignalIndex.DONE and
                  edge_event.value == 1):
                await self.done_events.put(edge_event)
            elif (edge_event.index ==
                  Sx1278ControlSignalIndex.RX_PACKET_PENDING and
                  edge_event.value == 1):
                await self.rx_packet_events.put(edge_event)

    async def wait_idle(self):
        if int(self.dut.busy_o.value) == 0:
            return
        await self.idle_events.get()

    async def wait_done(self):
        await self.done_events.get()
        return int(self.dut.error_o.value)

    async def wait_rx_packet(self):
        if int(self.dut.rx_packet_pending_o.value) == 0:
            await self.rx_packet_events.get()

    async def read_received(self, length):
        await self.wait_rx_packet()
        payload = []
        for index in range(length):
            self.dut.rx_read_index_i.value = index
            await Timer(1, units="us")
            payload.append(int(self.dut.rx_data_o.value))
        return bytes(payload)
