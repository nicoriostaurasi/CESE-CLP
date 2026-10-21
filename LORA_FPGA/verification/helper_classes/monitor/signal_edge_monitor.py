import cocotb
from dataclasses import dataclass

from cocotb.queue import Queue
from cocotb.triggers import Edge
from cocotb.utils import get_sim_time


@dataclass(frozen=True)
class SignalMonitorEvent:
    """Cambio observado en una de las señales registradas por el monitor."""

    index: object
    value: int
    time_ns: int


class SignalEdgeMonitor:
    """Publica los cambios de un conjunto indexado de señales del DUT."""

    def __init__(self, signals):
        self.signals = signals
        self.events = Queue()

    def start(self):
        for index, signal in self.signals.items():
            cocotb.start_soon(self._monitor_signal(index, signal))

    async def _monitor_signal(self, index, signal):
        while True:
            await Edge(signal)
            try:
                value = int(signal.value)
            except ValueError:
                continue
            await self.events.put(SignalMonitorEvent(
                index=index,
                value=value,
                time_ns=int(get_sim_time(units="ns")),
            ))

    async def get(self):
        return await self.events.get()

    def flush(self):
        """Descarta cambios acumulados que ya pertenecen al evento actual."""
        while not self.events.empty():
            self.events.get_nowait()
