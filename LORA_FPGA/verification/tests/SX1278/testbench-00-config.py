"""Carga registros y verifica la secuencia SPI de configuracion del SX1278."""

import pyuvm
from sequences import ResetSequence
from pyuvm import ConfigDB, uvm_sequence
from common_tests.BaseTest import BaseTest

CONFIG = ((0, 0x6C), (1, 0x40), (2, 0x00), (3, 7), (4, 1),
          (5, 7), (6, 0), (7, 8), (8, 14))

class TestConfigSeq(uvm_sequence):
    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        await ResetSequence("reset_sequence").start(seqr)
        await seqr.agent_sx1278.configure(CONFIG)

@pyuvm.test(timeout_time=6, timeout_unit="ms")
class TestConfig(BaseTest):
    def end_of_elaboration_phase(self):
        self.sequence = TestConfigSeq()
