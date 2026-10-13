"""Solicita RX, inyecta ABC desde el radio y verifica el evento UART resultante."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest
from common.protocol import CMD_CONTROL, CTRL_RX_START, command_frame

class TestRxSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart.send_command(command_frame(CMD_CONTROL, CTRL_RX_START, 0))
        await seqr.agent_spi.inject_rx(b"ABC")
        await seqr.agent_uart.capture_event(8)

@pyuvm.test(timeout_time=8, timeout_unit="ms")
class TestRx(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestRxSeq()
