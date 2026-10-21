"""Transmite SOL e ING NRT consecutivamente y verifica ambas operaciones completas."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest
from common.protocol import (CMD_CONTROL, CMD_TX_WRITE, CTRL_TX_BEGIN,
                      CTRL_TX_START, command_frame)


class TestConsecutiveTxSeq(uvm_sequence):
    async def send_payload(self, uart_agent, payload):
        await uart_agent.send_command(
            command_frame(CMD_CONTROL, CTRL_TX_BEGIN, 0))
        for value in payload:
            await uart_agent.send_command(
                command_frame(CMD_TX_WRITE, 0, value))
        await uart_agent.send_command(
            command_frame(CMD_CONTROL, CTRL_TX_START, len(payload)))

    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await self.send_payload(seqr.agent_uart, b"SOL")
        await self.send_payload(seqr.agent_uart, b"ING NRT")


@pyuvm.test(timeout_time=30, timeout_unit="ms")
class TestConsecutiveTx(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestConsecutiveTxSeq()
