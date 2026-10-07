# Plan de pruebas por DUT

Cada caso se ejecuta como una simulación independiente. El archivo
`testbench-NN-descripcion.py` define la secuencia concreta y la clase derivada
de `BaseTest`. La secuencia llama a los agentes mediante el sequencer; todas
las comprobaciones permanecen en el scoreboard del DUT.

```text
testbench-NN.py
       |
       +----> ResetSequence ----> rst
       |
       v
   Sequence ----> Agent ----> wrapper VHDL ----> DUT
                    |                            |
                    +---------- eventos --------+
                                 |
                                 v
                         Scoreboard + mock
```

## UART

| Archivo | Escenario |
|---|---|
| `testbench-00-tx-byte.py` | Transmite un byte por TX. |
| `testbench-01-tx-multiple-bytes.py` | Transmite varios bytes consecutivos. |
| `testbench-02-rx-byte.py` | Recibe un byte por RX. |
| `testbench-03-rx-multiple-bytes.py` | Recibe varios bytes consecutivos. |
| `testbench-04-tx-rx.py` | Alterna TX y RX con distintos patrones. |
| `testbench-05-vhdl-patterns.py` | Reproduce `AA`, `00`, `FF` y `55` de los testbenchs VHDL. |

## SPI

| Caso | Escenario |
|---|---|
| `testbench-00-single-frame.py` | Transmisión de una trama de dos bytes. |
| `testbench-01-multiple-frames.py` | Varias tramas y pausas entre ellas. |
| `testbench-02-vhdl-regression.py` | Reproduce las tramas de cuatro y dos bytes del testbench VHDL. |

## Command decoder

| Caso | Escenario |
|---|---|
| `testbench-00-config-write.py` | Comando de escritura de configuración válido. |
| `testbench-01-tx-write.py` | Carga de un byte del payload TX. |
| `testbench-02-bad-checksum.py` | Checksum alterado y respuesta NACK. |
| `testbench-03-bad-end.py` | Delimitador final alterado y respuesta NACK. |

## UART TX master

| Caso | Escenario |
|---|---|
| `testbench-00-ack-response.py` | Serialización de una respuesta ACK. |
| `testbench-01-rx-packet.py` | Evento RX con payload de varios bytes. |

## SX1278 controller

| Caso | Escenario |
|---|---|
| `testbench-00-config.py` | Secuencia SPI completa de configuración. |
| `testbench-01-tx.py` | Carga y transmisión de un payload. |
| `testbench-02-rx.py` | Configuración RX, DIO0 y lectura del payload. |
| `testbench-03-vhdl-tx-sequence.py` | Payload `A5 96 81` utilizado por el testbench VHDL. |

## Top LORA UART

| Caso | Escenario |
|---|---|
| `testbench-00-config.py` | Comandos UART de configuración y secuencia SPI. |
| `testbench-01-tx.py` | Carga UART del payload y transmisión LoRa. |
| `testbench-02-rx.py` | Solicitud UART, recepción LoRa y evento UART. |
| `testbench-03-rx-crc-retry.py` | Descarta CRC inválido, rearma RX y entrega el paquete válido siguiente. |
| `testbench-04-consecutive-tx.py` | Transmite `SOL` e `ING NRT` consecutivamente. |
| `testbench-05-rx-reset-cancel.py` | Cancela la espera RX mediante reset y acepta el comando siguiente. |

El runner descubre automáticamente todos los archivos `testbench*.py`. Cada
waveform se guarda en `verification/waveforms/<suite>/<caso>.ghw`.
