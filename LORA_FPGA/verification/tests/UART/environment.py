import cocotb
from cocotb.clock import Clock
from pyuvm import ConfigDB, uvm_env, uvm_sequencer

from agents.agent_uart import AgentUART
from scoreboard import Scoreboard


class Env(uvm_env):
    """Conecta los lados serie y paralelo de myUart."""

    def build_phase(self):
        self.dut = cocotb.top
        self.seqr = uvm_sequencer("seqr", self)
        self.agent_uart = AgentUART("uart_agent", self, self.dut,
                                      line_timing=(9_000, 11_000))
        self.scoreboard = Scoreboard("scoreboard", self)
        self.seqr.agent_uart = self.agent_uart
        ConfigDB().set(None, "*", "SEQR", self.seqr)

    def connect_phase(self):
        self.agent_uart.ap.connect(self.scoreboard.uart_export)

    def start_of_simulation_phase(self):
        self.dut.dataWr.value = 0
        self.dut.dataTx.value = 0
        self.dut.rx.value = 1
        self.dut.rst.value = 0
        cocotb.start_soon(Clock(self.dut.clk, 1, units="us").start())
        self.agent_uart.start_monitors()
