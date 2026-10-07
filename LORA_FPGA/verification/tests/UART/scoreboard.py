from helper_classes.scoreboard.base_scoreboard import BaseScoreboard
from common.events import EventKind


class UartMockup:
    """Compara los bytes ingresados con los obtenidos en ambas direcciones."""

    def __init__(self):
        self.expected_line = []
        self.expected_parallel = []

    def assert_event(self, event, source):
        if event.kind is EventKind.UART_LINE_INPUT:
            self.expected_parallel.append(event.data)
        elif event.kind is EventKind.UART_PARALLEL_OUTPUT:
            expected = self.expected_parallel.pop(0)
            assert event.data == expected, (
                f"UART RX esperado=0x{expected:02X}, obtenido=0x{event.data:02X}")
        elif event.kind is EventKind.UART_PARALLEL_INPUT:
            self.expected_line.append(event.data)
        elif event.kind is EventKind.UART_LINE_OUTPUT:
            expected = self.expected_line.pop(0)
            assert event.data == expected, (
                f"UART TX esperado=0x{expected:02X}, obtenido=0x{event.data:02X}")
        else:
            raise AssertionError(f"Evento UART desconocido: {event.kind}")


class Scoreboard(BaseScoreboard):
    def __init__(self, name, parent):
        super().__init__(name, parent, port_names=["uart"])

    def build_phase(self):
        super().build_phase()
        self.dut_mockup = UartMockup()

    def check_event(self, event, source):
        self.dut_mockup.assert_event(event, source)
