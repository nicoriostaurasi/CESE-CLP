"""Transmite dos tramas SPI independientes y verifica sus limites mediante NSS."""

import pyuvm
from sequences import ResetSequence
from cocotb.triggers import Timer
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest

class TestMultipleFramesSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        for frame in (bytes((0x86, 0x6C)), bytes((0x9D, 0x72))):
            await seqr.agent_spi.send_frame(frame)
        await Timer(5, units="us")

@pyuvm.test(timeout_time=3, timeout_unit="ms")
class TestMultipleFrames(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestMultipleFramesSeq()
