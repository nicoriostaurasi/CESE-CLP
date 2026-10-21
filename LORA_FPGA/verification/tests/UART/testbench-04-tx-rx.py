"""Alterna transmisiones y recepciones para comprobar ambas direcciones UART."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence

from common_tests.BaseTest import BaseTest


class TestTxRxSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        for tx_value, rx_value in ((0x12, 0x21), (0xA5, 0x5A),
                                   (0x00, 0xFF)):
            await seqr.agent_uart.send_parallel_and_capture_line(tx_value)
            await seqr.agent_uart.send_line_and_capture_parallel(rx_value)


@pyuvm.test(timeout_time=4, timeout_unit="ms")
class TestTxRx(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestTxRxSeq()
