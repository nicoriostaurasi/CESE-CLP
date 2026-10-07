from enum import IntEnum

from helper_classes.monitor import SignalEdgeMonitor
from .utils import SpiFrameEvent


class SpiSignalIndex(IntEnum):
    SCLK = 0
    NSS = 1


class SpiMonitor:
    """Reconstruye frames MOSI/MISO delimitados por NSS."""

    def __init__(self, sclk, mosi, miso, nss, event_callback=None):
        self.sclk = sclk
        self.mosi = mosi
        self.miso = miso
        self.nss = nss
        self.frames = []
        self.event_callback = event_callback
        self.edge_monitor = SignalEdgeMonitor({
            SpiSignalIndex.SCLK: sclk,
            SpiSignalIndex.NSS: nss,
        })

    async def run(self):
        self.edge_monitor.start()
        while True:
            edge_event = await self.edge_monitor.get()
            if (edge_event.index != SpiSignalIndex.NSS or
                    edge_event.value != 0):
                continue

            mosi_bytes = []
            miso_bytes = []
            mosi_byte = 0
            miso_byte = 0
            bit_count = 0

            while True:
                edge_event = await self.edge_monitor.get()
                if (edge_event.index == SpiSignalIndex.NSS and
                        edge_event.value == 1):
                    break
                if (edge_event.index != SpiSignalIndex.SCLK or
                        edge_event.value != 1):
                    continue
                mosi_byte = (mosi_byte << 1) | int(self.mosi.value)
                miso_byte = (miso_byte << 1) | int(self.miso.value)
                bit_count += 1
                if bit_count == 8:
                    mosi_bytes.append(mosi_byte)
                    miso_bytes.append(miso_byte)
                    mosi_byte = 0
                    miso_byte = 0
                    bit_count = 0

            if mosi_bytes:
                event = SpiFrameEvent(bytes(mosi_bytes), bytes(miso_bytes))
                self.frames.append(event)
                if self.event_callback is not None:
                    self.event_callback(event)
