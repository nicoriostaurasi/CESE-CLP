from helper_classes.scoreboard.base_scoreboard import BaseScoreboard
from common.events import EventKind
from common.protocol import (CMD_CONFIG_WRITE, CMD_CONTROL, CMD_TX_WRITE,
                      CTRL_TX_BEGIN, CTRL_TX_START, UART_ACK, UART_EVENT_RX_PACKET,
                      response_frame, rx_event_frame)


class LoraUartMockup:
    """Compara respuestas UART y payloads LoRa extremo a extremo."""

    def __init__(self):
        self.expected_uart = []
        self.tx_payload = bytearray()
        self.expected_radio_tx = None
        self.expected_uart_event = None

    def assert_event(self, event, source):
        if event.kind is EventKind.UART_COMMAND:
            _, command, parameter, value, _, _ = event.data
            # El decoder devuelve en el ACK el campo VALUE recibido, también
            # para comandos de control como TX_START (longitud del payload).
            data = value
            if command == CMD_CONTROL and parameter == CTRL_TX_BEGIN:
                self.tx_payload.clear()
            if command == CMD_TX_WRITE:
                self.tx_payload.append(value)
            if command == CMD_CONTROL and parameter == CTRL_TX_START:
                self.expected_radio_tx = bytes(self.tx_payload)
            self.expected_uart.append(response_frame(command, UART_ACK, data))
        elif event.kind is EventKind.UART_RESPONSE:
            expected = self.expected_uart.pop(0)
            assert event.data == expected, (
                f"Respuesta UART esperada={expected!r}, obtenida={event.data!r}")
        elif event.kind is EventKind.RADIO_TX_OBSERVED:
            assert event.data == self.expected_radio_tx, (
                f"LoRa TX esperado={self.expected_radio_tx!r}, "
                f"obtenido={event.data!r}")
        elif event.kind is EventKind.RADIO_RX_INJECTED:
            self.expected_uart_event = rx_event_frame(event.data)
        elif event.kind is EventKind.UART_ASYNC_EVENT:
            assert event.data == self.expected_uart_event, (
                f"Evento RX esperado={self.expected_uart_event!r}, "
                f"obtenido={event.data!r}")
        elif event.kind is EventKind.UART_PARALLEL_OUTPUT:
            # El monitor publica cada byte fisico. La comparacion de la trama
            # completa se realiza con UART_RESPONSE o UART_ASYNC_EVENT.
            pass
        else:
            raise AssertionError(f"Evento LORA_UART desconocido: {event.kind}")


class Scoreboard(BaseScoreboard):
    def __init__(self, name, parent):
        super().__init__(name, parent, port_names=["uart", "sx1278"])

    def build_phase(self):
        super().build_phase()
        self.dut_mockup = LoraUartMockup()

    def check_event(self, event, source):
        self.dut_mockup.assert_event(event, source)
