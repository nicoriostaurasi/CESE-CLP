----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 02.10.2026 01:18:07
-- Design Name:
-- Module Name: sx1278_config_manager - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Gestiona la aplicacion de la configuracion del SX1278. Solicita
--              al arbitro la secuencia OP_CONFIG y espera su finalizacion.
--
-- Dependencies: sx1278_controller_pkg
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sx1278_controller_pkg.all;

entity sx1278_config_manager is
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono de la MEF.
        rst : in std_logic;
        -- Pulso que inicia la secuencia de configuracion.
        start_i : in std_logic;
        -- Byte FRF mas significativo.
        frf_msb_i : in std_logic_vector(8-1 downto 0);
        -- Byte FRF intermedio.
        frf_mid_i : in std_logic_vector(8-1 downto 0);
        -- Byte FRF menos significativo.
        frf_lsb_i : in std_logic_vector(8-1 downto 0);
        -- Codigo de ancho de banda.
        bandwidth_i : in std_logic_vector(4-1 downto 0);
        -- Codigo de tasa de codificacion.
        coding_rate_i : in std_logic_vector(3-1 downto 0);
        -- Factor de ensanchamiento.
        spreading_factor_i : in std_logic_vector(4-1 downto 0);
        -- Byte superior del preambulo.
        preamble_msb_i : in std_logic_vector(8-1 downto 0);
        -- Byte inferior del preambulo.
        preamble_lsb_i : in std_logic_vector(8-1 downto 0);
        -- Valor codificado para RegPaConfig.
        pa_config_i : in std_logic_vector(8-1 downto 0);
        -- Solicitud de propiedad del secuenciador SPI.
        sequence_request_o : out std_logic;
        -- Indice del frame requerido por el secuenciador.
        sequence_step_i : in std_logic_vector(4-1 downto 0);
        -- Frame SPI correspondiente al indice actual.
        sequence_frame_o : out std_logic_vector(16-1 downto 0);
        -- Indice del ultimo frame de configuracion.
        sequence_last_step_o : out std_logic_vector(4-1 downto 0);
        -- Pulso que informa el fin de la secuencia SPI.
        sequence_done_i : in std_logic;
        -- Indica que la configuracion esta en curso.
        busy_o : out std_logic;
        -- Pulso que informa la configuracion terminada.
        done_o : out std_logic
    );
end sx1278_config_manager;

architecture Behavioral of sx1278_config_manager is
    type t_state is (ST_IDLE, ST_REQUEST, ST_DONE);
    signal state_now : t_state;
    signal state_next : t_state;
    signal config_sequence : t_spi_sequence(0 to 15-1);
    signal modem_config_1 : std_logic_vector(8-1 downto 0);
    signal modem_config_2 : std_logic_vector(8-1 downto 0);
begin
    state_register : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state_now<=ST_IDLE;
            else
                state_now<=state_next;
            end if;
        end if;
    end process;

    next_state_logic : process(state_now,start_i,sequence_done_i)
    begin
        state_next<=state_now;
        case state_now is
            when ST_IDLE =>
                if start_i='1' then
                    state_next<=ST_REQUEST;
                end if;
            when ST_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_DONE;
                end if;
            when ST_DONE =>
                state_next<=ST_IDLE;
        end case;
    end process;

    modem_config_1<=bandwidth_i & coding_rate_i & '0';
    modem_config_2<=spreading_factor_i & "0100";

    config_sequence(0)<=FRAME_LORA_SLEEP;
    config_sequence(1)<=FRAME_LORA_STANDBY;
    config_sequence(2)<=CMD_WRITE_FRF_MSB & frf_msb_i;
    config_sequence(3)<=CMD_WRITE_FRF_MID & frf_mid_i;
    config_sequence(4)<=CMD_WRITE_FRF_LSB & frf_lsb_i;
    config_sequence(5)<=CMD_WRITE_MODEM_CONFIG_1 & modem_config_1;
    config_sequence(6)<=CMD_WRITE_MODEM_CONFIG_2 & modem_config_2;
    config_sequence(7)<=FRAME_MODEM_CONFIG_3;
    config_sequence(8)<=CMD_WRITE_PREAMBLE_MSB & preamble_msb_i;
    config_sequence(9)<=CMD_WRITE_PREAMBLE_LSB & preamble_lsb_i;
    config_sequence(10)<=CMD_WRITE_PA_CONFIG & pa_config_i;
    config_sequence(11)<=FRAME_LNA_CONFIG;
    config_sequence(12)<=FRAME_FIFO_TX_BASE;
    config_sequence(13)<=FRAME_FIFO_RX_BASE;
    config_sequence(14)<=FRAME_CLEAR_ALL_IRQ;

    sequence_frame_o<=config_sequence(to_integer(unsigned(sequence_step_i)));
    sequence_last_step_o<=std_logic_vector(TO_UNSIGNED(14,sequence_last_step_o'length));

    -- Las salidas de control dependen exclusivamente del estado actual. La
    -- configuracion solo escribe registros, por lo que no necesita exponer
    -- una seleccion de lectura hacia el arbitro SPI.
    output_logic : process(state_now)
    begin
        sequence_request_o<='0';
        busy_o<='1';
        done_o<='0';

        case state_now is
            when ST_IDLE =>
                busy_o<='0';
            when ST_REQUEST =>
                sequence_request_o<='1';
            when ST_DONE =>
                done_o<='1';
        end case;
    end process;
end Behavioral;
