import cocotb
from cocotb.clock import Clock
from pyuvm import ConfigDB, uvm_env, uvm_sequencer

from agents.agent_spi import AgentSPI
from scoreboard import Scoreboard


class Env(uvm_env):
    """Conecta el host, el monitor, el mock SX1278 y el scoreboard."""

    def build_phase(self):
        self.dut = cocotb.top
        self.seqr = uvm_sequencer("seqr", self)
        self.agent_spi = AgentSPI("spi_agent", self, self.dut,
                                  radio_model=True)
        self.scoreboard = Scoreboard("scoreboard", self)
        self.seqr.agent_spi = self.agent_spi
        ConfigDB().set(None, "*", "SEQR", self.seqr)

    def connect_phase(self):
        self.agent_spi.ap.connect(self.scoreboard.spi_export)

    def start_of_simulation_phase(self):
        self.dut.byte_i.value = 0
        self.dut.charge_byte.value = 0
        self.dut.start_spi_transfer.value = 0
        self.dut.rx_ram_read.value = 0
        self.dut.rst.value = 0
        cocotb.start_soon(Clock(self.dut.clk, 1, units="us").start())
        cocotb.start_soon(self.agent_spi.monitor.run())
        cocotb.start_soon(self.agent_spi.model.run())
