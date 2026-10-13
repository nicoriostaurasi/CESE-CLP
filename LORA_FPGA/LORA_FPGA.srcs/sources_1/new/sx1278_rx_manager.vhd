----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 02.10.2026 01:18:07
-- Design Name:
-- Module Name: sx1278_rx_manager - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Gestiona la recepcion de un paquete, consulta las IRQ y extrae
--              el payload de la FIFO mediante operaciones solicitadas al arbitro.
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

entity sx1278_rx_manager is
    generic (
        MAX_DATA_BYTES : integer := 50
    );
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono de la MEF y del buffer RX.
        rst : in std_logic;
        -- Pulso que inicia la espera de un paquete.
        start_i : in std_logic;
        -- Pulso sincronizado de DIO0 utilizado como RxDone.
        dio0_rising_edge_i : in std_logic;

        -- Solicitud de propiedad del secuenciador SPI.
        sequence_request_o : out std_logic;
        -- Indice del frame solicitado por el secuenciador.
        sequence_step_i : in std_logic_vector(4-1 downto 0);
        -- Frame SPI que debe ejecutarse en el paso actual.
        sequence_frame_o : out std_logic_vector(16-1 downto 0);
        -- Indice del ultimo frame de la secuencia actual.
        sequence_last_step_o : out std_logic_vector(4-1 downto 0);
        -- Marca que la operacion SPI actual es una lectura.
        sequence_read_o : out std_logic;
        -- Pulso de finalizacion del secuenciador SPI.
        sequence_done_i : in std_logic;
        -- Byte devuelto por la ultima lectura SPI.
        sequence_read_data_i : in std_logic_vector(8-1 downto 0);

        -- Indice de lectura aleatoria del payload recibido.
        read_index_i : in std_logic_vector(6-1 downto 0);
        -- Byte del payload seleccionado por read_index_i.
        data_o : out std_logic_vector(8-1 downto 0);
        -- Cantidad de bytes del ultimo paquete valido.
        length_o : out std_logic_vector(6-1 downto 0);
        -- Indica que el buffer contiene un paquete valido.
        valid_o : out std_logic;
        -- Mantiene pendiente el paquete hasta enviarlo por UART.
        packet_pending_o : out std_logic;
        -- Indice utilizado por el serializador UART.
        stream_index_i : in std_logic_vector(6-1 downto 0);
        -- Byte del payload seleccionado para el flujo UART.
        stream_data_o : out std_logic_vector(8-1 downto 0);
        -- Pulso que libera el paquete luego de transmitirlo por UART.
        packet_sent_i : in std_logic;

        -- Indica que la solicitud RX continua en curso.
        busy_o : out std_logic;
        -- Pulso generado al completar un paquete valido.
        done_o : out std_logic;
        -- Indica que el ultimo evento DIO0 tenia error de CRC.
        error_o : out std_logic
    );
end sx1278_rx_manager;

architecture Behavioral of sx1278_rx_manager is
    type t_state is (
        ST_IDLE, ST_SETUP_REQUEST, ST_SETUP_DONE, ST_WAIT_DIO0,
        ST_IRQ_REQUEST, ST_IRQ_CHECK,
        ST_DISCARD_REQUEST, ST_RESTART_GAP, ST_RESTART_REQUEST,
        ST_LENGTH_REQUEST, ST_LENGTH_CHECK,
        ST_ADDRESS_REQUEST, ST_POINTER_GAP, ST_POINTER_REQUEST, ST_FIFO_GAP,
        ST_FIFO_REQUEST, ST_FIFO_CAPTURE, ST_CLEAR_REQUEST, ST_PACKET_DONE
    );
    type t_rx_payload is array(0 to MAX_DATA_BYTES-1) of
        std_logic_vector(8-1 downto 0);

    signal state_now : t_state;
    signal state_next : t_state;
    signal irq_flags_q : std_logic_vector(8-1 downto 0);
    signal irq_flags_d : std_logic_vector(8-1 downto 0);
    signal length_q : unsigned(6-1 downto 0);
    signal length_d : unsigned(6-1 downto 0);
    signal fifo_address_q : std_logic_vector(8-1 downto 0);
    signal fifo_address_d : std_logic_vector(8-1 downto 0);
    signal read_byte_index_q : unsigned(6-1 downto 0);
    signal read_byte_index_d : unsigned(6-1 downto 0);
    signal payload : t_rx_payload;
    signal valid_q : std_logic;
    signal valid_d : std_logic;
    signal packet_pending_q : std_logic;
    signal packet_pending_d : std_logic;
    signal rx_setup_frame : std_logic_vector(16-1 downto 0);
    signal rx_clear_frame : std_logic_vector(16-1 downto 0);
