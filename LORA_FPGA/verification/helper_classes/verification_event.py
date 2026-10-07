from dataclasses import dataclass, field
from cocotb.utils import get_sim_time
from common.events import EventClassifier, EventKind


@dataclass(frozen=True)
class VerificationEvent:
    """Evento independiente del DUT intercambiado entre agente y scoreboard."""

    kind: EventKind
    data: object
    time_ns: float = field(default_factory=lambda: get_sim_time("ns"),
                           compare=False)

    def __post_init__(self):
        object.__setattr__(self, "kind", EventKind(self.kind))

    @property
    def category(self):
        return EventClassifier.category(self.kind)

    def description(self):
        """Devuelve una representacion orientada a la lectura del log."""
        from common.protocol import describe_command_frame, hex_bytes

        if self.kind in (EventKind.UART_COMMAND,
                         EventKind.COMMAND_REQUESTED):
            return describe_command_frame(bytes(self.data))
        if isinstance(self.data, (bytes, bytearray)):
            return hex_bytes(bytes(self.data))
        if isinstance(self.data, int):
            return f"0x{self.data:02X}"
        return str(self.data)
