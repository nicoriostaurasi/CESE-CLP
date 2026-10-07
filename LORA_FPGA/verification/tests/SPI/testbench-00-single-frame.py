"""Carga y transmite una unica trama SPI de dos bytes."""

import pyuvm
from sequences import ResetSequence
from cocotb.triggers import Timer
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest

class TestSingleFrameSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_spi.send_frame(bytes((0x86, 0x6C)))
        await Timer(5, units="us")

@pyuvm.test(timeout_time=2, timeout_unit="ms")
class TestSingleFrame(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestSingleFrameSeq()
