import cocotb
from cocotb.clock import Clock
from pyuvm import ConfigDB, uvm_env, uvm_sequencer
from agent_uart_output import AgentUartOutput
from scoreboard import Scoreboard


class Env(uvm_env):
    def build_phase(self):
        self.dut = cocotb.top
        self.seqr = uvm_sequencer("seqr", self)
        self.agent = AgentUartOutput("agent_uart_output", self, self.dut)
        self.scoreboard = Scoreboard("scoreboard", self)
        self.seqr.agent_uart_master = self.agent
        ConfigDB().set(None, "*", "SEQR", self.seqr)

    def connect_phase(self):
        self.agent.ap.connect(self.scoreboard.uart_master_export)

    def start_of_simulation_phase(self):
        for name in ("response_start_i", "rx_packet_valid_i", "uart_ready_i"):
            getattr(self.dut, name).value = 0
        self.dut.response_command_i.value = 0
        self.dut.response_status_i.value = 0
        self.dut.response_data_i.value = 0
        self.dut.rx_packet_length_i.value = 0
        self.dut.rx_packet_data_i.value = 0
        self.dut.rst.value = 0
        cocotb.start_soon(Clock(self.dut.clk, 1, units="us").start())
        self.agent.start_monitor()
