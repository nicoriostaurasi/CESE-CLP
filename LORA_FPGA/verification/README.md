# Entorno de verificación LoRa FPGA

Cada bloque posee un entorno `pyuvm` independiente. Los tests son clases UVM pequeñas: seleccionan una
secuencia y dejan la construcción y la comprobación a las fases de UVM.

```text
verification/
|-- agents/
|   |-- agent_spi/       # agent.py, monitors.py y bus SPI completo
|   |-- agent_uart/      # agent.py y monitors.py de la UART fisica
|   `-- agent_sx1278_control/ # señales de control del transceptor
|-- sequences/
|   `-- reset_sequence.py
|-- common_tests/
|   `-- BaseTest.py
|-- helper_classes/
|   |-- agent/base_agent.py
|   `-- scoreboard/base_scoreboard.py
`-- tests/
    |-- COMMAND_DECODER/
    |   |-- hdl/command_decoder_verification_wrapper.vhd
    |   |-- agent_command_decoder/
    |   |   |-- agent.py
    |   |   `-- monitors.py
    |-- SPI/
    |   |-- hdl/spi_verification_wrapper.vhd
    |   |-- environment.py
    |   |-- scoreboard.py
    |   |-- testbench-00-single-frame.py
    |   `-- testbench-01-multiple-frames.py
    |-- UART/
    |-- SX1278/
    |-- UART_TX_MASTER/
    |   `-- agent_uart_output/
    `-- LORA_UART/
```

Los DUT no se instancian directamente desde Python. Cada suite posee una
carpeta `hdl/` con su wrapper VHDL, que deja visible solamente la interfaz que
corresponde verificar. `run.py` toma el wrapper desde la misma carpeta del
test correspondiente:

- `spi_verification_wrapper`: controlador de frames y bus SPI completo.
- `uart_verification_wrapper`: biblioteca UART completa, TX y RX.
- `command_decoder_verification_wrapper`: recepción y decodificación de comandos.
- `uart_tx_master_verification_wrapper`: serialización y arbitraje de la salida UART.
- `sx1278_controller_verification_wrapper`: CONFIG, TX, RX, reset y bus SPI.
- `lora_top_verification_wrapper`: integración completa UART + SX1278.

Cada DUT posee `environment.py`, `scoreboard.py` y varios
`testbench-NN-descripcion.py`. Cada testbench contiene la secuencia concreta y
la clase de test que hereda de `BaseTest`; no contiene asserts ni acceso al
scoreboard. `Env` hereda de `uvm_env`, publica su sequencer mediante `ConfigDB`
y conecta los agentes con un `Scoreboard` derivado de `BaseScoreboard`.
El environment inicia clocks y monitores en `start_of_simulation_phase`. Cada
test inicia explícitamente el DUT con
`await ResetSequence("reset_sequence").start(seqr)`; el reset es una secuencia
compartida y no requiere un agente dedicado.
El detalle de los casos separados por DUT está en [TEST_PLAN.md](TEST_PLAN.md).
El scoreboard contiene un mockup y realiza la comparación automáticamente en
`check_phase`; `BaseScoreboard` verifica en `final_phase` que el chequeo ocurrió.

## Flujo de eventos

Las secuencias solamente solicitan operaciones a los agentes. No acceden al
DUT, al scoreboard ni al mockup y no contienen aserciones. Cada agente maneja
su driver y monitor, y publica las operaciones solicitadas y observadas por un
`uvm_analysis_port`.

Los tipos de evento están centralizados en `common/events.py` mediante `EventKind` y
`EventClassifier`; los scoreboards no comparan strings sueltos. UART posee
monitores explícitos e independientes para la línea serie y para la interfaz
paralela. SPI posee un monitor de frames delimitados por NSS y el decoder posee
un monitor de respuestas y pulsos semánticos.

El environment conecta esos analysis ports con los exports del scoreboard. La
clase `BaseScoreboard` almacena los eventos en FIFOs, los ordena por tiempo y se
los entrega al mockup específico del DUT. Todos los asserts funcionales están
dentro de `assert_event()` en los mockups de cada scoreboard.

Los componentes usan directamente el `Logger` provisto por `pyuvm`. Los
eventos observados se publican con nivel `DEBUG` y los errores detectados por
el scoreboard con nivel `ERROR`.

## Ejecución con Docker

Desde la carpeta `LORA_FPGA`:

```powershell
docker compose -f verification/compose.yaml build
docker compose -f verification/compose.yaml run --rm verification
```

Para ejecutar una sola suite:

```powershell
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py spi
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py uart
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py command_decoder
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py uart_tx_master
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py sx1278
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py lora_uart
```

Para listar todos los tests con su identificador:

```powershell
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py --list
```

Para ejecutar exactamente un test:

```powershell
docker compose -f verification/compose.yaml run --rm verification `
  python verification/run.py --test uart/00-tx-byte
```

El identificador siempre utiliza el formato `suite/caso` mostrado por
`--list`. Esto evita ambigüedades entre casos como `config`, `tx` y `rx` que
aparecen en más de una suite.

Los waveforms GHDL se copian a
`verification/waveforms/<suite>/<caso>.ghw`. Se pueden abrir con GTKWave.

## Secuencias de entrada y salida

- SPI: carga de frame, transmisión con NSS continuo y escritura observada en
  el mapa de registros del mock.
- UART: transmisión y recepción 8N1 por los pines serie y la interfaz paralela.
- COMMAND_DECODER: encuadre, checksum, decodificación y pulsos semánticos sin
  depender de la UART física ni del controlador LoRa.
- UART_TX_MASTER: respuesta ACK/NACK y paquete RX, incluyendo el arbitraje del
  único canal de salida UART.
- SX1278: configuración, carga/transmisión de payload y recuperación de un
  paquete recibido.
- LORA_UART: comandos UART completos, respuestas ACK, CONFIG, TX y evento RX
  automático.

## Observación detectada por la verificación

La UART actual define el terminal de cuenta como `(sysClk/baudRate)-1` y luego
vuelve a comparar contra ese valor menos uno. Por esa razón el período efectivo
es un ciclo menor al esperado. Los agentes usan el período efectivo para poder
verificar el comportamiento existente; conviene corregir el divisor UART en un
refactor específico del RTL.
