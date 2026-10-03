----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 01.10.2026
-- Design Name:
-- Module Name: uart_rx_serializer - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Serializa un paquete LoRa recibido utilizando la trama UART:
--              [#][RX_PACKET][LONGITUD][PAYLOAD...][CHECKSUM][$].
--              Recorre el buffer RX mediante un indice y notifica cuando el
--              paquete completo fue entregado al host.
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

entity uart_rx_serializer is
    generic (
        MAX_DATA_BYTES : integer := 50
    );
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono de la MEF y del contador de bytes.
        rst : in std_logic;

        -- Acceso al paquete almacenado por sx1278_controller.
        -- Indica que hay un paquete pendiente para transmitir.
        rx_packet_valid_i : in std_logic;
        -- Cantidad de bytes del payload.
        rx_packet_length_i : in std_logic_vector(6-1 downto 0);
        -- Indice solicitado al buffer RX.
        rx_packet_index_o : out std_logic_vector(6-1 downto 0);
        -- Byte devuelto por el buffer RX.
        rx_packet_data_i : in std_logic_vector(8-1 downto 0);
        -- Pulso que informa que la trama UART completa fue enviada.
        rx_packet_sent_o : out std_logic;

        -- Arbitraje con uart_tx_master. El paquete permanece pendiente hasta
        -- recibir enable y se transmite completo sin intercalar respuestas.
        -- Solicita al master el uso exclusivo del transmisor UART.
        request_o : out std_logic;
        -- Concesion del master para comenzar la trama.
        enable_i : in std_logic;
        -- Pulso generado al finalizar el evento RX completo.
        done_o : out std_logic;

        -- Interfaz byte a byte con el transmisor UART compartido.
        -- Pulso que indica que termino el byte UART anterior.
        uart_ready_i : in std_logic;
        -- Byte actual presentado al transmisor UART.
        uart_data_o : out std_logic_vector(8-1 downto 0);
        -- Pulso que inicia la transmision de uart_data_o.
        uart_wr_o : out std_logic
    );
end uart_rx_serializer;

architecture Behavioral of uart_rx_serializer is

    type t_state is (ST_IDLE, ST_SEND_BYTE, ST_WAIT_BYTE, ST_FINISH);

    signal state_now : t_state;
    signal state_next : t_state;
    signal byte_index : unsigned(6-1 downto 0);
    signal byte_counter_rst : std_logic;
    signal byte_counter_ena : std_logic;
    signal byte_counter_tc : std_logic;
    signal packet_length : unsigned(6-1 downto 0);
    signal packet_length_load : std_logic;
    signal packet_checksum : std_logic_vector(8-1 downto 0);
    signal packet_checksum_load : std_logic;
    signal packet_checksum_ena : std_logic;
    signal rx_packet_length_byte : std_logic_vector(8-1 downto 0);
    signal packet_length_byte : std_logic_vector(8-1 downto 0);
    signal initial_packet_checksum : std_logic_vector(8-1 downto 0);
    signal payload_byte_selected : std_logic;
    signal checksum_byte_selected : std_logic;
    signal checksum_byte_index : unsigned(6-1 downto 0);
    signal last_byte_index : unsigned(6-1 downto 0);

begin

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

    -- El master solamente concede enable luego de observar request_o. Por lo
    -- tanto enable_i ya implica que existe un paquete RX pendiente.
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

    -- La MEF solamente coordina los bloques de datos mediante senales de
    -- control. Los contadores y registros no necesitan conocer sus estados.
    output_logic : process(state_now, enable_i, payload_byte_selected,
                           uart_ready_i, byte_counter_tc)
    begin
        byte_counter_rst<='0';
        byte_counter_ena<='0';
        packet_length_load<='0';
        packet_checksum_load<='0';
        packet_checksum_ena<='0';
        uart_wr_o<='0';
        done_o<='0';
        rx_packet_sent_o<='0';

        case state_now is
            when ST_IDLE =>
                byte_counter_rst<='1';
                if enable_i='1' then
                    packet_length_load<='1';
                    packet_checksum_load<='1';
                end if;
            when ST_SEND_BYTE =>
                uart_wr_o<='1';
                if payload_byte_selected='1' then
                    packet_checksum_ena<='1';
                end if;
            when ST_WAIT_BYTE =>
                if uart_ready_i='1' and byte_counter_tc='0' then
                    byte_counter_ena<='1';
                end if;
            when ST_FINISH =>
                done_o<='1';
                rx_packet_sent_o<='1';
        end case;
    end process;

    byte_counter : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' or byte_counter_rst='1' then
                byte_index<=TO_UNSIGNED(0,byte_index'length);
                byte_counter_tc<='0';
            elsif byte_counter_ena='1' then
                byte_index<=byte_index+TO_UNSIGNED(1,byte_index'length);
                if byte_index=last_byte_index-TO_UNSIGNED(1,byte_index'length) then
                    byte_counter_tc<='1';
                else
                    byte_counter_tc<='0';
                end if;
            end if;
        end if;
    end process;

    packet_registers : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                packet_length<=TO_UNSIGNED(0,packet_length'length);
                packet_checksum<=(others=>'0');
            else
                if packet_length_load='1' then
                    packet_length<=unsigned(rx_packet_length_i);
                end if;

                if packet_checksum_load='1' then
                    packet_checksum<=initial_packet_checksum;
                elsif packet_checksum_ena='1' then
                    packet_checksum<=packet_checksum xor rx_packet_data_i;
                end if;
            end if;
        end if;
    end process;

    request_o<=rx_packet_valid_i;

    rx_packet_length_byte<="00" & rx_packet_length_i;
    packet_length_byte<="00" & std_logic_vector(packet_length);
    initial_packet_checksum<=UART_EVENT_RX_PACKET xor rx_packet_length_byte;

    payload_byte_selected<='1' when byte_index>=TO_UNSIGNED(3,byte_index'length) and
                        byte_index<packet_length+TO_UNSIGNED(3,byte_index'length)
                        else '0';

    checksum_byte_index<=packet_length+TO_UNSIGNED(3,packet_length'length);
    checksum_byte_selected<='1' when byte_index=checksum_byte_index else '0';

    uart_data_o<=UART_FRAME_START when byte_index=TO_UNSIGNED(0,6) else 
             UART_EVENT_RX_PACKET when byte_index=TO_UNSIGNED(1,6) else 
             packet_length_byte when byte_index=TO_UNSIGNED(2,6) else 
             rx_packet_data_i when payload_byte_selected='1' else 
             packet_checksum when checksum_byte_selected='1' else 
             UART_FRAME_END;

    last_byte_index<=checksum_byte_index+TO_UNSIGNED(1,last_byte_index'length);
    rx_packet_index_o<=std_logic_vector(byte_index-TO_UNSIGNED(3,6)) when payload_byte_selected='1' else (others=>'0');

end Behavioral;
