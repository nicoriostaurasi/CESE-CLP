"""Transmite multiples patrones consecutivos por la salida UART."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestTxMultipleBytesSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        for value in (0x00, 0x55, 0xA5, 0x81, 0xFF):
            await seqr.agent_uart.send_parallel_and_capture_line(value)


@pyuvm.test(timeout_time=4, timeout_unit="ms")
class TestTxMultipleBytes(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestTxMultipleBytesSeq()
