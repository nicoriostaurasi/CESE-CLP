from helper_classes.scoreboard.base_scoreboard import BaseScoreboard
from common.events import EventKind


class Sx1278Mockup:
    """Compara frames y payloads esperados con los observados por el agente."""

    def __init__(self):
        self.expected_config = None
        self.expected_tx = None
        self.expected_rx = None

    def assert_event(self, event, source):
        if event.kind is EventKind.CONFIG_REQUESTED:
            values = dict(event.data)
            modem_config_1 = (values[3] << 4) | (values[4] << 1)
            self.expected_config = (values[0], modem_config_1)
        elif event.kind is EventKind.CONFIG_OBSERVED:
            assert event.data == self.expected_config, (
                f"CONFIG esperado={self.expected_config}, obtenido={event.data}")
        elif event.kind is EventKind.TX_REQUESTED:
            self.expected_tx = event.data
        elif event.kind is EventKind.RADIO_TX_OBSERVED:
            assert event.data == self.expected_tx, (
                f"TX esperado={self.expected_tx!r}, obtenido={event.data!r}")
        elif event.kind in (EventKind.RX_INJECTED,
                            EventKind.RADIO_RX_INJECTED):
            self.expected_rx = event.data
        elif event.kind is EventKind.RX_OBSERVED:
            assert event.data == self.expected_rx, (
                f"RX esperado={self.expected_rx!r}, obtenido={event.data!r}")
        else:
            raise AssertionError(f"Evento SX1278 desconocido: {event.kind}")


class Scoreboard(BaseScoreboard):
    def __init__(self, name, parent):
        super().__init__(name, parent, port_names=["sx1278", "spi"])

    def build_phase(self):
        super().build_phase()
        self.dut_mockup = Sx1278Mockup()

    def check_event(self, event, source):
        self.dut_mockup.assert_event(event, source)
