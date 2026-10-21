import cocotb
from enum import IntEnum

from cocotb.queue import Queue

from common.events import EventKind
from helper_classes.monitor import SignalEdgeMonitor


class CommandSignalIndex(IntEnum):
    """Identifica las salidas de control observadas en el decoder."""

    CONFIG_WRITE = 0
    TX_WRITE = 1
    RESPONSE_START = 2


class CommandOutputMonitor:
    """Interpreta flancos del decoder y publica comandos completos."""

    def __init__(self, dut, callback):
        self.dut = dut
        self.callback = callback
        self.observed = Queue()
        self.edge_monitor = SignalEdgeMonitor({
            CommandSignalIndex.CONFIG_WRITE: dut.config_wr_ena_o,
            CommandSignalIndex.TX_WRITE: dut.tx_data_valid_o,
            CommandSignalIndex.RESPONSE_START: dut.response_start_o,
        })

    def start(self):
        self.edge_monitor.start()
        cocotb.start_soon(self.run())

    async def receive(self):
        return await self.observed.get()

    async def run(self):
        # Las escrituras aparecen antes de response_start_o. Sus datos se
        # conservan hasta armar el evento semantico de la respuesta.
        config_write = 0
        config_addr = 0
        config_data = 0
        tx_write = 0
        tx_data = 0

        while True:
            edge_event = await self.edge_monitor.get()

            # Solamente los flancos ascendentes representan pulsos activos.
            if edge_event.value != 1:
                continue

            if edge_event.index == CommandSignalIndex.CONFIG_WRITE:
                config_write = 1
                config_addr = int(self.dut.config_addr_o.value)
                config_data = int(self.dut.config_data_o.value)
            elif edge_event.index == CommandSignalIndex.TX_WRITE:
                tx_write = 1
                tx_data = int(self.dut.tx_data_o.value)
            elif edge_event.index == CommandSignalIndex.RESPONSE_START:
                event = {
                    "command": int(self.dut.response_command_o.value),
                    "status": int(self.dut.response_status_o.value),
                    "data": int(self.dut.response_data_o.value),
                    "config_write": config_write,
                    "config_addr": config_addr,
                    "config_data": config_data,
                    "tx_write": tx_write,
                    "tx_data": tx_data,
                    "time_ns": edge_event.time_ns,
                }
                await self.observed.put(event)
                self.callback(EventKind.COMMAND_OBSERVED, event)
                config_write = 0
                tx_write = 0
