"""Inyecta multiples bytes consecutivos y verifica su recepcion en orden."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestRxMultipleBytesSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        for value in (0x00, 0x3C, 0x81, 0xC3, 0xFF):
            await seqr.agent_uart.send_line_and_capture_parallel(value)


@pyuvm.test(timeout_time=4, timeout_unit="ms")
class TestRxMultipleBytes(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestRxMultipleBytesSeq()
