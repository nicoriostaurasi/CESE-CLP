----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 02.10.2026 01:18:07
-- Design Name:
-- Module Name: sx1278_tx_manager - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Ejecuta una transmision completa con el payload previamente
--              almacenado: prepara la FIFO, escribe sus bytes, inicia TX,
--              espera TxDone y limpia la interrupcion.
--
-- Dependencies: sx1278_controller_pkg, block_ram
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

entity sx1278_tx_manager is
    generic (
        MAX_DATA_BYTES : integer := 50
    );
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono de la MEF, punteros y RAM.
        rst : in std_logic;
        -- Inicia un payload nuevo y reinicia el puntero de escritura.
        tx_begin_i : in std_logic;
        -- Habilita la escritura de tx_data_i en el buffer local.
        tx_write_i : in std_logic;
        -- Byte que se agrega al payload.
        tx_data_i : in std_logic_vector(8-1 downto 0);
        -- Solicita transmitir el payload almacenado.
        tx_start_i : in std_logic;
        -- Pulso sincronizado de DIO0 utilizado como TxDone.
        sx1278_dio0_rising_edge_i : in std_logic;
        -- Solicitud de propiedad del secuenciador SPI.
        spi_sequence_request_o : out std_logic;
        -- Indice del frame solicitado por el secuenciador.
        spi_sequence_step_i : in std_logic_vector(4-1 downto 0);
        -- Frame SPI que debe ejecutarse en el paso actual.
        spi_sequence_frame_o : out std_logic_vector(16-1 downto 0);
        -- Indice del ultimo frame de la secuencia actual.
        spi_sequence_last_step_o : out std_logic_vector(4-1 downto 0);
        -- Pulso de finalizacion del secuenciador SPI.
        spi_sequence_done_i : in std_logic;
        -- Indica que hay una transmision en curso.
        tx_busy_o : out std_logic;
        -- Pulso generado al finalizar y limpiar TxDone.
        tx_done_o : out std_logic
    );
end sx1278_tx_manager;

architecture Behavioral of sx1278_tx_manager is
    type t_state is (ST_IDLE, ST_BEGIN_REQUEST, ST_BEGIN_GAP,
                     ST_FILL_TX, ST_FILL_TX_GAP, ST_START_GAP,
                     ST_START_REQUEST, ST_WAIT_DIO0, ST_CLEAR_GAP,
                     ST_CLEAR_REQUEST, ST_DONE);
    signal state_now : t_state;
    signal state_next : t_state;
    signal read_byte_index_q : unsigned(6-1 downto 0);
    signal read_byte_index_d : unsigned(6-1 downto 0);
    signal write_index : unsigned(6-1 downto 0);
    signal payload_data : std_logic_vector(8-1 downto 0);
    signal ram_write_address : integer range 0 to MAX_DATA_BYTES-1;
    signal ram_read_address : integer range 0 to MAX_DATA_BYTES-1;
    signal tx_begin_frame : std_logic_vector(16-1 downto 0);
    signal tx_start_frame : std_logic_vector(16-1 downto 0);
