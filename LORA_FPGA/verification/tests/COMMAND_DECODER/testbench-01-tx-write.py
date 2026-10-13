"""Envia TX_WRITE y verifica que el decoder entregue el byte al buffer de TX."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest
from common.protocol import CMD_TX_WRITE, command_frame

class TestTxWriteSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_command.send_frame(command_frame(CMD_TX_WRITE, 0, ord("A")))

@pyuvm.test(timeout_time=2, timeout_unit="ms")
class TestTxWrite(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestTxWriteSeq()
