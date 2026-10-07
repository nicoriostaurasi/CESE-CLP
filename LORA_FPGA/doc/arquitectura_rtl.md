# Arquitectura RTL del controlador LoRa

Este documento describe la organización del diseño implementado en
`LORA_FPGA.srcs/sources_1/new`. El sistema recibe comandos por UART, controla
un transceptor SX1278 mediante SPI y devuelve respuestas o paquetes recibidos
por la misma UART.

La implementación separa las responsabilidades de protocolo, control y manejo
de pines. Esta división permite verificar cada nivel por separado y evita que
la máquina de estados principal tenga que generar directamente cada flanco de
SPI o cada bit de UART.

## Jerarquía

```text
lora_command_fpga_manager
├── myUart
│   ├── uart_rx
│   └── uart_tx
├── command_decoder
│   └── command_acceptance_validator
├── sx1278_controller
│   ├── sx1278_config_registers
│   ├── sx1278_frame_builder
│   └── spi_sequence_controller
│       └── spi_register_access
│           └── spi_frame_controller
│               ├── block_ram (TX)
│               ├── block_ram (RX)
│               └── spi_pin_driver
├── uart_response_serializer
├── uart_rx_serializer
├── uart_tx_master
└── led_status_controller
```

Los packages `uart_command_pkg` y `sx1278_controller_pkg` contienen los tipos y
constantes compartidos. No implementan hardware por sí mismos.

## Flujo de un comando

1. `uart_rx` reconstruye un byte y activa `dataRd` durante un ciclo.
2. `command_decoder` recibe una trama completa, verifica delimitadores y
   checksum, y consulta los validadores.
3. Si el comando es válido, el decoder genera un pulso hacia
   `sx1278_controller`. Si no lo es, solicita una respuesta NACK.
4. `sx1278_controller` selecciona una operación de tipo
   `t_sx1278_operation`.
5. `sx1278_frame_builder` presenta el frame correspondiente al paso actual.
6. `spi_sequence_controller` repite los accesos necesarios hasta completar la
   secuencia.
7. Los bloques inferiores convierten cada acceso en bytes y finalmente en las
   señales `NSS`, `SCLK` y `MOSI`; simultáneamente capturan `MISO`.
8. Al finalizar, el controlador genera `done_o` o `error_o` y el serializador
   transmite ACK o NACK.

## Top level: `lora_command_fpga_manager`

Es el único bloque que debe conectarse a los pines de la FPGA. Su función es
exclusivamente interconectar los subsistemas:

- UART física con el host.
- Decodificación de comandos.
- Controlador del SX1278.
- Serialización de respuestas y paquetes RX.
- Indicadores LED.

El top no construye tramas ni contiene la secuencia del radio. Los parámetros
principales son la frecuencia del reloj del sistema, el baud rate, la
frecuencia SPI, el tiempo de reset y el tamaño máximo del payload.

## Subsistema UART

### `uart_rx`

Detecta el bit de inicio, desplaza los bits de la entrada `rx` y entrega el dato
paralelo en `dataRx`. `dataRd` es un pulso de un ciclo que indica que el byte es
válido. El receptor no interpreta delimitadores ni comandos.

### `uart_tx`

Cuando `dataWr` vale uno, carga una trama formada por bit de inicio, datos y bit
de parada. La carga tiene prioridad sobre el desplazamiento para evitar perder
el nuevo byte. `ready` pulsa al terminar la transmisión completa.

### `myUart`

Es un wrapper full-duplex que instancia `uart_rx` y `uart_tx` con los mismos
genéricos. No agrega lógica de protocolo.

### `command_decoder`

Implementa el protocolo descrito en
[`lora_uart_config_frames.md`](lora_uart_config_frames.md). Su MEF separa:

- registro secuencial de estado y datos Q;
- cálculo combinacional del estado siguiente;
- cálculo combinacional de salidas y próximos valores D.

El decoder espera una trama completa antes de ejecutar una acción. Un checksum
incorrecto, un delimitador final incorrecto o un comando rechazado produce
NACK. No existe timeout en hardware: el host decide cuándo reintentar.

### Validadores

`command_acceptance_validator` concentra la validez semántica: reconoce las
familias de comandos, las acciones de control, las direcciones configurables y
los rangos permitidos por el SX1278. El checksum se filtra previamente en
`ST_DECODE`; en ese mismo estado se evalúa la disponibilidad del controlador.
Si alguna condición falla, la MEF no genera strobes y responde NACK para que el
host reintente la trama. RESET se mantiene como excepción a la condición de
ocupado para permitir recuperación.

El ACK confirma aceptación y lanzamiento de la orden, no la finalización de la
operación SPI. Esta decisión elimina un estado de espera del protocolo UART y
mantiene el control de flujo simple: una solicitud recibida durante `busy`
obtiene NACK y el script la reintenta después de la pausa configurada.
La respuesta se mantiene deliberadamente simple para el alcance del trabajo
práctico: ACK o NACK.

### Serialización y arbitraje UART

`uart_response_serializer` genera las respuestas ACK/NACK de seis bytes.
`uart_rx_serializer` genera los eventos de longitud variable que contienen el
paquete LoRa recibido. Ambos esperan `ready` antes de avanzar al byte siguiente.

`uart_tx_master` concede el transmisor completo a una sola fuente hasta recibir
`done`. Las respuestas tienen prioridad al quedar libre, pero nunca interrumpen
una trama RX que ya comenzó.

## Controlador SX1278

### `sx1278_config_registers`

Almacena frecuencia, bandwidth, coding rate, spreading factor, preámbulo y
potencia. La escritura se realiza con `wr_ena_i`, `addr_i` y `data_i`.