begin
    register_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state_now<=ST_IDLE;
                read_byte_index_q<=TO_UNSIGNED(0,read_byte_index_q'length);
            else
                state_now<=state_next;
                read_byte_index_q<=read_byte_index_d;
            end if;
        end if;
    end process;

    write_index_register : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                write_index<=TO_UNSIGNED(0,write_index'length);
            -- TX_BEGIN abre un payload nuevo. El manager resuelve internamente
            -- el reinicio del puntero; el nivel superior no limpia la RAM.
            elsif tx_begin_i='1' then
                write_index<=TO_UNSIGNED(0,write_index'length);
            elsif tx_write_i='1' and write_index<TO_UNSIGNED(MAX_DATA_BYTES,write_index'length) then
                write_index<=write_index+TO_UNSIGNED(1,write_index'length);
            end if;
        end if;
    end process;

    ram_write_address<=to_integer(write_index) when write_index<TO_UNSIGNED(MAX_DATA_BYTES,write_index'length) else 0;
    ram_read_address<=to_integer(read_byte_index_q) when read_byte_index_q<TO_UNSIGNED(MAX_DATA_BYTES,read_byte_index_q'length) else 0;
    tx_ram : entity work.block_ram
        generic map (
            DATA_WIDTH => 8,
            DEPTH => MAX_DATA_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            wr_en_i => tx_write_i,
            wr_addr_i => ram_write_address,
            wr_data_i => tx_data_i,
            rd_addr_i => ram_read_address,
            rd_data_o => payload_data
        );

    next_state_logic : process(state_now,tx_start_i,spi_sequence_done_i,sx1278_dio0_rising_edge_i,read_byte_index_q,write_index)
    begin
        state_next<=state_now;
        case state_now is
            when ST_IDLE =>
                if tx_start_i='1' then
                    state_next<=ST_BEGIN_REQUEST;
                end if;
            when ST_BEGIN_REQUEST =>
                if spi_sequence_done_i='1' then
                    state_next<=ST_BEGIN_GAP;
                end if;
            when ST_BEGIN_GAP =>
                state_next<=ST_FILL_TX;
            when ST_FILL_TX =>
                if spi_sequence_done_i='1' then
                    if read_byte_index_q=write_index-TO_UNSIGNED(1,write_index'length) then
                        state_next<=ST_START_GAP;
                    else
                        state_next<=ST_FILL_TX_GAP;
                    end if;
                end if;
            when ST_FILL_TX_GAP =>
                state_next<=ST_FILL_TX;
            when ST_START_GAP =>
                state_next<=ST_START_REQUEST;
            when ST_START_REQUEST =>
                if spi_sequence_done_i='1' then
                    state_next<=ST_WAIT_DIO0;
                end if;
            when ST_WAIT_DIO0 =>
                if sx1278_dio0_rising_edge_i='1' then
                    state_next<=ST_CLEAR_GAP;
                end if;
            when ST_CLEAR_GAP =>
                state_next<=ST_CLEAR_REQUEST;
            when ST_CLEAR_REQUEST =>
                if spi_sequence_done_i='1' then
                    state_next<=ST_DONE;
                end if;
            when ST_DONE =>
                state_next<=ST_IDLE;
        end case;
    end process;

    output_logic : process(state_now,tx_start_i,spi_sequence_done_i,read_byte_index_q,write_index,tx_begin_frame,tx_start_frame,payload_data)
    begin
        read_byte_index_d<=read_byte_index_q;
        spi_sequence_request_o<='0';
        spi_sequence_frame_o<=FRAME_CLEAR_TX_DONE;
        spi_sequence_last_step_o<=(others=>'0');
        tx_busy_o<='1';
        tx_done_o<='0';

        case state_now is
            when ST_IDLE =>
                tx_busy_o<='0';
                if tx_start_i='1' then
                    read_byte_index_d<=TO_UNSIGNED(0,read_byte_index_d'length);
                end if;
            when ST_BEGIN_REQUEST =>
                spi_sequence_request_o<='1';
                spi_sequence_frame_o<=tx_begin_frame;
                spi_sequence_last_step_o<=std_logic_vector(TO_UNSIGNED(1,spi_sequence_last_step_o'length));
            when ST_FILL_TX =>
                spi_sequence_request_o<='1';
                spi_sequence_frame_o<=CMD_WRITE_FIFO & payload_data;
                if spi_sequence_done_i='1' then
                    if read_byte_index_q/=write_index-TO_UNSIGNED(1,write_index'length) then
                        read_byte_index_d<=read_byte_index_q+TO_UNSIGNED(1,read_byte_index_d'length);
                    end if;
                end if;
            when ST_START_REQUEST =>
                spi_sequence_request_o<='1';
                spi_sequence_frame_o<=tx_start_frame;
                spi_sequence_last_step_o<=std_logic_vector(TO_UNSIGNED(3,spi_sequence_last_step_o'length));
            when ST_CLEAR_REQUEST =>
                spi_sequence_request_o<='1';
            when ST_DONE =>
                tx_done_o<='1';
            when others =>
                null;
        end case;
    end process;

    with spi_sequence_step_i select
        tx_begin_frame<=TX_BEGIN_SEQUENCE(0) when x"0",
                        TX_BEGIN_SEQUENCE(1) when x"1",
                        (others=>'0') when others;

    with spi_sequence_step_i select
        tx_start_frame<=CMD_WRITE_PAYLOAD_LENGTH & "00" & std_logic_vector(write_index) when x"0",
                        FRAME_CLEAR_ALL_IRQ when x"1",
                        FRAME_DIO0_TX_DONE when x"2",
                        FRAME_TX_MODE when x"3",
                        (others=>'0') when others;

end Behavioral;
