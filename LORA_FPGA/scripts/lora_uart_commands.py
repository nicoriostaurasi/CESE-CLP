#!/usr/bin/env python3
"""Envia tramas UART delimitadas al lora_command_fpga_manager."""

import argparse
import sys
import time

try:
    from serial.serialutil import (
        EIGHTBITS,
        PARITY_NONE,
        STOPBITS_ONE,
        SerialException,
    )
    from serial.serialwin32 import Serial
except ImportError as error:
    print(
        "No se pudo cargar pyserial. "
        f"Instalar con: py -3.13 -m pip install --force-reinstall pyserial ({error})",
        file=sys.stderr,
    )
    raise SystemExit(1)


CMD_CONFIG_WRITE = 0x01
CMD_CONTROL = 0x02
CMD_TX_WRITE = 0x03

CTRL_APPLY_CONFIG = 0x01
CTRL_RESET_PERIPH = 0x02
CTRL_TX_START = 0x03
CTRL_RX_START = 0x04
CTRL_TX_BEGIN = 0x05

CFG_FRF_MSB = 0x00
CFG_FRF_MID = 0x01
CFG_FRF_LSB = 0x02
CFG_BANDWIDTH = 0x03
CFG_CODING_RATE = 0x04
CFG_SPREADING_FACTOR = 0x05
CFG_PREAMBLE_MSB = 0x06
CFG_PREAMBLE_LSB = 0x07
CFG_TX_POWER_DBM = 0x08

UART_ACK = 0x06
UART_NACK = 0x15
MAX_DATA_BYTES = 50
UART_FRAME_START = 0x23
UART_FRAME_END = 0x24
UART_EVENT_RX_PACKET = 0x80

COMMAND_NAMES = {
    CMD_CONFIG_WRITE: "CONFIG_WRITE",
    CMD_CONTROL: "CONTROL",
    CMD_TX_WRITE: "TX_WRITE",
}

CONTROL_NAMES = {
    CTRL_APPLY_CONFIG: "APPLY_CONFIG",
    CTRL_RESET_PERIPH: "RESET_PERIPH",
    CTRL_TX_START: "TX_START",
    CTRL_RX_START: "RX_START",
    CTRL_TX_BEGIN: "TX_BEGIN",
}

CONFIG_NAMES = {
    CFG_FRF_MSB: "SET_FRF_MSB",
    CFG_FRF_MID: "SET_FRF_MID",
    CFG_FRF_LSB: "SET_FRF_LSB",
    CFG_BANDWIDTH: "SET_BANDWIDTH",
    CFG_CODING_RATE: "SET_CODING_RATE",
    CFG_SPREADING_FACTOR: "SET_SPREADING_FACTOR",
    CFG_PREAMBLE_MSB: "SET_PREAMBLE_MSB",
    CFG_PREAMBLE_LSB: "SET_PREAMBLE_LSB",
    CFG_TX_POWER_DBM: "SET_TX_POWER_DBM",
}

def integer(value: str) -> int:
    """Acepta enteros decimales o con prefijo 0x."""
    return int(value, 0)


def byte_value(value: str) -> int:
    """Acepta un caracter ASCII o un byte numerico."""
    if len(value) == 1 and not value.isdigit():
        return ord(value)
    result = integer(value)
    if not 0 <= result <= 0xFF:
        raise argparse.ArgumentTypeError("el valor debe estar entre 0 y 255")
    return result


def command_mnemonic(command: int, parameter: int, value: int) -> str:
    """Describe la accion representada por una trama de comando."""
    if command == CMD_CONFIG_WRITE:
        return CONFIG_NAMES.get(parameter, f"CONFIG_WRITE[0x{parameter:02X}]")
    if command == CMD_CONTROL:
        control = CONTROL_NAMES.get(parameter, f"CONTROL[0x{parameter:02X}]")
        return control
    if command == CMD_TX_WRITE:
        printable = chr(value) if 32 <= value <= 126 else "."
        return f"FIFO_WRITE='{printable}'"
    return f"UNKNOWN_COMMAND[0x{command:02X}]"


