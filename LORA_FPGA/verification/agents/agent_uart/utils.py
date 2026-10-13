from dataclasses import dataclass, field


@dataclass(frozen=True)
class UartEvent:
    """Byte observado en una de las direcciones de la UART."""

    value: int
    direction: str
    time_ns: float = field(default=0.0, compare=False)
