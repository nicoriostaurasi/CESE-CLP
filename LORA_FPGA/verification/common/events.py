from dataclasses import dataclass
from enum import Enum


@dataclass(frozen=True)
class SpiFrameEvent:
    """Bytes observados en MOSI y MISO durante un frame SPI."""

    mosi: bytes
    miso: bytes


@dataclass(frozen=True)
class UartEvent:
    """Byte UART observado y sentido de la transferencia."""

    data: int
    direction: str


class EventCategory(Enum):
    STIMULUS = "stimulus"
    OBSERVATION = "observation"


class EventKind(str, Enum):
    UART_LINE_INPUT = "uart_line_input"
    UART_LINE_OUTPUT = "uart_line_output"
    UART_PARALLEL_INPUT = "uart_parallel_input"
    UART_PARALLEL_OUTPUT = "uart_parallel_output"
    UART_COMMAND = "uart_command"
    UART_RESPONSE = "uart_response"
    UART_ASYNC_EVENT = "uart_async_event"
    UART_FRAME_OBSERVED = "uart_frame_observed"
    SPI_REQUESTED = "spi_requested"
    SPI_OBSERVED = "spi_observed"
    COMMAND_REQUESTED = "command_requested"
    COMMAND_OBSERVED = "command_observed"
    RESPONSE_REQUESTED = "response_requested"
    RX_PACKET_REQUESTED = "rx_packet_requested"
    CONFIG_REQUESTED = "config_requested"
    CONFIG_OBSERVED = "config_observed"
    TX_REQUESTED = "tx_requested"
    RX_INJECTED = "rx_injected"
    RX_OBSERVED = "rx_observed"
    RADIO_TX_OBSERVED = "radio_tx_observed"
    RADIO_RX_INJECTED = "radio_rx_injected"


class EventClassifier:
    """Clasifica eventos sin repetir literales en agentes y scoreboards."""

    STIMULUS_EVENTS = {
        EventKind.UART_LINE_INPUT, EventKind.UART_PARALLEL_INPUT,
        EventKind.UART_COMMAND, EventKind.SPI_REQUESTED,
        EventKind.COMMAND_REQUESTED, EventKind.RESPONSE_REQUESTED,
        EventKind.RX_PACKET_REQUESTED, EventKind.CONFIG_REQUESTED,
        EventKind.TX_REQUESTED, EventKind.RX_INJECTED,
        EventKind.RADIO_RX_INJECTED,
    }

    @classmethod
    def category(cls, kind):
        event_kind = EventKind(kind)
        if event_kind in cls.STIMULUS_EVENTS:
            return EventCategory.STIMULUS
        return EventCategory.OBSERVATION

