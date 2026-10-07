import cocotb
from cocotb.clock import Clock
from pyuvm import ConfigDB, uvm_env, uvm_sequencer

from agents.agent_spi import AgentSPI
from agents.agent_sx1278_control import AgentSX1278Control
from scoreboard import Scoreboard


class Env(uvm_env):
    """Conecta el controlador con un agente que emula el transceptor."""

    def build_phase(self):
        self.dut = cocotb.top
        self.seqr = uvm_sequencer("seqr", self)
        self.agent_spi = AgentSPI("spi_agent", self, self.dut,
                                  radio_model=True,
                                  dio0=self.dut.sx1278_dio0_i,
                                  publish_frames=False)
        self.agent_sx1278 = AgentSX1278Control(
            "sx1278_control_agent", self, self.dut)
        self.scoreboard = Scoreboard("scoreboard", self)
        self.seqr.agent_sx1278 = self.agent_sx1278
        self.seqr.agent_spi = self.agent_spi
        ConfigDB().set(None, "*", "SEQR", self.seqr)

    def connect_phase(self):
        self.agent_sx1278.ap.connect(self.scoreboard.sx1278_export)
        self.agent_spi.ap.connect(self.scoreboard.spi_export)

    def start_of_simulation_phase(self):
        for name in ("config_wr_ena_i", "start_config_i", "reset_request_i",
                     "tx_begin_i", "tx_data_valid_i", "start_tx_i",
                     "start_rx_i", "rx_packet_sent_i"):
            getattr(self.dut, name).value = 0
        self.dut.config_addr_i.value = 0
        self.dut.config_data_i.value = 0
        self.dut.tx_data_i.value = 0
        self.dut.rx_read_index_i.value = 0
        self.dut.rx_stream_index_i.value = 0
        self.dut.rst.value = 0
        cocotb.start_soon(Clock(self.dut.clk, 1, units="us").start())
        self.agent_sx1278.start_monitor()
        cocotb.start_soon(self.agent_spi.monitor.run())
        cocotb.start_soon(self.agent_spi.model.run())
