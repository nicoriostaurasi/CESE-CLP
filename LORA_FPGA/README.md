# Controlador FPGA para LoRa SX1278

Implementación VHDL de un controlador para el transceptor LoRa SX1278 sobre
una placa Zybo Zynq-7000. El sistema recibe comandos desde una PC mediante
UART, traduce las solicitudes a secuencias SPI y devuelve ACK, NACK o los
paquetes recibidos.

## Funciones implementadas

- Escritura de parámetros de configuración LoRa.
- Aplicación de la configuración mediante SPI.
- Reset físico del transceptor.
- Escritura byte a byte de la FIFO TX.
- Inicio de transmisión y detección de `TxDone` por DIO0.
- Recepción continua y lectura automática de paquetes.
- Envío por UART del payload recibido.
- Checksum XOR para comandos y respuestas UART.
- Indicadores LED de actividad y estado.

El payload máximo utilizado por el diseño es configurable mediante
`MAX_DATA_BYTES` y vale 50 bytes por defecto.

## Organización

```text
LORA_FPGA.srcs/sources_1/new/  Código RTL sintetizable
LORA_FPGA.srcs/sim_1/new/      Testbenches VHDL
scripts/                       Cliente UART y scripts de simulación
verification/                  Entorno de verificación automatizada
doc/                           Arquitectura, protocolo y pinout
```

La descripción detallada de los bloques se encuentra en
[`doc/arquitectura_rtl.md`](doc/arquitectura_rtl.md).

## Protocolo UART

La comunicación usa 115200 8N1. Las solicitudes tienen el formato:

```text
[#] [COMANDO] [PARAMETRO] [VALOR] [CHECKSUM] [$]
```

El checksum es el XOR de comando, parámetro y valor. Los comandos y ejemplos
se describen en
[`doc/lora_uart_config_frames.md`](doc/lora_uart_config_frames.md).

## Uso del script

Desde PowerShell, con la FPGA conectada al puerto correspondiente:

```powershell
python .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 config
python .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 tx-text "ING NRT"
python .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 rx
python .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 reset
```

La pausa recomendada entre comandos UART es `0.020` segundos (20 ms), acompañada
por tres reintentos. Esta combinación completó correctamente 10 transmisiones
consecutivas durante la prueba en hardware. Los reintentos absorben las ventanas
ocasionales en las que el controlador todavía se encuentra ocupado.

El comando `rx` espera un paquete y muestra el payload recibido en hexadecimal y
ASCII. Puede cancelarse con `Ctrl+C` antes de recibirlo.

## Simulación integrada

El testbench principal es
`LORA_FPGA.srcs/sim_1/new/lora_command_fpga_manager_tb.vhd`. Verifica comandos
inválidos, configuración, transmisión y recepción automática.

Con Vivado 2024.2 instalado:

```powershell
cd .\scripts
& 'C:\Xilinx\Vivado\2024.2\bin\vivado.bat' `
    -mode batch -source run_lora_top_tb.tcl
```

La simulación correcta termina con:

```text
UART verificada: CONFIG, TX SOL, TX ING NRT y RX automatico ABC correctos
```

## Documentación relacionada

- [Arquitectura RTL](doc/arquitectura_rtl.md)
- [Reporte de utilización de FPGA](doc/UtilizationReport.txt)
- [Protocolo UART](doc/lora_uart_config_frames.md)
- [Interfaz del módulo](doc/lora_module_if.md)
- [Registros de la interfaz](doc/lora_module_if_regs.md)
- [Conexión UART/FTDI](doc/pinout_conector_ftdi.md)
- [Esquema de la Zybo](doc/zybo_sch.pdf)
- [Datasheet del SX1278](doc/sx1276-1278113.pdf)
