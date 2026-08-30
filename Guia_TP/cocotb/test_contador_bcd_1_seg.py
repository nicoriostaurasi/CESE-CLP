import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


CLK_PERIOD_NS = 10
SYS_CLK_SIM = 5


async def wait_clock_cycles(dut, cycles):
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    await Timer(1, units="ns")


@cocotb.test()
async def test_contador_bcd_1_seg(dut):
    """Verifica reset, enable, periodo, rollover BCD y reanudacion."""

    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())

    dut.ena.value = 0
    dut.rst.value = 1
    await wait_clock_cycles(dut, 5)
    dut.rst.value = 0
    await Timer(1, units="ns")
    assert int(dut.q.value) == 0, "El contador no quedo en cero"

    # Sin habilitacion general, un periodo completo no debe modificar Q.
    await wait_clock_cycles(dut, SYS_CLK_SIM)
    assert int(dut.q.value) == 0, "El contador avanzo con ena=0"

    # Comprueba una vuelta completa y dos cuentas adicionales.
    dut.ena.value = 1
    for expected in range(1, 13):
        await wait_clock_cycles(dut, SYS_CLK_SIM)
        assert int(dut.q.value) == expected % 10, (
            f"Esperado {expected % 10}, obtenido {int(dut.q.value)}"
        )

    # Pausa dos periodos completos en el valor 2.
    dut.ena.value = 0
    await wait_clock_cycles(dut, 2 * SYS_CLK_SIM)
    assert int(dut.q.value) == 2, "El contador no se detuvo con ena=0"

    # Al habilitar nuevamente debe continuar desde el valor retenido.
    dut.ena.value = 1
    await wait_clock_cycles(dut, SYS_CLK_SIM)
    assert int(dut.q.value) == 3, "El contador no reanudo desde el valor retenido"
