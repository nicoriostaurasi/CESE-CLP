"""Envia CONFIG_WRITE valido y verifica ACK y pulso de escritura de configuracion."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest
from common.protocol import CMD_CONFIG_WRITE, command_frame

class TestConfigWriteSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_command.send_frame(command_frame(CMD_CONFIG_WRITE, 3, 7))

@pyuvm.test(timeout_time=2, timeout_unit="ms")
class TestConfigWrite(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestConfigWriteSeq()
