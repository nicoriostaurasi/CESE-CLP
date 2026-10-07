"""Cancela una espera RX mediante reset del periferico y comprueba la recuperacion."""

import pyuvm
from sequences import ResetSequence
from cocotb.triggers import Timer
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest
from common.protocol import (CMD_CONFIG_WRITE, CMD_CONTROL, CTRL_RESET_PERIPH,
                      CTRL_RX_START, command_frame)


class TestRxResetCancelSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart.send_command(
            command_frame(CMD_CONTROL, CTRL_RX_START, 0))
        await seqr.agent_uart.send_command(
            command_frame(CMD_CONTROL, CTRL_RESET_PERIPH, 0))
        await Timer(2, units="ms")
        await seqr.agent_uart.send_command(
            command_frame(CMD_CONFIG_WRITE, 5, 7))


@pyuvm.test(timeout_time=8, timeout_unit="ms")
class TestRxResetCancel(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestRxResetCancelSeq()
