"""Reproduce en TX y RX los patrones AA, 00, FF y 55 del testbench VHDL."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestVhdlPatternsSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        for value in (0xAA, 0x00, 0xFF, 0x55):
            await seqr.agent_uart.send_parallel_and_capture_line(value)
            await seqr.agent_uart.send_line_and_capture_parallel(value)


@pyuvm.test(timeout_time=5, timeout_unit="ms")
class TestVhdlPatterns(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestVhdlPatternsSeq()
