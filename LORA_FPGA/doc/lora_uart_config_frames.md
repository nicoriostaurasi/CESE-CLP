# Protocolo UART y decodificador de comandos

La FPGA se comunica con la PC mediante UART a 115200 baudios, 8 bits de datos,
sin paridad y un bit de stop (115200 8N1). La entidad `command_decoder` recibe
las solicitudes y genera las acciones destinadas al `sx1278_controller`.

## Trama de solicitud

Todas las solicitudes tienen seis bytes:

```text
[#] [COMANDO] [PARAMETRO] [VALOR] [CHECKSUM] [$]
```

| Campo | Valor o significado |
| --- | --- |
| `#` | `0x23`, comienzo de trama |
| `COMANDO` | clase de operación solicitada |
| `PARAMETRO` | dirección de configuración o acción de control |
| `VALOR` | dato asociado al comando |
| `CHECKSUM` | `COMANDO XOR PARAMETRO XOR VALOR` |
| `$` | `0x24`, final de trama |

El decoder ignora bytes hasta encontrar `#`. Después captura exactamente los
cuatro campos internos y exige `$`. Si recibe un sexto byte distinto de `$`,
responde NACK para que el host pueda reenviar la solicitud. Si el byte no llega,
permanece esperando porque no existe timeout temporal dentro de la FPGA; en ese
caso el timeout y el reintento quedan a cargo del host.

## Respuesta

Todas las respuestas a comandos también tienen seis bytes:

```text
[#] [COMANDO] [ESTADO] [DATO] [CHECKSUM] [$]
```

| Estado | Código | Significado |
| --- | ---: | --- |
| ACK | `0x06` | comando aceptado y terminado |
| NACK | `0x15` | comando rechazado o error durante su ejecución |

El checksum de respuesta es `COMANDO XOR ESTADO XOR DATO`. Con ACK, `DATO`
repite el valor de la solicitud. Con NACK, `DATO` vale `0x00`. El diseño no
clasifica las causas: comando desconocido, checksum incorrecto, parámetro
inválido y controlador ocupado producen el mismo NACK.

## Entidad `command_decoder`

La entidad cumple cuatro funciones:

1. Encuadra y registra los seis bytes de la solicitud.
2. Comprueba el checksum y la validez básica del comando.
3. Genera pulsos de un ciclo hacia el controlador LoRa.
4. Solicita al serializador el envío de ACK o NACK.

### Entradas

| Puerto | Función |
| --- | --- |
| `clk`, `rst` | reloj y reset síncrono |
| `uart_data_rd_i` | pulso que indica un byte UART nuevo |
| `uart_data_rx_i` | byte recibido |
| `controller_busy_i` | el controlador SX1278 está ejecutando una operación |
| `rst_periph_active_i` | el reset físico del SX1278 sigue activo |

### Salidas hacia el controlador

| Puerto | Función |
| --- | --- |
| `config_wr_ena_o` | escribe un valor en el banco de configuración |
| `config_addr_o` | dirección tomada de `PARAMETRO` |
| `config_data_o` | dato tomado de `VALOR` |
| `config_start_o` | aplica mediante SPI la configuración almacenada |
| `tx_data_o` | byte que se escribe en la FIFO TX |
| `tx_data_valid_o` | solicita la escritura de `tx_data_o` |
| `tx_begin_o` | abre un payload nuevo y reinicia su puntero interno |
| `tx_start_o` | comienza la transmisión LoRa con los bytes almacenados |
| `rx_start_o` | coloca el SX1278 en recepción continua |
| `peripheral_reset_request_o` | solicita el reset físico del SX1278 |

### Salidas de respuesta

| Puerto | Función |
| --- | --- |
| `response_start_o` | pulso que inicia la respuesta UART |
| `response_command_o` | comando al cual corresponde la respuesta |
| `response_status_o` | ACK o NACK |
| `response_data_o` | valor recibido si hay ACK; cero si hay NACK |

### Máquina de estados

| Estado | Función |
| --- | --- |
| `ST_WAIT_START` | descarta bytes hasta recibir `#` |
| `ST_WAIT_COMMAND` | captura `COMANDO` |
| `ST_WAIT_PARAMETER` | captura `PARAMETRO` |
| `ST_WAIT_VALUE` | captura `VALOR` |
| `ST_WAIT_CHECKSUM` | captura `CHECKSUM` |
| `ST_WAIT_END` | exige `$`; un valor diferente genera NACK |
| `ST_DECODE` | valida y genera el pulso correspondiente |
| `ST_RESPONSE` | activa `response_start_o` durante un ciclo |

El ACK confirma que la FPGA aceptó la orden y generó el pulso hacia el
controlador. No espera la finalización de la operación SPI. Si el controlador
está ocupado al llegar `ST_DECODE`, se responde NACK y el host puede reintentar.

El bloque tiene un único proceso secuencial, `register_process`, que actualiza
`state_now` y copia todos los valores D a sus registros Q. `output_logic`
calcula los próximos valores D junto con los pulsos de control y la transición
de estado se decide independientemente en `next_state_logic`.

