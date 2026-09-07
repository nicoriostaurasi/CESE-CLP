|    CMD | Significado        | DATA              |
| -----: | ------------------ | ----------------- |
| `0x01` | `SET_FRF_MSB`      | byte FRF[23:16]   |
| `0x02` | `SET_FRF_MID`      | byte FRF[15:8]    |
| `0x03` | `SET_FRF_LSB`      | byte FRF[7:0]     |
| `0x04` | `SET_BW`           | 0–9               |
| `0x05` | `SET_CR`           | 1–4               |
| `0x06` | `SET_SF`           | 6–12              |
| `0x07` | `SET_POWER`        | dBm               |
| `0x08` | `SET_PREAMBLE_MSB` | byte [15:8]       |
| `0x09` | `SET_PREAMBLE_LSB` | byte [7:0]        |
| `0x0A` | `APPLY_CONFIG`     | ignorado / `0x00` |
