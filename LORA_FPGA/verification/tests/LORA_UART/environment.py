import cocotb
from cocotb.clock import Clock
from pyuvm import ConfigDB, uvm_env, uvm_sequencer

from agents.agent_spi import AgentSPI
from agents.agent_sx1278_control import AgentSX1278Control
from agents.agent_uart import AgentUART
from scoreboard import Scoreboard


class Env(uvm_env):
    """Conecta UART, top, SPI y el agente SX1278."""

    def build_phase(self):
        self.dut = cocotb.top
        self.seqr = uvm_sequencer("seqr", self)
        self.agent_uart = AgentUART("uart_agent", self, self.dut)
        self.agent_spi = AgentSPI("spi_agent", self, self.dut,
                                  radio_model=True,
                                  dio0=self.dut.sx1278_dio0_i,
                                  publish_frames=False)
        self.agent_sx1278 = AgentSX1278Control(
            "sx1278_control_agent", self, self.dut)
        self.scoreboard = Scoreboard("scoreboard", self)
        self.seqr.agent_uart = self.agent_uart
        self.seqr.agent_spi = self.agent_spi
        self.seqr.agent_sx1278 = self.agent_sx1278
        ConfigDB().set(None, "*", "SEQR", self.seqr)

    def connect_phase(self):
        self.agent_uart.ap.connect(self.scoreboard.uart_export)
        self.agent_spi.ap.connect(self.scoreboard.sx1278_export)

    def start_of_simulation_phase(self):
        self.dut.dataWr.value = 0
        self.dut.dataTx.value = 0
        self.dut.sx1278_dio0_i.value = 0
        self.dut.rst.value = 0
        cocotb.start_soon(Clock(self.dut.clk, 100, units="ns").start())
        self.agent_uart.start_monitors()
        self.agent_sx1278.start_monitor()
        cocotb.start_soon(self.agent_spi.monitor.run())
        cocotb.start_soon(self.agent_spi.model.run())