begin
    register_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state_now<=ST_IDLE;
                irq_flags_q<=(others=>'0');
                length_q<=TO_UNSIGNED(0,length_q'length);
                fifo_address_q<=(others=>'0');
                read_byte_index_q<=TO_UNSIGNED(0,read_byte_index_q'length);
                payload<=(others=>(others=>'0'));
                valid_q<='0';
                packet_pending_q<='0';
            else
                state_now<=state_next;
                irq_flags_q<=irq_flags_d;
                length_q<=length_d;
                fifo_address_q<=fifo_address_d;
                read_byte_index_q<=read_byte_index_d;
                valid_q<=valid_d;
                packet_pending_q<=packet_pending_d;

                if state_now=ST_FIFO_CAPTURE then
                    payload(to_integer(read_byte_index_q))<=sequence_read_data_i;
                end if;
            end if;
        end if;
    end process;

    next_state_logic : process(state_now,start_i,dio0_rising_edge_i,sequence_done_i,irq_flags_q,length_q,read_byte_index_q)
    begin
        state_next<=state_now;
        case state_now is
            when ST_IDLE =>
                if start_i='1' then
                    state_next<=ST_SETUP_REQUEST;
                end if;
            when ST_SETUP_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_SETUP_DONE;
                end if;
            when ST_SETUP_DONE =>
                state_next<=ST_WAIT_DIO0;
            when ST_WAIT_DIO0 =>
                if dio0_rising_edge_i='1' then
                    state_next<=ST_IRQ_REQUEST;
                end if;
            when ST_IRQ_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_IRQ_CHECK;
                end if;
            when ST_IRQ_CHECK =>
                if irq_flags_q(IRQ_PAYLOAD_CRC_ERROR_BIT)='1' then
                    state_next<=ST_DISCARD_REQUEST;
                else
                    state_next<=ST_LENGTH_REQUEST;
                end if;
            when ST_DISCARD_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_RESTART_GAP;
                end if;
            when ST_RESTART_GAP =>
                state_next<=ST_RESTART_REQUEST;
            when ST_RESTART_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_WAIT_DIO0;
                end if;
            when ST_LENGTH_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_LENGTH_CHECK;
                end if;
            when ST_LENGTH_CHECK =>
                if length_q=TO_UNSIGNED(0,length_q'length) then
                    state_next<=ST_DISCARD_REQUEST;
                else
                    state_next<=ST_ADDRESS_REQUEST;
                end if;
            when ST_ADDRESS_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_POINTER_GAP;
                end if;
            when ST_POINTER_GAP =>
                state_next<=ST_POINTER_REQUEST;
            when ST_POINTER_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_FIFO_GAP;
                end if;
            when ST_FIFO_GAP =>
                state_next<=ST_FIFO_REQUEST;
            when ST_FIFO_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_FIFO_CAPTURE;
                end if;
            when ST_FIFO_CAPTURE =>
                if read_byte_index_q=length_q-TO_UNSIGNED(1,length_q'length) then
                    state_next<=ST_CLEAR_REQUEST;
                else
                    state_next<=ST_FIFO_GAP;
                end if;
            when ST_CLEAR_REQUEST =>
                if sequence_done_i='1' then
                    state_next<=ST_PACKET_DONE;
                end if;
            when ST_PACKET_DONE =>
                state_next<=ST_IDLE;
        end case;
    end process;

    with sequence_step_i select
        rx_setup_frame<=RX_SETUP_SEQUENCE(0) when x"0",
                        RX_SETUP_SEQUENCE(1) when x"1",
                        RX_SETUP_SEQUENCE(2) when x"2",
                        RX_SETUP_SEQUENCE(0) when others;

    with sequence_step_i select
        rx_clear_frame<=RX_CLEAR_SEQUENCE(0) when x"0",
                        RX_CLEAR_SEQUENCE(1) when x"1",
                        RX_CLEAR_SEQUENCE(0) when others;

    output_logic : process(state_now,start_i,dio0_rising_edge_i,sequence_done_i,sequence_read_data_i,packet_sent_i,irq_flags_q,length_q,fifo_address_q,read_byte_index_q,valid_q,packet_pending_q,rx_setup_frame,rx_clear_frame)
    begin
        irq_flags_d<=irq_flags_q;
        length_d<=length_q;
        fifo_address_d<=fifo_address_q;
        read_byte_index_d<=read_byte_index_q;
        valid_d<=valid_q;
        packet_pending_d<=packet_pending_q;
        sequence_request_o<='0';
        sequence_frame_o<=FRAME_CLEAR_RX_IRQ;
        sequence_last_step_o<=(others=>'0');
        sequence_read_o<='0';
        busy_o<='1';
        done_o<='0';
        error_o<='0';

        if packet_sent_i='1' then
            packet_pending_d<='0';
        end if;

        case state_now is
            when ST_IDLE =>
                busy_o<='0';
                if start_i='1' then
                    valid_d<='0';
                    packet_pending_d<='0';
                    length_d<=TO_UNSIGNED(0,length_d'length);
                    read_byte_index_d<=TO_UNSIGNED(0,read_byte_index_d'length);
                end if;
            when ST_SETUP_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=rx_setup_frame;
                sequence_last_step_o<=std_logic_vector(TO_UNSIGNED(2,sequence_last_step_o'length));
            when ST_SETUP_DONE =>
                done_o<='1';
            when ST_WAIT_DIO0 =>
                if dio0_rising_edge_i='1' then
                    valid_d<='0';
                    packet_pending_d<='0';
                    length_d<=TO_UNSIGNED(0,length_d'length);
                    read_byte_index_d<=TO_UNSIGNED(0,read_byte_index_d'length);
                end if;
            when ST_IRQ_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=FRAME_READ_IRQ;
                sequence_read_o<='1';
                if sequence_done_i='1' then
                    irq_flags_d<=sequence_read_data_i;
                end if;
            when ST_IRQ_CHECK =>
                error_o<=irq_flags_q(IRQ_PAYLOAD_CRC_ERROR_BIT);
            when ST_DISCARD_REQUEST =>
                sequence_request_o<='1';
            when ST_RESTART_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=FRAME_RX_CONTINUOUS;
            when ST_LENGTH_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=FRAME_READ_RX_LENGTH;
                sequence_read_o<='1';
                if sequence_done_i='1' then
                    length_d<=resize(unsigned(sequence_read_data_i),length_d'length);
                end if;
            when ST_ADDRESS_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=FRAME_READ_RX_ADDRESS;
                sequence_read_o<='1';
                if sequence_done_i='1' then
                    fifo_address_d<=sequence_read_data_i;
                end if;
            when ST_POINTER_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=CMD_WRITE_FIFO_POINTER & fifo_address_q;
            when ST_FIFO_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=FRAME_READ_FIFO;
                sequence_read_o<='1';
            when ST_FIFO_CAPTURE =>
                if read_byte_index_q/=length_q-TO_UNSIGNED(1,length_q'length) then
                    read_byte_index_d<=read_byte_index_q+TO_UNSIGNED(1,read_byte_index_d'length);
                end if;
            when ST_CLEAR_REQUEST =>
                sequence_request_o<='1';
                sequence_frame_o<=rx_clear_frame;
                sequence_last_step_o<=std_logic_vector(TO_UNSIGNED(1,sequence_last_step_o'length));
            when ST_PACKET_DONE =>
                done_o<='1';
                if irq_flags_q(IRQ_PAYLOAD_CRC_ERROR_BIT)='0' and length_q/=TO_UNSIGNED(0,length_q'length) then
                    valid_d<='1';
                    packet_pending_d<='1';
                end if;
            when others =>
                null;
        end case;
    end process;

    data_o<=payload(to_integer(unsigned(read_index_i))) when unsigned(read_index_i)<TO_UNSIGNED(MAX_DATA_BYTES,read_index_i'length)
                    else (others=>'0');

    stream_data_o<=payload(to_integer(unsigned(stream_index_i))) when unsigned(stream_index_i)<TO_UNSIGNED(MAX_DATA_BYTES,stream_index_i'length)
                    else (others=>'0');

    length_o<=std_logic_vector(length_q);
    valid_o<=valid_q;
    packet_pending_o<=packet_pending_q;

end Behavioral;
