"""Entrega ABC como paquete recibido y verifica su serializacion como evento UART."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest

class TestRxPacketSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_uart_master.send_rx_packet(b"ABC")

@pyuvm.test(timeout_time=3, timeout_unit="ms")
class TestRxPacket(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestRxPacketSeq()
