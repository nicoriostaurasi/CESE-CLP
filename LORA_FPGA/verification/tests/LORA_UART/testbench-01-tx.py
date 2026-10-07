"""Carga LORA por UART, inicia TX y verifica el payload observado en el radio."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest
from common.protocol import CMD_CONTROL, CMD_TX_WRITE, CTRL_TX_BEGIN, CTRL_TX_START, command_frame

class TestTxSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart.send_command(command_frame(CMD_CONTROL, CTRL_TX_BEGIN, 0))
        for value in b"LORA":
            await seqr.agent_uart.send_command(command_frame(CMD_TX_WRITE, 0, value))
        await seqr.agent_uart.send_command(command_frame(CMD_CONTROL, CTRL_TX_START, 0))

@pyuvm.test(timeout_time=8, timeout_unit="ms")
class TestTx(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestTxSeq()
