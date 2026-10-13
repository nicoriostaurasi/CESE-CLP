"""Reproduce en Cocotb los patrones usados originalmente por el testbench VHDL."""

import pyuvm
from sequences import ResetSequence
from cocotb.triggers import Timer
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestVhdlRegressionSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_spi.send_frame(bytes((0xA5, 0x81, 0x96, 0x3C)))
        await seqr.agent_spi.send_frame(bytes((0x0F, 0xF0)))
        await Timer(5, units="us")


@pyuvm.test(timeout_time=4, timeout_unit="ms")
class TestVhdlRegression(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestVhdlRegressionSeq()
