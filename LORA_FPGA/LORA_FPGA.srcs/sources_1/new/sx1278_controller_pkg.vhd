----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.09.2026 12:03:59
-- Design Name: 
-- Module Name: sx1278_controller_pkg - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Tipos, direcciones de configuracion, comandos de registro y
--              frames SPI constantes compartidos por los bloques SX1278.
-- 
-- Dependencies: Ninguna
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package sx1278_controller_pkg is
    constant CFG_FRF_MSB            : std_logic_vector(8-1 downto 0) := x"00";
    constant CFG_FRF_MID            : std_logic_vector(8-1 downto 0) := x"01";
    constant CFG_FRF_LSB            : std_logic_vector(8-1 downto 0) := x"02";
    constant CFG_BANDWIDTH          : std_logic_vector(8-1 downto 0) := x"03";
    constant CFG_CODING_RATE        : std_logic_vector(8-1 downto 0) := x"04";
    constant CFG_SPREADING_FACTOR   : std_logic_vector(8-1 downto 0) := x"05";
    constant CFG_PREAMBLE_MSB       : std_logic_vector(8-1 downto 0) := x"06";
    constant CFG_PREAMBLE_LSB       : std_logic_vector(8-1 downto 0) := x"07";
    constant CFG_TX_POWER_DBM       : std_logic_vector(8-1 downto 0) := x"08";

    -- Una palabra representa los dos bytes transferidos mientras NSS
    -- permanece activo: comando/direccion y dato (o byte dummy de lectura).
    subtype t_spi_frame is std_logic_vector(16-1 downto 0);
    type t_spi_sequence is array(natural range <>) of t_spi_frame;

    -- Operaciones que el controlador puede delegar al constructor y al
    -- secuenciador de frames SPI.
    type t_sx1278_operation is (
        OP_CONFIG,
        OP_TX_BEGIN,
        OP_TX_WRITE,
        OP_TX_START,
        OP_TX_CLEAR,
        OP_RX_SETUP,
        OP_RX_IRQ,
        OP_RX_LENGTH,
        OP_RX_ADDRESS,
        OP_RX_POINTER,
        OP_RX_FIFO,
        OP_RX_CLEAR
    );

    -- Bits y valores de IRQ utilizados por las secuencias TX y RX.
    constant IRQ_TX_DONE : std_logic_vector(8-1 downto 0) := x"08";
    constant IRQ_RX_CLEAR : std_logic_vector(8-1 downto 0) := x"60";
    constant IRQ_PAYLOAD_CRC_ERROR_BIT : integer := 5;

    -- Secuencias completas cuyos bytes no dependen de la configuracion ni
    -- del payload recibido desde la interfaz UART.
    constant TX_BEGIN_SEQUENCE : t_spi_sequence(0 to 2-1) :=
        (x"8189", x"8D00");

    constant RX_SETUP_SEQUENCE : t_spi_sequence(0 to 3-1) :=
        (x"C000", x"92FF", x"818D");

    -- Tras capturar un unico paquete se limpian las IRQ y se vuelve a
    -- standby. El uso de RxContinuous durante la espera evita que el timeout
    -- interno de RxSingle finalice antes de que el usuario ordene transmitir.
    constant RX_CLEAR_SEQUENCE : t_spi_sequence(0 to 2-1) :=
        (x"9260", x"8189");

    -- Frames fijos y bytes de comando reutilizados por el controlador.
    constant FRAME_LORA_SLEEP : t_spi_frame := x"8188";
    constant FRAME_LORA_STANDBY : t_spi_frame := x"8189";
    constant FRAME_MODEM_CONFIG_3 : t_spi_frame := x"A604";
    constant FRAME_LNA_CONFIG : t_spi_frame := x"8C23";
    constant FRAME_FIFO_TX_BASE : t_spi_frame := x"8E00";
    constant FRAME_FIFO_RX_BASE : t_spi_frame := x"8F00";
    constant FRAME_CLEAR_ALL_IRQ : t_spi_frame := x"92FF";
    constant FRAME_DIO0_TX_DONE : t_spi_frame := x"C040";
    constant FRAME_TX_MODE : t_spi_frame := x"818B";
    constant FRAME_CLEAR_TX_DONE : t_spi_frame := x"9208";
    constant FRAME_READ_IRQ : t_spi_frame := x"1200";
    constant FRAME_READ_RX_LENGTH : t_spi_frame := x"1300";
    constant FRAME_READ_RX_ADDRESS : t_spi_frame := x"1000";
    constant FRAME_READ_FIFO : t_spi_frame := x"0000";
    constant FRAME_CLEAR_RX_IRQ : t_spi_frame := x"9260";
    constant FRAME_RX_CONTINUOUS : t_spi_frame := x"818D";

    constant CMD_WRITE_FIFO : std_logic_vector(8-1 downto 0) := x"80";
    constant CMD_WRITE_FRF_MSB : std_logic_vector(8-1 downto 0) := x"86";
    constant CMD_WRITE_FRF_MID : std_logic_vector(8-1 downto 0) := x"87";
    constant CMD_WRITE_FRF_LSB : std_logic_vector(8-1 downto 0) := x"88";
    constant CMD_WRITE_PA_CONFIG : std_logic_vector(8-1 downto 0) := x"89";
    constant CMD_WRITE_FIFO_POINTER : std_logic_vector(8-1 downto 0) := x"8D";
    constant CMD_WRITE_MODEM_CONFIG_1 : std_logic_vector(8-1 downto 0) := x"9D";
    constant CMD_WRITE_MODEM_CONFIG_2 : std_logic_vector(8-1 downto 0) := x"9E";
    constant CMD_WRITE_PREAMBLE_MSB : std_logic_vector(8-1 downto 0) := x"A0";
    constant CMD_WRITE_PREAMBLE_LSB : std_logic_vector(8-1 downto 0) := x"A1";
    constant CMD_WRITE_PAYLOAD_LENGTH : std_logic_vector(8-1 downto 0) := x"A2";
end package sx1278_controller_pkg;
