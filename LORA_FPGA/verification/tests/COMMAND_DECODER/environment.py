import cocotb
from cocotb.clock import Clock
from pyuvm import ConfigDB, uvm_env, uvm_sequencer
from agent_command_decoder import AgentCommandDecoder
from scoreboard import Scoreboard


class Env(uvm_env):
    def build_phase(self):
        self.dut = cocotb.top
        self.seqr = uvm_sequencer("seqr", self)
        self.agent = AgentCommandDecoder("agent_command_decoder", self,
                                         self.dut)
        self.scoreboard = Scoreboard("scoreboard", self)
        self.seqr.agent_command = self.agent
        ConfigDB().set(None, "*", "SEQR", self.seqr)

    def connect_phase(self):
        self.agent.ap.connect(self.scoreboard.command_export)

    def start_of_simulation_phase(self):
        self.dut.uart_data_rd_i.value = 0
        self.dut.uart_data_rx_i.value = 0
        self.dut.controller_busy_i.value = 0
        self.dut.peripheral_reset_active_i.value = 0
        self.dut.rst.value = 0
        cocotb.start_soon(Clock(self.dut.clk, 1, units="us").start())
        self.agent.start_monitor()
