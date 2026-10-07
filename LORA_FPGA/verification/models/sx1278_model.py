import cocotb
from cocotb.triggers import FallingEdge, First, RisingEdge, Timer

from common.events import SpiFrameEvent


class Sx1278Model:
    """Modelo funcional minimo del mapa de registros y FIFO del SX1278."""

    REG_FIFO = 0x00
    REG_OP_MODE = 0x01
    REG_FIFO_ADDR_PTR = 0x0D
    REG_FIFO_TX_BASE = 0x0E
    REG_FIFO_RX_CURRENT = 0x10
    REG_IRQ_FLAGS = 0x12
    REG_RX_NB_BYTES = 0x13

    def __init__(self, sclk, mosi, miso, nss, dio0=None, tx_callback=None):
        self.sclk = sclk
        self.mosi = mosi
        self.miso = miso
        self.nss = nss
        self.dio0 = dio0
        self.registers = [0] * 128
        self.fifo = [0] * 256
        self.frames = []
        self.tx_packets = []
        self.tx_callback = tx_callback
        self.miso.value = 0
        if self.dio0 is not None:
            self.dio0.value = 0

    def _read(self, address: int) -> int:
        if address == self.REG_FIFO:
            pointer = self.registers[self.REG_FIFO_ADDR_PTR]
            return self.fifo[pointer]
        return self.registers[address]

    def _write(self, address: int, value: int):
        if address == self.REG_FIFO:
            pointer = self.registers[self.REG_FIFO_ADDR_PTR]
            self.fifo[pointer] = value
            self.registers[self.REG_FIFO_ADDR_PTR] = (pointer + 1) & 0xFF
        elif address == self.REG_IRQ_FLAGS:
            self.registers[address] &= ~value
        else:
            self.registers[address] = value

        if address == self.REG_OP_MODE and value == 0x8B:
            length = self.registers[0x22]
            base = self.registers[self.REG_FIFO_TX_BASE]
            payload = bytes(self.fifo[base:base + length])
            self.tx_packets.append(payload)
            if self.tx_callback is not None:
                self.tx_callback(payload)
            if self.dio0 is not None:
                cocotb.start_soon(self._pulse_dio0())

    async def _pulse_dio0(self):
        # El evento del radio ocurre luego de que finaliza el frame SPI que
        # selecciona TX; la demora evita superponerlo con el ultimo clock.
        await Timer(20, units="us")
        self.registers[self.REG_IRQ_FLAGS] |= 0x08
        self.dio0.value = 1
        await Timer(10, units="us")
        self.dio0.value = 0

    async def inject_rx(self, payload: bytes, crc_error: bool = False):
        base = 0x20
        self.fifo[base:base + len(payload)] = payload
        self.registers[self.REG_FIFO_RX_CURRENT] = base
        self.registers[self.REG_RX_NB_BYTES] = len(payload)
        self.registers[self.REG_IRQ_FLAGS] = 0x60 if crc_error else 0x40
        self.dio0.value = 1
        await Timer(2, units="us")
        self.dio0.value = 0

    async def run(self):
        while True:
            await FallingEdge(self.nss)
            address = 0
            write = False
            byte_index = 0
            received_byte = 0
            received_bits = 0
            response_byte = 0
            response_bit = 7
            mosi_bytes = []
            miso_bytes = []
            self.miso.value = (response_byte >> response_bit) & 1

            while int(self.nss.value) == 0:
                await First(RisingEdge(self.sclk), RisingEdge(self.nss))
                if int(self.nss.value) != 0:
                    break
                received_byte = (received_byte << 1) | int(self.mosi.value)
                received_bits += 1
                if received_bits == 8:
                    mosi_bytes.append(received_byte)
                    miso_bytes.append(response_byte)
                    if byte_index == 0:
                        write = bool(received_byte & 0x80)
                        address = received_byte & 0x7F
                        response_byte = 0 if write else self._read(address)
                    elif write:
                        self._write(address, received_byte)
                        response_byte = 0
                    else:
                        if address == self.REG_FIFO:
                            pointer = self.registers[self.REG_FIFO_ADDR_PTR]
                            self.registers[self.REG_FIFO_ADDR_PTR] = \
                                (pointer + 1) & 0xFF
                        response_byte = self._read(address)
                    byte_index += 1
                    received_byte = 0
                    received_bits = 0
                    response_bit = 7
                else:
                    response_bit -= 1

                await First(FallingEdge(self.sclk), RisingEdge(self.nss))
                if int(self.nss.value) == 0:
                    self.miso.value = (response_byte >> response_bit) & 1

            self.miso.value = 0
            if mosi_bytes:
                self.frames.append(SpiFrameEvent(bytes(mosi_bytes),
                                                 bytes(miso_bytes)))
