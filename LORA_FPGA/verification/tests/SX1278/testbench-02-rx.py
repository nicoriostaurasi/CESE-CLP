"""Inicia recepcion, inyecta ABC y comprueba la lectura del payload recibido."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest

class TestRxSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_sx1278.start_receive()
        await seqr.agent_spi.inject_rx(b"ABC")
        await seqr.agent_sx1278.read_received(3)

@pyuvm.test(timeout_time=5, timeout_unit="ms")
class TestRx(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestRxSeq()
