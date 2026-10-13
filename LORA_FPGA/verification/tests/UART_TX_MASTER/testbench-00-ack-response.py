"""Solicita una respuesta ACK y verifica la trama UART serializada completa."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest
from common.protocol import CMD_CONTROL, UART_ACK

class TestAckResponseSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart_master.send_response(CMD_CONTROL, UART_ACK, 0x55)

@pyuvm.test(timeout_time=2, timeout_unit="ms")
class TestAckResponse(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestAckResponseSeq()
