"""Carga todos los parametros por UART y aplica la configuracion completa por SPI."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest
from common.protocol import CMD_CONFIG_WRITE, CMD_CONTROL, CTRL_APPLY_CONFIG, command_frame

class TestConfigSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        config = ((0, 0x6C), (1, 0x40), (2, 0x00), (3, 7), (4, 1),
                  (5, 7), (6, 0), (7, 8), (8, 14))
        for address, value in config:
            await seqr.agent_uart.send_command(command_frame(CMD_CONFIG_WRITE, address, value))
        await seqr.agent_uart.send_command(command_frame(CMD_CONTROL, CTRL_APPLY_CONFIG, 0))

@pyuvm.test(timeout_time=12, timeout_unit="ms")
class TestConfig(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestConfigSeq()
