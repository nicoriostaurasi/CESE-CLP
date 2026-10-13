
MOSI 0x81 0x88 -> RegOpMode[0x01] = 0x88 {LongRangeMode=LoRa; AccessSharedReg=LoRa-page; LowFrequencyModeOn=LF; Mode=SLEEP} | MISO 0xFF 0xFF | NSS: 0 -> 1
MOSI 0x81 0x89 -> RegOpMode[0x01] = 0x89 {LongRangeMode=LoRa; AccessSharedReg=LoRa-page; LowFrequencyModeOn=LF; Mode=STDBY} | MISO 0xFF 0xFF | NSS: 0 -> 1
[0x01]-> 
7: 1 (HC)
6: 0 (HC)
5-4: 0 (HC)
3: 1 (HC)
2-0: 8 modos (no deberia ser configurable por el usuario..) (SLEEP->STDBY) (HC CONFIG)

MOSI 0x86 0x6C -> RegFrfMsb[0x06] = 0x6C {Frf[23:16]=0x6C} | MISO 0xFF 0xFF | NSS: 0 -> 1
MOSI 0x87 0x40 -> RegFrfMid[0x07] = 0x40 {Frf[15:8]=0x40} | MISO 0xFF 0xFF | NSS: 0 -> 1
MOSI 0x88 0x00 -> RegFrfLsb[0x08] = 0x00 {Frf[7:0]=0x00} | MISO 0xFF 0xFF | NSS: 0 -> 1
[0x06, 0x07, 0x08] -> Carrier Freq 
0x6C-0x40-0x00 = 7.094.272 (Freq) (enviar en 3 comandos distintos cada byte, que el script lo procese cuando lo reciba el..)

MOSI 0x9D 0x72 -> RegModemConfig1[0x1D] = 0x72 {Bw=125kHz; CodingRate=4/5; HeaderMode=EXPLICIT} | MISO 0xFF 0xFF | NSS: 0 -> 1
[0x1D] -> 
7-4: acepta un byte de 0 a 9.. (BW) (CODIFICADO)
3-1: un byte pero de 1 a 4 (CR) (CODIFICADO)
0: 1 (HC)

MOSI 0x9E 0x74 -> RegModemConfig2[0x1E] = 0x74 {SpreadingFactor=SF7; TxContinuousMode=NORMAL; RxPayloadCrc=ON; SymbTimeout[9:8]=0} | MISO 0xFF 0xFF | NSS: 0 -> 1
[0x1E] -> 
7-4: acepta un byte de 6 a 12 (SF) (CODIFICADO)
3: 0 (HC)
2: 1 (HC)
1-0: 0 (HC)

MOSI 0xA6 0x04 -> RegModemConfig3[0x26] = 0x04 {LowDataRateOptimize=DISABLED; AgcAutoOn=ENABLED} | MISO 0xFF 0xFF | NSS: 0 -> 1
7-4: 0x00 (HC)
3: 0 (HC)
2: 1 (HC)
1-0: 0x00 (HC)

MOSI 0xA0 0x00 -> RegPreambleMsb[0x20] = 0x00 {PreambleLength[15:8]=0x00} | MISO 0xFF 0xFF | NSS: 0 -> 1
MOSI 0xA1 0x08 -> RegPreambleLsb[0x21] = 0x08 {PreambleLength[7:0]=0x08} | MISO 0xFF 0xFF | NSS: 0 -> 1
Preamble->8 (MANDAR COMO LA FREQ, aca es directo)

MOSI 0x89 0xFC -> RegPaConfig[0x09] = 0xFC {PaSelect=PA_BOOST; MaxPower=0x7; OutputPower=0xC} | MISO 0xFF 0xFF | NSS: 
0 -> 1
(Power)
Aca lo mejor es una tabla que convierta dbm de salida cada 1 dbm al valor escritura en registro
7:1
6-4: recibe de 0 a 7 10.8+0.6*reg
3-0: 
(RECIBIR EL VALOR EN DBM Y TENER LA TABLA HARCODEADA, que se reciba el dbm directo y se hace el pasaje con un mux)

MOSI 0x8C 0x23 -> RegLna[0x0C] = 0x23 {LnaGain=G1(max); LnaBoostLf=0x0; LnaBoostHf=BOOST_150%} | MISO 0xFF 0xFF | NSS: 0 -> 1
7-5:1 (HC)
4-3:0 (HC)
2: 0(HC)
1-0:3(HC)

Apuntar fifo
MOSI 0x8E 0x00 -> RegFifoTxBaseAddr[0x0E] = 0x00 {FifoTxBaseAddr=0x00} | MISO 0xFF 0xFF | NSS: 0 -> 1
MOSI 0x8F 0x00 -> RegFifoRxBaseAddr[0x0F] = 0x00 {FifoRxBaseAddr=0x00} | MISO 0xFF 0xFF | NSS: 0 -> 1
(HC)

Limpiar flags
(HC)
MOSI 0x92 0xFF -> RegIrqFlags[0x12] = 0xFF {Clear: RxTimeout=1; RxDone=1; PayloadCrcError=1; ValidHeader=1; TxDone=1; CadDone=1; FhssChangeChannel=1; CadDetected=1} | MISO 0xFF 0xFF | NSS: 0 -> 1

