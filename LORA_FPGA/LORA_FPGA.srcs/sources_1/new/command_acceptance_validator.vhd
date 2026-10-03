----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 21.09.2026 18:52:34
-- Design Name:
-- Module Name: command_acceptance_validator - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Valida el comando UART, sus parametros y los rangos de los
--              registros configurables. El encuadre, el checksum y la
--              disponibilidad del SX1278 pertenecen al command_decoder.
--
-- Dependencies: uart_command_pkg, sx1278_controller_pkg
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.uart_command_pkg.all;
use work.sx1278_controller_pkg.all;

entity command_acceptance_validator is
    port (
        -- Codigo de operacion recibido por UART.
        command_i : in std_logic_vector(8-1 downto 0);
        -- Parametro o direccion asociado al comando.
        parameter_i : in std_logic_vector(8-1 downto 0);
        -- Valor transportado por el comando.
        value_i : in std_logic_vector(8-1 downto 0);

        -- Indica que comando, parametro y valor forman una orden valida.
        command_accepted_o : out std_logic
    );
end command_acceptance_validator;

architecture Behavioral of command_acceptance_validator is

    -- Este bloque es combinacional. Se mantiene separado del decoder para que
    -- la MEF solo se ocupe de recibir la trama y emitir acciones.
    signal valid_control_command : std_logic;
    signal valid_config_command : std_logic;
    signal bandwidth_in_range : std_logic;
    signal coding_rate_in_range : std_logic;
    signal spreading_factor_in_range : std_logic;
    signal tx_power_in_range : std_logic;
    signal valid_command : std_logic;

begin

    -- Rangos definidos por los campos LoRa del SX1278. Frecuencia y preambulo
    -- se transmiten como bytes sin codificacion y aceptan cualquier valor.
    bandwidth_in_range<='1' when
            unsigned(value_i)<=TO_UNSIGNED(9,8)
        else '0';

    coding_rate_in_range<='1' when
            unsigned(value_i)>=TO_UNSIGNED(1,8) and
            unsigned(value_i)<=TO_UNSIGNED(4,8)
        else '0';

    spreading_factor_in_range<='1' when
            unsigned(value_i)>=TO_UNSIGNED(6,8) and
            unsigned(value_i)<=TO_UNSIGNED(12,8)
        else '0';

    tx_power_in_range<='1' when
            unsigned(value_i)>=TO_UNSIGNED(2,8) and
            unsigned(value_i)<=TO_UNSIGNED(17,8)
        else '0';

    -- Las constantes de direccion tienen el mismo ancho que el parametro UART.
    -- Una direccion desconocida cae directamente en others, sin validacion
    -- adicional del nibble superior ni posibilidad de alias.
    with parameter_i select
        valid_config_command<=
            '1' when CFG_FRF_MSB |
                     CFG_FRF_MID |
                     CFG_FRF_LSB |
                     CFG_PREAMBLE_MSB |
                     CFG_PREAMBLE_LSB,
            bandwidth_in_range when CFG_BANDWIDTH,
            coding_rate_in_range when CFG_CODING_RATE,
            spreading_factor_in_range when CFG_SPREADING_FACTOR,
            tx_power_in_range when CFG_TX_POWER_DBM,
            '0' when others;

    -- Aunque todos los errores terminan en un mismo NACK, es necesario
    -- reconocer las acciones existentes. De otro modo un CONTROL desconocido
    -- seria confirmado con ACK aunque no produjera ninguna accion.
    with parameter_i select
        valid_control_command<=
            '1' when CTRL_RESET_PERIPH |
                     CTRL_APPLY_CONFIG |
                     CTRL_TX_BEGIN |
                     CTRL_TX_START |
                     CTRL_RX_START,
            '0' when others;

    -- Cada familia selecciona su regla. TX_WRITE acepta el byte sin controlar
    -- el indice, decision tomada para mantener simple el trabajo practico.
    with command_i select
        valid_command<=
            valid_config_command when CMD_CONFIG_WRITE,
            valid_control_command when CMD_CONTROL,
            '1' when CMD_TX_WRITE,
            '0' when others;

    -- El decoder ya verifico delimitadores y checksum antes de consultar esta
    -- salida, que representa solamente la validez semantica del comando.
    command_accepted_o<=valid_command;

end Behavioral;
