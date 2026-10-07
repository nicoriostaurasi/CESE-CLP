"""Carga el payload TP y verifica la secuencia completa de transmision SX1278."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest

class TestTxSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_sx1278.transmit(b"TP")

@pyuvm.test(timeout_time=4, timeout_unit="ms")
class TestTx(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestTxSeq()
