----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 01.10.2026
-- Design Name:
-- Module Name: uart_tx_master - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Integra los serializadores de respuestas y paquetes RX, y
--              arbitra su acceso al unico transmisor UART.
--              La fuente seleccionada conserva el bus hasta completar toda
--              su trama, evitando que se intercalen bytes de ambas fuentes.
--
-- Dependencies: uart_response_serializer, uart_rx_serializer
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_tx_master is
    generic (
        MAX_DATA_BYTES : integer := 50
    );
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono del arbitro y los serializadores.
        rst : in std_logic;

        -- Respuesta ACK/NACK generada por el decodificador de comandos.
        -- Pulso que presenta una respuesta nueva.
        response_start_i : in std_logic;
        -- Comando asociado a la respuesta.
        response_command_i : in std_logic_vector(8-1 downto 0);
        -- Resultado ACK o NACK.
        response_status_i : in std_logic_vector(8-1 downto 0);
        -- Dato asociado a la respuesta.
        response_data_i : in std_logic_vector(8-1 downto 0);

        -- Paquete recibido por LoRa y expuesto por el controlador SX1278.
        -- Indica que hay un paquete RX pendiente.
        rx_packet_valid_i : in std_logic;
        -- Cantidad de bytes del paquete RX.
        rx_packet_length_i : in std_logic_vector(6-1 downto 0);
        -- Indice solicitado al buffer RX.
        rx_packet_index_o : out std_logic_vector(6-1 downto 0);
        -- Byte obtenido del buffer RX.
        rx_packet_data_i : in std_logic_vector(8-1 downto 0);
        -- Pulso que libera el paquete RX transmitido.
        rx_packet_sent_o : out std_logic;

        -- Interfaz byte a byte con myUart.
        -- Pulso que indica el fin del byte UART anterior.
        uart_ready_i : in std_logic;
        -- Byte seleccionado entre los dos serializadores.
        uart_data_o : out std_logic_vector(8-1 downto 0);
        -- Pulso de escritura hacia myUart.
        uart_wr_o : out std_logic
    );
end uart_tx_master;

architecture Behavioral of uart_tx_master is

    type t_state is (ST_IDLE, ST_RESPONSE, ST_RX_PACKET);
    signal state_now : t_state;
    signal state_next : t_state;

    signal response_request : std_logic;
    signal response_enable : std_logic;
    signal response_done : std_logic;
    signal response_uart_data : std_logic_vector(8-1 downto 0);
    signal response_uart_wr : std_logic;

    signal rx_request : std_logic;
    signal rx_enable : std_logic;
    signal rx_done : std_logic;
    signal rx_uart_data : std_logic_vector(8-1 downto 0);
    signal rx_uart_wr : std_logic;

begin

    -- Ambos formadores de trama pertenecen al master. De este modo el nivel
    -- superior entrega informacion semantica y no administra handshakes
    -- internos ni buses UART intermedios.
    response_serializer : entity work.uart_response_serializer
        port map (
            clk => clk,
            rst => rst,
            response_start_i => response_start_i,
            response_command_i => response_command_i,
            response_status_i => response_status_i,
            response_data_i => response_data_i,
            request_o => response_request,
            enable_i => response_enable,
            done_o => response_done,
            uart_ready_i => uart_ready_i,
            uart_data_o => response_uart_data,
            uart_wr_o => response_uart_wr
        );

    rx_serializer : entity work.uart_rx_serializer
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            rx_packet_valid_i => rx_packet_valid_i,
            rx_packet_length_i => rx_packet_length_i,
            rx_packet_index_o => rx_packet_index_o,
            rx_packet_data_i => rx_packet_data_i,
            rx_packet_sent_o => rx_packet_sent_o,
            request_o => rx_request,
            enable_i => rx_enable,
            done_o => rx_done,
            uart_ready_i => uart_ready_i,
            uart_data_o => rx_uart_data,
            uart_wr_o => rx_uart_wr
        );

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

    next_state_logic : process(state_now, response_request,
                               response_done, rx_request, rx_done)
    begin
        state_next<=state_now;

        case state_now is
            when ST_IDLE =>
                if response_request='1' then
                    state_next<=ST_RESPONSE;
                elsif rx_request='1' then
                    state_next<=ST_RX_PACKET;
                end if;
            when ST_RESPONSE =>
                if response_done='1' then
                    state_next<=ST_IDLE;
                end if;
            when ST_RX_PACKET =>
                if rx_done='1' then
                    state_next<=ST_IDLE;
                end if;
        end case;
    end process;

    response_enable<='1' when state_now=ST_RESPONSE else '0';
    rx_enable<='1' when state_now=ST_RX_PACKET else '0';

    uart_data_o<=response_uart_data when state_now=ST_RESPONSE
        else rx_uart_data when state_now=ST_RX_PACKET
        else (others=>'0');

    uart_wr_o<=response_uart_wr when state_now=ST_RESPONSE
        else rx_uart_wr when state_now=ST_RX_PACKET
        else '0';

end Behavioral;
