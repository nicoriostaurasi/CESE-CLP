"""Reproduce la transmision A5 96 81 del testbench VHDL original."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestVhdlTxSequenceSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_sx1278.transmit(bytes((0xA5, 0x96, 0x81)))


@pyuvm.test(timeout_time=4, timeout_unit="ms")
class TestVhdlTxSequence(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestVhdlTxSequenceSeq()
