"""Inyecta un paquete con CRC erroneo y comprueba que se entregue el siguiente valido."""

import pyuvm
from sequences import ResetSequence
from cocotb.triggers import Timer
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest
from common.protocol import CMD_CONTROL, CTRL_RX_START, command_frame


class TestRxCrcRetrySeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart.send_command(
            command_frame(CMD_CONTROL, CTRL_RX_START, 0))
        await seqr.agent_spi.inject_rx(b"BAD", crc_error=True)
        await Timer(500, units="us")
        await seqr.agent_spi.inject_rx(b"ABC")
        await seqr.agent_uart.capture_event(8)


@pyuvm.test(timeout_time=8, timeout_unit="ms")
class TestRxCrcRetry(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestRxCrcRetrySeq()
