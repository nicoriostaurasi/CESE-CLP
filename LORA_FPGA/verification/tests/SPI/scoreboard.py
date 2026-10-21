from helper_classes.scoreboard.base_scoreboard import BaseScoreboard
from common.events import EventKind


class SpiMockup:
    """Modelo de referencia que conserva la secuencia SPI esperada."""

    def __init__(self):
        self.expected = []
        self.observed = []

    def expect_frame(self, frame):
        self.expected.append(bytes(frame))

    def observe_frame(self, frame):
        self.observed.append(bytes(frame))

    def assert_event(self, event, source):
        if event.kind is EventKind.SPI_REQUESTED:
            self.expect_frame(event.data)
        elif event.kind is EventKind.SPI_OBSERVED:
            self.observe_frame(event.data)
            expected = self.expected[len(self.observed)-1]
            assert event.data == expected, (
                f"SPI esperado={expected!r}, observado={event.data!r}")
        else:
            raise AssertionError(f"Evento SPI desconocido: {event.kind}")


class Scoreboard(BaseScoreboard):
    def __init__(self, name, parent):
        super().__init__(name, parent, port_names=["spi"])

    def build_phase(self):
        super().build_phase()
        self.dut_mockup = SpiMockup()

    def check_event(self, event, source):
        self.dut_mockup.assert_event(event, source)
