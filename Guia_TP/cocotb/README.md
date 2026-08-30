# Verificacion con Cocotb

Este entorno verifica el top level VHDL `contador_bcd_1_seg` con Cocotb y GHDL.
El test cubre reset sincrono, habilitacion general, avance cada `N` ciclos,
rollover BCD de 9 a 0, pausa y reanudacion.

La estructura sigue el enfoque de `CocoTB_FPGA_Verification`: un `Makefile`, un
testbench Python y un waveform versionado. Para VHDL se utiliza GHDL en lugar de
Icarus Verilog.

## Ejecutar con Docker

Desde esta carpeta:

```sh
docker compose build
docker compose run --rm cocotb make run
```

El valor real del top level es `SYS_CLK=100000000`. La simulacion lo reemplaza
por `5` para que cada segundo simulado requiera solamente cinco ciclos.

El waveform generado queda en:

```text
waveforms/contador_bcd_1_seg.vcd
```

Puede abrirse con GTKWave u otro visor compatible con VCD.
