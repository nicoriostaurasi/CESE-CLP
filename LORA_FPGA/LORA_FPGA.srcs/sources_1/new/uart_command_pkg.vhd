----------------------------------------------------------------------------------
-- Package Name: uart_command_pkg
-- Description: Constantes compartidas por los bloques que implementan el
--              protocolo UART de comandos y respuestas.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package uart_command_pkg is

    constant CMD_CONFIG_WRITE : std_logic_vector(8-1 downto 0) := x"01";
    constant CMD_CONTROL : std_logic_vector(8-1 downto 0) := x"02";
    constant CMD_TX_WRITE : std_logic_vector(8-1 downto 0) := x"03";
    constant CTRL_APPLY_CONFIG : std_logic_vector(8-1 downto 0) := x"01";
    constant CTRL_RESET_PERIPH : std_logic_vector(8-1 downto 0) := x"02";
    constant CTRL_TX_START : std_logic_vector(8-1 downto 0) := x"03";
    constant CTRL_RX_START : std_logic_vector(8-1 downto 0) := x"04";
    constant CTRL_TX_BEGIN : std_logic_vector(8-1 downto 0) := x"05";

    constant UART_ACK : std_logic_vector(8-1 downto 0) := x"06";
    constant UART_NACK : std_logic_vector(8-1 downto 0) := x"15";
    constant UART_FRAME_START : std_logic_vector(8-1 downto 0) := x"23";
    constant UART_FRAME_END : std_logic_vector(8-1 downto 0) := x"24";
    constant UART_EVENT_RX_PACKET : std_logic_vector(8-1 downto 0) := x"80";

end package uart_command_pkg;

package body uart_command_pkg is
end package body uart_command_pkg;
