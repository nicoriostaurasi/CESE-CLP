from dataclasses import dataclass, field


@dataclass(frozen=True)
class SpiFrameEvent:
    """Transacción SPI completa delimitada por NSS."""

    mosi: bytes
    miso: bytes
    time_ns: float = field(default=0.0, compare=False)