class FpgaLink:
    def __init__(
        self,
        port: str,
        baudrate: int,
        timeout: float,
        check_ack: bool,
        command_delay: float,
        retries: int,
    ):
        self.serial = Serial(
            port=port,
            baudrate=baudrate,
            bytesize=EIGHTBITS,
            parity=PARITY_NONE,
            stopbits=STOPBITS_ONE,
            timeout=timeout,
        )
        self.check_ack = check_ack
        self.command_delay = command_delay
        self.retries = retries
        self.serial.reset_input_buffer()

    def close(self) -> None:
        self.serial.close()

    def wait_command_gap(self) -> None:
        """Deja tiempo de reposo antes de enviar la trama siguiente."""
        if self.command_delay > 0:
            time.sleep(self.command_delay)

    def read_rx_event(self) -> bytes:
        """Decodifica [#][RX_PACKET][LEN][DATA...][CHECKSUM][$]."""
        while True:
            start = self.serial.read(1)
            if not start:
                continue
            if start[0] != UART_FRAME_START:
                continue

            event = self.serial.read(1)
            if not event or event[0] != UART_EVENT_RX_PACKET:
                continue

            length_data = self.serial.read(1)
            if not length_data:
                raise RuntimeError("timeout esperando la longitud RX")
            length = length_data[0]
            payload = self.serial.read(length)
            checksum_data = self.serial.read(1)
            frame_end = self.serial.read(1)

            if len(payload) != length or not checksum_data or not frame_end:
                raise RuntimeError("trama RX incompleta")
            if frame_end[0] != UART_FRAME_END:
                raise RuntimeError("delimitador final RX invalido")

            expected_checksum = UART_EVENT_RX_PACKET ^ length
            for value in payload:
                expected_checksum ^= value
            if checksum_data[0] != expected_checksum:
                raise RuntimeError(
                    "checksum RX invalido: "
                    f"recibido=0x{checksum_data[0]:02X}, "
                    f"esperado=0x{expected_checksum:02X}"
                )

            printable = ''.join(chr(value) if 32 <= value <= 126 else '.'
                                for value in payload)
            print(f"RX_PACKET len={length} HEX={payload.hex(' ').upper()} "
                  f"ASCII='{printable}'")
            return payload

    def send(
        self,
        command: int,
        parameter: int = 0,
        value: int = 0,
    ) -> None:
        """Envia un comando y lo reintenta ante NACK o respuesta no valida.

        El protocolo usa un NACK generico. Puede significar que el comando es
        invalido o que el controlador estaba ocupado; por eso el host espera el
        intervalo configurado y reenvia la trama completa un numero acotado de
        veces.
        """
        attempts = 1 if not self.check_ack else self.retries + 1

        for attempt in range(1, attempts + 1):
            try:
                self._send_once(command, parameter, value)
                return
            except RuntimeError as error:
                if attempt == attempts:
                    raise

                print(
                    f"Reintento {attempt}/{self.retries} despues de "
                    f"{self.command_delay * 1000:.0f} ms: {error}",
                    file=sys.stderr,
                )
                # Descarta una respuesta parcial antes de reenviar la trama
                # completa desde su delimitador inicial.
                self.serial.reset_input_buffer()
                self.wait_command_gap()

    def _send_once(
        self,
        command: int,
        parameter: int,
        value: int,
    ) -> None:
        """Realiza un unico intercambio UART de solicitud y respuesta."""
        checksum = command ^ parameter ^ value
        frame = bytes(
            (UART_FRAME_START, command, parameter, value, checksum, UART_FRAME_END)
        )
        name = COMMAND_NAMES.get(command, "UNKNOWN")
        mnemonic = command_mnemonic(command, parameter, value)
        print(
            f"TX  {name:<14} {mnemonic:<28} "
            f"[0x{command:02X} 0x{parameter:02X} 0x{value:02X} "
            f"CHK=0x{checksum:02X}]",
            end="",
        )
        self.serial.write(frame)
        self.serial.flush()

        if not self.check_ack:
            print()
            self.wait_command_gap()
            return

        response = self.serial.read(6)
        if len(response) != 6:
            print(f" -> respuesta incompleta ({response.hex(' ').upper()})")
            raise RuntimeError("timeout esperando la respuesta de seis bytes")

        (frame_start, response_command, status, response_data,
         response_checksum, frame_end) = response
        print(
            f" -> RX [0x{frame_start:02X} 0x{response_command:02X} "
            f"0x{status:02X} 0x{response_data:02X} "
            f"CHK=0x{response_checksum:02X} 0x{frame_end:02X}]",
            end="",
        )

        if frame_start != UART_FRAME_START or frame_end != UART_FRAME_END:
            print(" DELIMITADORES INVALIDOS")
            raise RuntimeError("la respuesta UART no tiene delimitadores validos")

        expected_checksum = response_command ^ status ^ response_data
        if response_checksum != expected_checksum:
            print(" CHECKSUM INVALIDO")
            raise RuntimeError(
                "checksum de respuesta invalido: "
                f"recibido=0x{response_checksum:02X}, "
                f"esperado=0x{expected_checksum:02X}"
            )

        if response_command != command:
            print(" COMANDO INESPERADO")
            raise RuntimeError("la respuesta no corresponde al comando enviado")
        if status == UART_ACK:
            print(" ACK")
            self.wait_command_gap()
            return
        if status == UART_NACK:
            print(" NACK")
            raise RuntimeError(f"la FPGA rechazo {name}")

        print(" ESTADO DESCONOCIDO")
        raise RuntimeError(f"estado UART desconocido 0x{status:02X}")


