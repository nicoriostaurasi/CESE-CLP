# Reloj de 125 MHz y reset activo alto mediante BTN0.
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4.000} [get_ports clk]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports rst]

# LED de estado: heartbeat, UART, busy y error.
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {status_led_o[0]}]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports {status_led_o[1]}]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports {status_led_o[2]}]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {status_led_o[3]}]

# SPI en JE
# JE1 -> CLK
# JE2 -> MOSI
# JE3 -> MISO
# JE4 -> NSS
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports spi_sclk_o]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports spi_mosi_o]
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports spi_miso_i]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports spi_nss_o]

# Control en JD
# JD3 (R14): entrada FPGA  <- DIO0 del SX1278.
# JD4 (P14): salida FPGA   -> RESET del SX1278.
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports sx1278_dio0_i]
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports sx1278_reset_o]

# UART de comandos conectada al adaptador USB-UART de la PC.
# Pines fisicos 1 y 2 del conector Pmod JD (Zybo Rev. B).
# JD1 (T14 / JD1_P): entrada FPGA  <- TX de la PC.
# JD2 (T15 / JD1_N): salida FPGA   -> RX de la PC.
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports uart_rx_i]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports uart_tx_o]
