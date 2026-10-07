"""Transmite 0x81 desde la interfaz paralela y lo reconstruye sobre la linea UART."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestTxByteSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart.send_parallel_and_capture_line(0x81)


@pyuvm.test(timeout_time=2, timeout_unit="ms")
class TestTxByte(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestTxByteSeq()
