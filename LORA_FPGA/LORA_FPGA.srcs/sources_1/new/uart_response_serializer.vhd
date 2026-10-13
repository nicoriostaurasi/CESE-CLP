----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 01.10.2026
-- Design Name:
-- Module Name: uart_response_serializer - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Serializa una respuesta UART de longitud fija:
--              [#][COMANDO][ESTADO][DATO][CHECKSUM][$].
--              Conserva la solicitud hasta que uart_tx_master habilita su
--              transmision y genera done al finalizar el ultimo byte.
--
-- Dependencies: uart_command_pkg
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

entity uart_response_serializer is
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono de la MEF y del contador de bytes.
        rst : in std_logic;

        -- Respuesta producida por command_decoder.
        -- Pulso que captura una respuesta nueva.
        response_start_i : in std_logic;
        -- Codigo del comando respondido.
        response_command_i : in std_logic_vector(8-1 downto 0);
        -- Resultado ACK o NACK.
        response_status_i : in std_logic_vector(8-1 downto 0);
        -- Dato incluido en la respuesta.
        response_data_i : in std_logic_vector(8-1 downto 0);

        -- Arbitraje con uart_tx_master. request permanece activo hasta que el
        -- master concede enable y la trama comienza a transmitirse.
        -- Solicita al master el uso exclusivo del transmisor UART.
        request_o : out std_logic;
        -- Concesion del master para comenzar la trama.
        enable_i : in std_logic;
        -- Pulso generado al finalizar la respuesta completa.
        done_o : out std_logic;

        -- Interfaz byte a byte con el transmisor UART compartido.
        -- Pulso que indica que termino el byte UART anterior.
        uart_ready_i : in std_logic;
        -- Byte actual presentado al transmisor UART.
        uart_data_o : out std_logic_vector(8-1 downto 0);
        -- Pulso que inicia la transmision de uart_data_o.
        uart_wr_o : out std_logic
    );
end uart_response_serializer;

architecture Behavioral of uart_response_serializer is

    type t_state is (ST_IDLE, ST_SEND_BYTE, ST_WAIT_BYTE, ST_FINISH);

    signal state_now : t_state;
    signal state_next : t_state;
    signal byte_index : unsigned(3-1 downto 0);
    signal byte_counter_tc : std_logic;
    signal byte_counter_rst : std_logic;
    signal byte_counter_ena : std_logic;
    signal response_pending : std_logic;
    signal command_reg : std_logic_vector(8-1 downto 0);
    signal status_reg : std_logic_vector(8-1 downto 0);
    signal data_reg : std_logic_vector(8-1 downto 0);
    signal checksum : std_logic_vector(8-1 downto 0);

begin

    -- Conserva la respuesta aunque el master se encuentre atendiendo RX.
    response_register : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                response_pending<='0';
                command_reg<=(others=>'0');
                status_reg<=(others=>'0');
                data_reg<=(others=>'0');
            elsif response_start_i='1' then
                response_pending<='1';
                command_reg<=response_command_i;
                status_reg<=response_status_i;
                data_reg<=response_data_i;
            elsif state_now=ST_IDLE and enable_i='1' and
                  response_pending='1' then
                response_pending<='0';
            end if;
        end if;
    end process;

    register_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state_now<=ST_IDLE;
            else
                state_now<=state_next;
            end if;
        end if;
    end process;

    -- La respuesta siempre contiene seis bytes. El contador solamente avanza
    -- cuando myUart informa que termino de transmitir el byte anterior.
    byte_counter : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' or byte_counter_rst='1' then
                byte_index<=TO_UNSIGNED(0,byte_index'length);
                byte_counter_tc<='0';
            elsif byte_counter_ena='1' then
                byte_index<=byte_index+TO_UNSIGNED(1,byte_index'length);
                -- Al avanzar desde CHECKSUM hacia END queda seleccionado el
                -- sexto byte y tc permanece activo hasta finalizar la trama.
                if byte_index=TO_UNSIGNED(4,byte_index'length) then
                    byte_counter_tc<='1';
                else
                    byte_counter_tc<='0';
                end if;
            end if;
        end if;
    end process;

    next_state_logic : process(state_now, enable_i, uart_ready_i,
                               byte_counter_tc)
    begin
        state_next<=state_now;

        case state_now is
            when ST_IDLE =>
                if enable_i='1' then
                    state_next<=ST_SEND_BYTE;
                end if;
            when ST_SEND_BYTE =>
                state_next<=ST_WAIT_BYTE;
            when ST_WAIT_BYTE =>
                if uart_ready_i='1' then
                    if byte_counter_tc='1' then
                        state_next<=ST_FINISH;
                    else
                        state_next<=ST_SEND_BYTE;
                    end if;
                end if;
            when ST_FINISH =>
                state_next<=ST_IDLE;
        end case;
    end process;

    output_logic : process(state_now, uart_ready_i, byte_counter_tc)
    begin
        byte_counter_rst<='0';
        byte_counter_ena<='0';
        uart_wr_o<='0';
        done_o<='0';

        case state_now is
            when ST_IDLE =>
                byte_counter_rst<='1';
            when ST_SEND_BYTE =>
                uart_wr_o<='1';
            when ST_WAIT_BYTE =>
                if uart_ready_i='1' and byte_counter_tc='0' then
                    byte_counter_ena<='1';
                end if;
            when ST_FINISH =>
                done_o<='1';
        end case;
    end process;

    request_o<=response_pending;

    checksum<=command_reg xor status_reg xor data_reg;

    uart_data_o<= UART_FRAME_START when byte_index=TO_UNSIGNED(0,3) else
                       command_reg when byte_index=TO_UNSIGNED(1,3) else
                        status_reg when byte_index=TO_UNSIGNED(2,3) else
                          data_reg when byte_index=TO_UNSIGNED(3,3) else
                          checksum when byte_index=TO_UNSIGNED(4,3) else
                    UART_FRAME_END;

end Behavioral;