## Validadores

`command_acceptance_validator` verifica las familias de comandos, las acciones
de control y las direcciones y rangos admitidos por el banco de configuración.
El checksum y la disponibilidad del controlador se filtran en `ST_DECODE`. El
resultado final es binario: el comando se acepta o se responde NACK.
`RESET_PERIPH` puede aceptarse incluso si el controlador está ocupado, para
permitir recuperar el sistema.

## Comandos

| Comando | Código | Parámetro | Valor |
| --- | ---: | --- | --- |
| `CONFIG_WRITE` | `0x01` | dirección de configuración | valor almacenado |
| `CONTROL` | `0x02` | acción de control | argumento de la acción |
| `TX_WRITE` | `0x03` | índice informativo | byte escrito en la FIFO |

### Direcciones de configuración

| Dirección | Configuración | Valores admitidos |
| ---: | --- | --- |
| `0x00` | `FRF_MSB` | `0..255` |
| `0x01` | `FRF_MID` | `0..255` |
| `0x02` | `FRF_LSB` | `0..255` |
| `0x03` | `BANDWIDTH` | `0..9` |
| `0x04` | `CODING_RATE` | `1..4` |
| `0x05` | `SPREADING_FACTOR` | `6..12` |
| `0x06` | `PREAMBLE_MSB` | `0..255` |
| `0x07` | `PREAMBLE_LSB` | `0..255` |
| `0x08` | `TX_POWER_DBM` | `2..17` |

Ejemplo para escribir `FRF_MSB=0x6C`:

```text
23 01 00 6C 6D 24
```

### Acciones de control

| Acción | Código | Valor |
| --- | ---: | --- |
| `APPLY_CONFIG` | `0x01` | ignorado |
| `RESET_PERIPH` | `0x02` | ignorado |
| `TX_START` | `0x03` | ignorado |
| `RX_START` | `0x04` | ignorado |
| `TX_BEGIN` | `0x05` | ignorado |

## Secuencia TX

`TX_BEGIN` abre un payload nuevo y hace que el manager de TX reinicie su puntero
interno. Cada `TX_WRITE` carga un byte consecutivo en la RAM y `TX_START` toma
como longitud la cantidad acumulada, prepara la FIFO del radio, escribe el
payload e inicia la transmisión. Para transmitir `ING`:

```text
23 02 05 00 07 24  -- TX_BEGIN
23 03 00 49 4A 24  -- 'I'
23 03 00 4E 4D 24  -- 'N'
23 03 00 47 44 24  -- 'G'
23 02 03 00 01 24  -- TX_START
```

El parámetro de `TX_WRITE` se ignora. La dirección de escritura y la longitud
se administran internamente, por orden de llegada.

## Recepción de un paquete y evento UART

El usuario envía `CTRL_RX_START`. Después del ACK, el SX1278 entra en
`RXSINGLE`. Cuando `DIO0` indica `RxDone`, el controlador lee la FIFO y
`uart_rx_serializer`, seleccionado por `uart_tx_master`, envía automáticamente:

```text
[#] [0x80] [LONGITUD] [PAYLOAD...] [CHECKSUM] [$]
```

El checksum es el XOR de `0x80`, la longitud y todo el payload. Para `ABC`:

```text
23 80 03 41 42 43 C3 24
```

No existe `RX_READ`: la recepción no pasa por `command_decoder` y el paquete se
emite por UART apenas queda disponible. Después, RX vuelve a reposo; para leer
otro paquete se debe enviar otra petición `CTRL_RX_START`.

## Script de control

```powershell
py -3.13 .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 config
py -3.13 .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 tx-text "ING_NRT"
py -3.13 .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 reset
py -3.13 .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 3 rx
```

`rx` mantiene al SX1278 en recepción continua hasta detectar un paquete. Después
de entregarlo en hexadecimal y ASCII, el controlador vuelve a standby. Si todavía
no llegó un paquete, la espera puede cancelarse con `Ctrl+C`.

Se recomienda `--command-delay 0.020`, equivalente a una pausa de 20 ms entre
solicitudes UART, junto con `--retries 3`. En la validación sobre la Zybo esta
configuración completó 10 de 10 transmisiones. Sin reintentos se observaron NACK
o respuestas incompletas ocasionales incluso con pausas mayores.

El script reintenta cada solicitud hasta tres veces cuando recibe NACK, vence el
timeout o la respuesta posee checksum o delimitadores incorrectos. La cantidad
puede cambiarse, por ejemplo:

```powershell
py -3.13 .\scripts\lora_uart_commands.py --port COM3 --command-delay 0.020 --retries 5 tx-text "ING_NRT"
```

Antes de cada reintento se descarta cualquier respuesta parcial y se respeta
`--command-delay`. Con `--no-ack` no se espera respuesta y, por lo tanto, no se
realizan reintentos.
