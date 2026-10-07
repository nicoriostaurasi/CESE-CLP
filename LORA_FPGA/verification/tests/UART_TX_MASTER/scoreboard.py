from helper_classes.scoreboard.base_scoreboard import BaseScoreboard
from common.events import EventKind
from common.protocol import response_frame, rx_event_frame


class UartMasterMockup:
    def __init__(self): self.expected = []
    def assert_event(self, event, source):
        if event.kind is EventKind.RESPONSE_REQUESTED:
            self.expected.append(response_frame(*event.data))
        elif event.kind is EventKind.RX_PACKET_REQUESTED:
            self.expected.append(rx_event_frame(event.data))
        elif event.kind is EventKind.UART_FRAME_OBSERVED:
            expected = self.expected.pop(0)
            assert event.data == expected, (
                f"Trama esperada={expected!r}, obtenida={event.data!r}")
        else: raise AssertionError(f"Evento desconocido: {event.kind}")


class Scoreboard(BaseScoreboard):
    def __init__(self, name, parent): super().__init__(name, parent, port_names=["uart_master"])
    def build_phase(self): super().build_phase(); self.dut_mockup = UartMasterMockup()
    def check_event(self, event, source): self.dut_mockup.assert_event(event, source)
