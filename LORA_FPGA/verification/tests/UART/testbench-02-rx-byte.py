"""Inyecta 0xA5 sobre RX y verifica el byte entregado por la interfaz paralela."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestRxByteSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart.send_line_and_capture_parallel(0xA5)


@pyuvm.test(timeout_time=2, timeout_unit="ms")
class TestRxByte(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestRxByteSeq()
