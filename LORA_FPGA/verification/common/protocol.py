UART_FRAME_START = 0x23
UART_FRAME_END = 0x24
UART_ACK = 0x06
UART_NACK = 0x15
UART_EVENT_RX_PACKET = 0x80

CMD_CONFIG_WRITE = 0x01
CMD_CONTROL = 0x02
CMD_TX_WRITE = 0x03

CTRL_APPLY_CONFIG = 0x01
CTRL_RESET_PERIPH = 0x02
CTRL_TX_START = 0x03
CTRL_RX_START = 0x04
CTRL_TX_BEGIN = 0x05

COMMAND_NAMES = {
    CMD_CONFIG_WRITE: "CONFIG_WRITE",
    CMD_CONTROL: "CONTROL",
    CMD_TX_WRITE: "TX_WRITE",
}

CONTROL_NAMES = {
    CTRL_APPLY_CONFIG: "APPLY_CONFIG",
    CTRL_RESET_PERIPH: "RESET_PERIPHERAL",
    CTRL_TX_START: "TX_START",
    CTRL_RX_START: "RX_START",
    CTRL_TX_BEGIN: "TX_BEGIN",
}


def hex_bytes(data: bytes) -> str:
    """Representa una secuencia como bytes hexadecimales de ancho fijo."""
    return " ".join(f"0x{value:02X}" for value in data)


def describe_command_frame(frame: bytes) -> str:
    """Traduce una trama UART de comando a una descripcion legible."""
    if len(frame) != 6:
        return hex_bytes(frame)

    _, command, parameter, value, checksum, _ = frame
    command_name = COMMAND_NAMES.get(command, f"UNKNOWN_0x{command:02X}")
    parameter_name = (CONTROL_NAMES.get(parameter, f"0x{parameter:02X}")
                      if command == CMD_CONTROL else f"0x{parameter:02X}")
    printable = (f" ('{chr(value)}')"
                 if command == CMD_TX_WRITE and 32 <= value <= 126 else "")
    return (f"{command_name}: parameter={parameter_name}, "
            f"value=0x{value:02X}{printable}, checksum=0x{checksum:02X}")


def command_frame(command: int, parameter: int, value: int) -> bytes:
    checksum = command ^ parameter ^ value
    return bytes((UART_FRAME_START, command, parameter, value,
                  checksum, UART_FRAME_END))


def response_frame(command: int, status: int, data: int = 0) -> bytes:
    checksum = command ^ status ^ data
    return bytes((UART_FRAME_START, command, status, data,
                  checksum, UART_FRAME_END))


def rx_event_frame(payload: bytes) -> bytes:
    checksum = UART_EVENT_RX_PACKET ^ len(payload)
    for value in payload:
        checksum ^= value
    return bytes((UART_FRAME_START, UART_EVENT_RX_PACKET, len(payload),
                  *payload, checksum, UART_FRAME_END))