def send_config(link: FpgaLink, args: argparse.Namespace) -> None:
    if not 0 <= args.frf <= 0xFFFFFF:
        raise ValueError("FRF debe ser un valor de 24 bits")
    if not 0 <= args.bw <= 9:
        raise ValueError("BW debe estar entre 0 y 9")
    if not 1 <= args.cr <= 4:
        raise ValueError("CR debe estar entre 1 y 4")
    if not 6 <= args.sf <= 12:
        raise ValueError("SF debe estar entre 6 y 12")
    if not 2 <= args.power <= 17:
        raise ValueError("POWER debe estar entre 2 y 17 dBm")
    if not 0 <= args.preamble <= 0xFFFF:
        raise ValueError("PREAMBLE debe ser un valor de 16 bits")

    register_values = (
        (CFG_FRF_MSB, (args.frf >> 16) & 0xFF),
        (CFG_FRF_MID, (args.frf >> 8) & 0xFF),
        (CFG_FRF_LSB, args.frf & 0xFF),
        (CFG_BANDWIDTH, args.bw),
        (CFG_CODING_RATE, args.cr),
        (CFG_SPREADING_FACTOR, args.sf),
        (CFG_TX_POWER_DBM, args.power),
        (CFG_PREAMBLE_MSB, (args.preamble >> 8) & 0xFF),
        (CFG_PREAMBLE_LSB, args.preamble & 0xFF),
    )

    for address, value in register_values:
        link.send(CMD_CONFIG_WRITE, address, value)
    link.send(CMD_CONTROL, CTRL_APPLY_CONFIG, 0)


def send_payload(link: FpgaLink, payload: bytes) -> None:
    if not 1 <= len(payload) <= MAX_DATA_BYTES:
        raise ValueError(f"el payload debe contener entre 1 y {MAX_DATA_BYTES} bytes")

    link.send(CMD_CONTROL, CTRL_TX_BEGIN, 0)
    for value in payload:
        link.send(CMD_TX_WRITE, 0, value)
    link.send(CMD_CONTROL, CTRL_TX_START, 0)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Control UART del SX1278 en FPGA")
    parser.add_argument("--port", default="COM9", help="puerto serie (default: COM9)")
    parser.add_argument("--baud", type=int, default=115200, help="baudrate")
    parser.add_argument("--timeout", type=float, default=1.0, help="timeout de respuesta")
    parser.add_argument(
        "--command-delay",
        type=float,
        default=0.500,
        help="pausa entre comandos en segundos (default: 0.500)",
    )
    parser.add_argument(
        "--retries",
        type=int,
        default=3,
        help="reintentos ante NACK, timeout o respuesta corrupta (default: 3)",
    )
    parser.add_argument("--no-ack", action="store_true", help="no esperar respuestas UART")

    commands = parser.add_subparsers(dest="action", required=True)

    config = commands.add_parser("config", help="cargar y aplicar la configuracion")
    config.add_argument("--frf", type=integer, default=0x6C4000, help="FRF de 24 bits")
    config.add_argument("--bw", type=int, default=7, help="codigo BW 0..9")
    config.add_argument("--cr", type=int, default=1, help="codigo CR 1..4")
    config.add_argument("--sf", type=int, default=7, help="spreading factor 6..12")
    config.add_argument("--power", type=int, default=14, help="potencia 2..17 dBm")
    config.add_argument("--preamble", type=integer, default=8, help="largo de preambulo")

    commands.add_parser("reset", help="resetear el SX1278")

    tx_byte = commands.add_parser("tx-byte", help="transmitir un byte")
    tx_byte.add_argument("data", type=byte_value, help="caracter, decimal o hexadecimal")

    tx_text = commands.add_parser("tx-text", help="transmitir un texto de hasta 50 bytes")
    tx_text.add_argument("text")

    commands.add_parser("rx", help="esperar la recepcion de un paquete LoRa")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    link = None

    try:
        if args.command_delay < 0:
            raise ValueError("command-delay no puede ser negativo")
        if args.retries < 0:
            raise ValueError("retries no puede ser negativo")
        link = FpgaLink(
            args.port,
            args.baud,
            args.timeout,
            not args.no_ack,
            args.command_delay,
            args.retries,
        )
        print(f"Puerto abierto: {args.port} @ {args.baud} 8N1")
        print(f"Pausa entre comandos: {args.command_delay * 1000:.1f} ms")

        if args.action == "config":
            send_config(link, args)
        elif args.action == "reset":
            link.send(CMD_CONTROL, CTRL_RESET_PERIPH, 0)
        elif args.action == "tx-byte":
            send_payload(link, bytes((args.data,)))
        elif args.action == "tx-text":
            send_payload(link, args.text.encode("ascii"))
        elif args.action == "rx":
            link.send(CMD_CONTROL, CTRL_RX_START, 0)
            print("RX activo. Esperando un paquete.")
            link.read_rx_event()
    except KeyboardInterrupt:
        print("\nMonitor RX finalizado por el usuario.")
        if link is not None and args.action == "rx":
            print("Cancelando la recepcion pendiente mediante RESET_PERIPH.")
            try:
                link.send(CMD_CONTROL, CTRL_RESET_PERIPH, 0)
            except (OSError, RuntimeError, SerialException) as error:
                print(f"Advertencia: no se pudo cancelar RX: {error}",
                      file=sys.stderr)
    except (OSError, RuntimeError, ValueError, UnicodeEncodeError, SerialException) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    finally:
        if link is not None:
            link.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
