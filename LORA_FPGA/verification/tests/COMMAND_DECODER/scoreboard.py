from helper_classes.scoreboard.base_scoreboard import BaseScoreboard
from common.events import EventKind
from common.protocol import (CMD_CONFIG_WRITE, CMD_TX_WRITE, UART_ACK, UART_NACK,
                      UART_FRAME_END)


class CommandDecoderMockup:
    def __init__(self): self.expected = []

    def assert_event(self, event, source):
        if event.kind is EventKind.COMMAND_REQUESTED:
            frame = event.data
            checksum_valid = frame[4] == (frame[1] ^ frame[2] ^ frame[3])
            framing_valid = frame[5] == UART_FRAME_END
            status = UART_ACK if checksum_valid and framing_valid else UART_NACK
            self.expected.append((frame[1], frame[2], frame[3], status))
        elif event.kind is EventKind.COMMAND_OBSERVED:
            command, parameter, value, status = self.expected.pop(0)
            got = event.data
            assert got["command"] == command and got["status"] == status
            assert got["data"] == (value if status == UART_ACK else 0)
            if status == UART_ACK and command == CMD_CONFIG_WRITE:
                assert got["config_write"] and got["config_addr"] == parameter
                assert got["config_data"] == value
            elif status == UART_ACK and command == CMD_TX_WRITE:
                assert got["tx_write"] and got["tx_data"] == value
        else: raise AssertionError(f"Evento desconocido: {event.kind}")


class Scoreboard(BaseScoreboard):
    def __init__(self, name, parent): super().__init__(name, parent, port_names=["command"])
    def build_phase(self): super().build_phase(); self.dut_mockup = CommandDecoderMockup()
    def check_event(self, event, source): self.dut_mockup.assert_event(event, source)