La potencia llega expresada en dBm y se codifica antes de almacenarse en el
formato de `RegPaConfig`. De esta manera el constructor de frames trabaja
directamente con el valor que requiere el transceptor.

### `sx1278_frame_builder`

Es un bloque combinacional. Según `operation_i` y `step_i`, entrega:

- `frame_o`: los dos bytes del acceso SPI;
- `last_step_o`: último paso de la secuencia;
- `read_o`: indica que debe conservarse el byte recibido.

Aquí se construyen las secuencias CONFIG y TX con los registros dinámicos. Los
frames completamente constantes se toman de `sx1278_controller_pkg`.

### `sx1278_controller`

Coordina las operaciones de alto nivel:

- aplicación de configuración;
- preparación y escritura de TX;
- inicio de transmisión y espera de `TxDone`;
- activación de recepción continua;
- lectura de IRQ, longitud, dirección y FIFO RX;
- limpieza de flags.

El controlador arbitra tres managers independientes para CONFIG, TX y RX.
Cada manager expresa sus pasos mediante estados propios y solicita al árbitro
el acceso al secuenciador SPI compartido. En TX, los estados distinguen la
preparación de la FIFO, su llenado byte a byte, el inicio de transmisión, la
espera de `TxDone` y la limpieza final de la interrupción.

`DIO0` es asíncrona respecto de `clk`. Por eso atraviesa dos registros de
sincronización y después se compara con la muestra anterior para producir un
pulso de flanco ascendente.

El reset físico se representa internamente con polaridad activa alta mediante
`reset_active`. La salida `sx1278_reset_o` se invierte porque el pin del SX1278
es activo bajo.

## Cadena SPI

### `spi_sequence_controller`

Ejecuta desde el paso cero hasta `last_step_i`. Solicita a
`spi_register_access` un acceso por vez y sólo incrementa el contador después
de recibir `done`. El frame se selecciona externamente usando `step_o`.

### `spi_register_access`

Adapta un acceso de dos bytes a la interfaz de carga del frame controller. En
una escritura espera directamente la finalización. En una lectura descarta el
byte recibido mientras se envía la dirección y conserva el segundo byte.

### `spi_frame_controller`

Almacena temporalmente los bytes TX, inicia transferencias byte a byte y guarda
los bytes RX. Mantiene `NSS` activo durante el frame completo y agrega una
pausa controlada entre bytes sin finalizar la transacción.

### `spi_pin_driver`

Es el único bloque que maneja directamente `SCLK`, `MOSI` y `MISO`. Implementa
una transferencia full-duplex de ocho bits con los parámetros de frecuencia,
polaridad y fase establecidos por sus genéricos.

### `block_ram`

Memoria síncrona sencilla utilizada por `spi_frame_controller`. La lógica de
punteros y control de flujo pertenece al frame controller, no a la memoria.

## Recepción LoRa

Después de ejecutar `RX_START`, el controlador configura `RXSINGLE` y espera un
flanco ascendente de `DIO0`. Entonces:

1. Lee `RegIrqFlags` y rechaza el paquete si existe error de CRC.
2. Lee la longitud recibida.
3. Lee la dirección inicial del paquete.
4. Posiciona el puntero de FIFO.
5. Lee y almacena cada byte.
6. Limpia las IRQ.
7. Activa `rx_packet_pending_o`.

El serializador recorre el buffer mediante `rx_stream_index_i` y confirma el
consumo con `rx_packet_sent_i`. Luego el manager vuelve a reposo. Para recibir
otro paquete, el host debe enviar una nueva petición `RX_START`.

## Indicadores LED

`led_status_controller` concentra la representación visual del estado para que
el top no tenga lógica adicional. Los LED permiten observar actividad general,
ocupación, finalización y error sin utilizar el analizador lógico.

## Archivos de apoyo

- [`lora_uart_config_frames.md`](lora_uart_config_frames.md): protocolo UART,
  comandos y ejemplos.
- [`lora_module_if.md`](lora_module_if.md): interfaz propuesta para controlar
  el periférico.
- [`lora_module_if_regs.md`](lora_module_if_regs.md): banco de registros y
  parámetros.
- [`pinout_conector_ftdi.md`](pinout_conector_ftdi.md): conexión UART externa.
- `zybo_sch.pdf`: esquema eléctrico de la placa.
- `sx1276-1278113.pdf`: documentación del transceptor.

## Verificación

El testbench integrado `lora_command_fpga_manager_tb.vhd` verifica:

- rechazo de checksum y delimitadores incorrectos;
- escritura y aplicación de configuración;
- transmisión de `SOL`;
- transmisión de `ING NRT`;
- recepción automática del payload `ABC`.

El entorno adicional dentro de `verification` separa agentes, secuencias,
entornos y scoreboards para SPI, UART, SX1278 y el top completo.

## Diagramas PlantUML

Los archivos fuente utilizados por la presentación se mantienen junto con la
documentación para que puedan actualizarse al modificar el diseño:

- [`command_decoder_simplified.puml`](diagrams/command_decoder_simplified.puml).
- [`spi_top_simplified.puml`](diagrams/spi_top_simplified.puml).
- [`sx1278_config_manager_simplified.puml`](diagrams/sx1278_config_manager_simplified.puml).
- [`sx1278_rx_manager_simplified.puml`](diagrams/sx1278_rx_manager_simplified.puml).
- [`sx1278_tx_manager_simplified.puml`](diagrams/sx1278_tx_manager_simplified.puml).

Cada fuente PlantUML posee una imagen PNG homónima empleada en la documentación.
