"""Altera el checksum de una trama valida y verifica que el decoder responda NACK."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest
from common.protocol import CMD_CONFIG_WRITE, command_frame


class TestBadChecksumSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        frame = bytearray(command_frame(CMD_CONFIG_WRITE, 5, 7))
        frame[4] ^= 0x01
        await seqr.agent_command.send_frame(frame)


@pyuvm.test(timeout_time=2, timeout_unit="ms")
class TestBadChecksum(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestBadChecksumSeq()
