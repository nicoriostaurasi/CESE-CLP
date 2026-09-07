----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2026 22:54:15
-- Design Name: 
-- Module Name: sx1262_spi_manager - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Interfaz de alto nivel para controlar un transceptor SX1262.
-- Recibe comandos y datos empaquetados de hasta MAX_DATA_BYTES, los convierte
-- en secuencias SPI y entrega las respuestas en un vector del mismo ancho.
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sx1262_spi_manager is
    generic (
        MAX_DATA_BYTES : integer := 50;
        CLK_FREQ_HZ    : integer := 100_000_000;
        SPI_FREQ_HZ    : integer := 5_000_000
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- Interfaz de comandos de alto nivel.
        -- 000: sin operacion
        -- 001: reset del SX1262
        -- 010: aplicar configuracion
        -- 011: transmitir payload
        -- 100: iniciar/leer recepcion
        command_i : in std_logic_vector(3-1 downto 0);
        start_i   : in std_logic;
        busy_o    : out std_logic;
        done_o    : out std_logic;
        error_o   : out std_logic;

        -- Banco de registros de configuracion.
        config_wr_i   : in  std_logic;
        config_addr_i : in  std_logic_vector(4-1 downto 0);
        config_data_i : in  std_logic_vector(32-1 downto 0);
        config_data_o : out std_logic_vector(32-1 downto 0);

        -- Informacion asociada al comando. El byte 0 ocupa los bits 7 downto 0.
        write_info_i : in std_logic_vector(MAX_DATA_BYTES*8-1 downto 0);
        write_length_i : in integer range 0 to MAX_DATA_BYTES;

        -- Cantidad maxima de bytes que debe recuperar un comando de lectura.
        read_length_i : in integer range 0 to MAX_DATA_BYTES;

        -- Resultado del comando. read_valid_o indica que read_info_o y
        -- read_length_o contienen una respuesta completa y valida.
        read_info_o : out std_logic_vector(MAX_DATA_BYTES*8-1 downto 0);
        read_length_o : out integer range 0 to MAX_DATA_BYTES;
        read_valid_o : out std_logic;

        -- Interfaz SPI fisica. El SX1262 utiliza modo 0: CPOL=0, CPHA=0.
        spi_sclk_o : out std_logic;
        spi_mosi_o : out std_logic;
        spi_miso_i : in std_logic;
        spi_nss_o  : out std_logic;

        -- GPIO adicionales del transceptor.
        sx1262_busy_i  : in std_logic;
        sx1262_dio1_i  : in std_logic;
        sx1262_reset_o : out std_logic
    );
end sx1262_spi_manager;

architecture Behavioral of sx1262_spi_manager is

    -- Reserva espacio para los bytes de comando, offsets y parametros que
    -- acompanan al payload de usuario dentro de una trama SPI.
    constant MAX_FRAME_BYTES : integer := MAX_DATA_BYTES+8;

    -- Comandos de alto nivel aceptados por command_i.
    constant CMD_NONE         : std_logic_vector(3-1 downto 0) := "000";
    constant CMD_RESET        : std_logic_vector(3-1 downto 0) := "001";
    constant CMD_APPLY_CONFIG : std_logic_vector(3-1 downto 0) := "010";
    constant CMD_TX           : std_logic_vector(3-1 downto 0) := "011";
    constant CMD_RX           : std_logic_vector(3-1 downto 0) := "100";

    -- Direcciones del banco de configuracion. 
    constant CFG_RF_FREQUENCY     : integer := 0;
    constant CFG_SPREADING_FACTOR : integer := 1;
    constant CFG_BANDWIDTH        : integer := 2;
    constant CFG_CODING_RATE      : integer := 3;
    constant CFG_PREAMBLE_LENGTH  : integer := 4;
    constant CFG_HEADER_TYPE      : integer := 5;
    constant CFG_CRC_ENABLE       : integer := 6;
    constant CFG_IQ_INVERTED      : integer := 7;
    constant CFG_TX_POWER         : integer := 8;
    constant CFG_RX_TIMEOUT       : integer := 9;
    constant CFG_TX_TIMEOUT       : integer := 10;
    constant CFG_LDRO             : integer := 11;

    type config_register_array_t is array (0 to 15) of
        std_logic_vector(32-1 downto 0);

    signal config_registers : config_register_array_t;

    type t_state is (
        ST_IDLE,
        ST_RESET_ASSERT,
        ST_RESET_RELEASE,
        ST_CONFIG_SET_STANDBY,
        ST_CONFIG_SET_PACKET_TYPE,
        ST_CONFIG_SET_RF_FREQUENCY,
        ST_CONFIG_SET_TX_PARAMS,
        ST_CONFIG_SET_MODULATION_PARAMS,
        ST_CONFIG_SET_PACKET_PARAMS,
        ST_CONFIG_SET_BUFFER_BASE_ADDRESS,
        ST_TX_WRITE_BUFFER,
        ST_TX_SET_PACKET_PARAMS,
        ST_TX_SET_TX,
        ST_TX_WAIT_DIO1,
        ST_RX_SET_RX,
        ST_RX_WAIT_DIO1,
        ST_RX_GET_BUFFER_STATUS,
        ST_RX_READ_BUFFER_STATUS,
        ST_RX_READ_BUFFER,
        ST_RX_READ_PAYLOAD,
        ST_RX_CLEAR_IRQ_STATUS,
        ST_COMMAND_DONE,
        ST_COMMAND_ERROR
    );

    signal state_now : t_state;
    signal state_next : t_state;

    -- Frame paralelo construido por la MEF y control del serializador.
    signal frame_data : std_logic_vector(MAX_FRAME_BYTES*8-1 downto 0);
    signal frame_length : integer range 0 to MAX_FRAME_BYTES;
    signal frame_request : std_logic;
    signal serializer_active : std_logic;
    signal serializer_done : std_logic;
    signal serializer_bytes_remaining : integer range 0 to MAX_FRAME_BYTES;
    signal serializer_shift_reg : std_logic_vector(MAX_FRAME_BYTES*8-1 downto 0);
    signal serializer_loading : std_logic;
    signal serializer_start_pending : std_logic;

    -- Interconexion con el controlador de frames SPI.
    signal frame_tx_byte : std_logic_vector(8-1 downto 0);
    signal frame_charge_byte : std_logic;
    signal frame_start_transfer : std_logic;
    signal frame_controller_busy : std_logic;
    signal frame_controller_done : std_logic;
    signal frame_rx_empty : std_logic;
    signal frame_rx_data : std_logic_vector(8-1 downto 0);
    signal frame_rx_read : std_logic;

    -- Copia local del payload. La interfaz externa puede cambiar sus datos
    -- despues de que el manager acepta el pulso start_i.
    signal tx_data_reg : std_logic_vector(MAX_DATA_BYTES*8-1 downto 0);
    signal tx_length_reg : integer range 0 to MAX_DATA_BYTES;

    -- Datos recuperados del buffer interno del SX1262.
    signal rx_data_reg : std_logic_vector(MAX_DATA_BYTES*8-1 downto 0);
    signal rx_length_reg : integer range 0 to MAX_DATA_BYTES;
    signal rx_requested_length_reg : integer range 0 to MAX_DATA_BYTES;
    signal rx_offset_reg : std_logic_vector(8-1 downto 0);
    signal rx_ram_counter : integer range 0 to MAX_FRAME_BYTES;
    signal rx_read_pending : integer range 0 to 2;
    signal rx_status_ready : std_logic;
    signal rx_payload_ready : std_logic;
    signal rx_result_valid : std_logic;

    -- Sincronizacion de DIO1 al dominio de clk.
    signal dio1_sync_1 : std_logic;
    signal dio1_sync_2 : std_logic;

begin

    frame_controller : entity work.spi_frame_controller
        generic map (
            RAM_DEPTH  => MAX_FRAME_BYTES,
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            CPOL        => '0',
            CPHA        => '0',
            IDLE_VALUE  => '0'
        )
        port map (
            clk                => clk,
            rst                => rst,
            byte_i             => frame_tx_byte,
            charge_byte        => frame_charge_byte,
            start_spi_transfer => frame_start_transfer,
            busy               => frame_controller_busy,
            done               => frame_controller_done,
            rx_ram_read        => frame_rx_read,
            rx_ram_empty       => frame_rx_empty,
            rx_ram_data_o      => frame_rx_data,
            spi_sclk_o          => spi_sclk_o,
            spi_mosi_o          => spi_mosi_o,
            spi_miso_i          => spi_miso_i,
            spi_nss_o           => spi_nss_o
        );

    config_write : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                config_registers<=(others=>(others=>'0'));
            elsif config_wr_i='1' then
                config_registers(to_integer(unsigned(config_addr_i)))<=config_data_i;
            end if;
        end if;
    end process;

    config_data_o<=config_registers(to_integer(unsigned(config_addr_i)));

    ---------------------------------------------------------------------------
    -- Sincronizador para la entrada asincrona DIO1.
    dio1_synchronizer : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                dio1_sync_1<='0';
                dio1_sync_2<='0';
            else
                dio1_sync_1<=sx1262_dio1_i;
                dio1_sync_2<=dio1_sync_1;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Registros de entrada de los comandos TX y RX
    ---------------------------------------------------------------------------
    command_input_register : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                tx_data_reg<=(others=>'0');
                tx_length_reg<=0;
                rx_requested_length_reg<=MAX_DATA_BYTES;
            elsif state_now=ST_IDLE and start_i='1' and command_i=CMD_TX then
                tx_data_reg<=write_info_i;
                tx_length_reg<=write_length_i;
            elsif state_now=ST_IDLE and start_i='1' and command_i=CMD_RX then
                if read_length_i=0 then
                    rx_requested_length_reg<=MAX_DATA_BYTES;
                else
                    rx_requested_length_reg<=read_length_i;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Constructor combinacional del frame de configuracion
    ---------------------------------------------------------------------------
    frame_builder : process(
        state_now,
        config_registers,
        tx_data_reg,
        tx_length_reg,
        rx_length_reg,
        rx_offset_reg
    )
    begin
        frame_data<=(others=>'0');
        frame_length<=0;
        frame_request<='0';

        case state_now is
            when ST_CONFIG_SET_STANDBY =>
                frame_data(7 downto 0)<=x"80";
                frame_data(15 downto 8)<=x"00";
                frame_length<=2;
                frame_request<='1';

            when ST_CONFIG_SET_PACKET_TYPE =>
                frame_data(7 downto 0)<=x"8A";
                frame_data(15 downto 8)<=x"01";
                frame_length<=2;
                frame_request<='1';

            when ST_CONFIG_SET_RF_FREQUENCY =>
                frame_data(7 downto 0)<=x"86";
                frame_data(15 downto 8)<=config_registers(CFG_RF_FREQUENCY)(31 downto 24);
                frame_data(23 downto 16)<=config_registers(CFG_RF_FREQUENCY)(23 downto 16);
                frame_data(31 downto 24)<=config_registers(CFG_RF_FREQUENCY)(15 downto 8);
                frame_data(39 downto 32)<=config_registers(CFG_RF_FREQUENCY)(7 downto 0);
                frame_length<=5;
                frame_request<='1';

            when ST_CONFIG_SET_TX_PARAMS =>
                frame_data(7 downto 0)<=x"8E";
                frame_data(15 downto 8)<=config_registers(CFG_TX_POWER)(7 downto 0);
                frame_data(23 downto 16)<=x"04";
                frame_length<=3;
                frame_request<='1';

            when ST_CONFIG_SET_MODULATION_PARAMS =>
                frame_data(7 downto 0)<=x"8B";
                frame_data(15 downto 8)<=config_registers(CFG_SPREADING_FACTOR)(7 downto 0);
                frame_data(23 downto 16)<=config_registers(CFG_BANDWIDTH)(7 downto 0);
                frame_data(31 downto 24)<=config_registers(CFG_CODING_RATE)(7 downto 0);
                frame_data(39 downto 32)<=config_registers(CFG_LDRO)(7 downto 0);
                frame_length<=5;
                frame_request<='1';

            when ST_CONFIG_SET_PACKET_PARAMS =>
                frame_data(7 downto 0)<=x"8C";
                frame_data(15 downto 8)<=config_registers(CFG_PREAMBLE_LENGTH)(15 downto 8);
                frame_data(23 downto 16)<=config_registers(CFG_PREAMBLE_LENGTH)(7 downto 0);
                frame_data(31 downto 24)<=config_registers(CFG_HEADER_TYPE)(7 downto 0);
                frame_data(39 downto 32)<=std_logic_vector(to_unsigned(MAX_DATA_BYTES,8));
                frame_data(47 downto 40)<=config_registers(CFG_CRC_ENABLE)(7 downto 0);
                frame_data(55 downto 48)<=config_registers(CFG_IQ_INVERTED)(7 downto 0);
                frame_length<=7;
                frame_request<='1';

            when ST_CONFIG_SET_BUFFER_BASE_ADDRESS =>
                frame_data(7 downto 0)<=x"8F";
                frame_data(15 downto 8)<=x"00";
                frame_data(23 downto 16)<=x"00";
                frame_length<=3;
                frame_request<='1';

            when ST_TX_WRITE_BUFFER =>
                -- WriteBuffer: opcode, offset de TX y payload.
                frame_data(7 downto 0)<=x"0E";
                frame_data(15 downto 8)<=x"00";

                for byte_index in 0 to MAX_DATA_BYTES-1 loop
                    if byte_index<tx_length_reg then
                        frame_data((byte_index+3)*8-1 downto
                                   (byte_index+2)*8)<=
                            tx_data_reg((byte_index+1)*8-1 downto byte_index*8);
                    end if;
                end loop;

                frame_length<=tx_length_reg+2;
                frame_request<='1';

            when ST_TX_SET_PACKET_PARAMS =>
                -- Actualiza PayloadLength antes de iniciar cada transmision.
                frame_data(7 downto 0)<=x"8C";
                frame_data(15 downto 8)<=config_registers(CFG_PREAMBLE_LENGTH)(15 downto 8);
                frame_data(23 downto 16)<=config_registers(CFG_PREAMBLE_LENGTH)(7 downto 0);
                frame_data(31 downto 24)<=config_registers(CFG_HEADER_TYPE)(7 downto 0);
                frame_data(39 downto 32)<=std_logic_vector(to_unsigned(tx_length_reg,8));
                frame_data(47 downto 40)<=config_registers(CFG_CRC_ENABLE)(7 downto 0);
                frame_data(55 downto 48)<=config_registers(CFG_IQ_INVERTED)(7 downto 0);
                frame_length<=7;
                frame_request<='1';

            when ST_TX_SET_TX =>
                -- SetTx utiliza el timeout de 24 bits almacenado en CFG_TX_TIMEOUT.
                frame_data(7 downto 0)<=x"83";
                frame_data(15 downto 8)<=config_registers(CFG_TX_TIMEOUT)(23 downto 16);
                frame_data(23 downto 16)<=config_registers(CFG_TX_TIMEOUT)(15 downto 8);
                frame_data(31 downto 24)<=config_registers(CFG_TX_TIMEOUT)(7 downto 0);
                frame_length<=4;
                frame_request<='1';

            when ST_RX_SET_RX =>
                -- SetRx con timeout FFFFFF: recepcion continua.
                frame_data(7 downto 0)<=x"82";
                frame_data(15 downto 8)<=x"FF";
                frame_data(23 downto 16)<=x"FF";
                frame_data(31 downto 24)<=x"FF";
                frame_length<=4;
                frame_request<='1';

            when ST_RX_GET_BUFFER_STATUS =>
                -- Dos bytes de respuesta: longitud y offset inicial.
                frame_data(7 downto 0)<=x"13";
                frame_data(15 downto 8)<=x"00";
                frame_data(23 downto 16)<=x"00";
                frame_data(31 downto 24)<=x"00";
                frame_length<=4;
                frame_request<='1';

            when ST_RX_READ_BUFFER =>
                -- ReadBuffer: opcode, offset, status/dummy y un dummy por
                -- cada byte que debe regresar por MISO.
                frame_data(7 downto 0)<=x"1E";
                frame_data(15 downto 8)<=rx_offset_reg;
                frame_data(23 downto 16)<=x"00";

                for byte_index in 0 to MAX_DATA_BYTES-1 loop
                    if byte_index<rx_length_reg then
                        frame_data((byte_index+4)*8-1 downto
                                   (byte_index+3)*8)<=x"00";
                    end if;
                end loop;

                frame_length<=rx_length_reg+3;
                frame_request<='1';

            when ST_RX_CLEAR_IRQ_STATUS =>
                frame_data(7 downto 0)<=x"02";
                frame_data(15 downto 8)<=x"FF";
                frame_data(23 downto 16)<=x"FF";
                frame_length<=3;
                frame_request<='1';

            when others =>
                null;
        end case;
    end process;

    ---------------------------------------------------------------------------
    -- Serializador secuencial de frames
    ---------------------------------------------------------------------------
    data_serializer : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                serializer_active<='0';
                serializer_done<='0';
                serializer_loading<='0';
                serializer_start_pending<='0';
                serializer_bytes_remaining<=0;
                serializer_shift_reg<=(others=>'0');
                frame_tx_byte<=(others=>'0');
                frame_charge_byte<='0';
                frame_start_transfer<='0';
            else
                frame_charge_byte<='0';
                frame_start_transfer<='0';

                if serializer_active='0' then
                    if serializer_done='1' and state_next/=state_now then
                        serializer_done<='0';

                    elsif frame_request='1' and serializer_done='0' and
                       sx1262_busy_i='0' and frame_length>0 and
                       frame_controller_busy='0' then
                        serializer_shift_reg<=frame_data;
                        serializer_bytes_remaining<=frame_length;
                        serializer_active<='1';
                        serializer_loading<='1';
                    end if;

                elsif serializer_loading='1' then
                    -- Carga un byte por ciclo en la RAM TX del frame controller.
                    frame_tx_byte<=serializer_shift_reg(7 downto 0);
                    frame_charge_byte<='1';
                    serializer_shift_reg<=x"00" &
                        serializer_shift_reg(MAX_FRAME_BYTES*8-1 downto 8);

                    if serializer_bytes_remaining=1 then
                        serializer_bytes_remaining<=0;
                        serializer_loading<='0';
                        serializer_start_pending<='1';
                    else
                        serializer_bytes_remaining<=serializer_bytes_remaining-1;
                    end if;

                elsif serializer_start_pending='1' then
                    -- Se inicia el frame un ciclo despues de cargar el ultimo
                    -- byte para asegurar que ya haya sido escrito en la RAM.
                    frame_start_transfer<='1';
                    serializer_start_pending<='0';

                elsif frame_controller_done='1' then
                    serializer_active<='0';
                    serializer_done<='1';
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Lectura secuencial de la RAM RX del frame controller
    ---------------------------------------------------------------------------
    rx_ram_reader : process(clk)
        variable received_length : integer;
    begin
        if rising_edge(clk) then
            if rst='1' then
                frame_rx_read<='0';
                rx_ram_counter<=0;
                rx_read_pending<=0;
                rx_status_ready<='0';
                rx_payload_ready<='0';
                rx_data_reg<=(others=>'0');
                rx_length_reg<=0;
                rx_offset_reg<=(others=>'0');
                rx_result_valid<='0';
            else
                frame_rx_read<='0';
                rx_status_ready<='0';
                rx_payload_ready<='0';

                if state_now=ST_IDLE and start_i='1' then
                    rx_result_valid<='0';

                    if command_i=CMD_RX then
                        rx_data_reg<=(others=>'0');
                        rx_length_reg<=0;
                        rx_offset_reg<=(others=>'0');
                        rx_ram_counter<=0;
                        rx_read_pending<=0;
                    end if;

                elsif state_now=ST_RX_READ_BUFFER_STATUS and
                      rx_status_ready='0' then
                    if rx_read_pending=0 and frame_rx_empty='0' then
                        -- Respuesta: byte 1=status, byte 2=length,
                        -- byte 3=start buffer pointer.
                        if rx_ram_counter=2 then
                            received_length:=to_integer(unsigned(frame_rx_data));
                            if received_length>rx_requested_length_reg then
                                rx_length_reg<=rx_requested_length_reg;
                            else
                                rx_length_reg<=received_length;
                            end if;
                        elsif rx_ram_counter=3 then
                            rx_offset_reg<=frame_rx_data;
                        end if;

                        if rx_ram_counter=3 then
                            rx_ram_counter<=0;
                            rx_status_ready<='1';
                        else
                            frame_rx_read<='1';
                            rx_read_pending<=2;
                            rx_ram_counter<=rx_ram_counter+1;
                        end if;
                    elsif rx_read_pending>0 then
                        -- Se contemplan el ciclo en que el frame controller
                        -- acepta read y el ciclo de lectura sincrona de RAM.
                        rx_read_pending<=rx_read_pending-1;
                    end if;

                elsif state_now=ST_RX_READ_PAYLOAD and
                      rx_payload_ready='0' then
                    if rx_read_pending=0 and frame_rx_empty='0' then
                        -- ReadBuffer devuelve tres bytes de protocolo antes
                        -- del primer byte valido del payload.
                        if rx_ram_counter>=3 and
                           rx_ram_counter<rx_length_reg+3 then
                            rx_data_reg(
                                (rx_ram_counter-2)*8-1 downto
                                (rx_ram_counter-3)*8
                            )<=frame_rx_data;
                        end if;

                        if rx_ram_counter=rx_length_reg+2 then
                            rx_ram_counter<=0;
                            rx_payload_ready<='1';
                            rx_result_valid<='1';
                        else
                            frame_rx_read<='1';
                            rx_read_pending<=2;
                            rx_ram_counter<=rx_ram_counter+1;
                        end if;
                    elsif rx_read_pending>0 then
                        rx_read_pending<=rx_read_pending-1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    

    ---------------------------------------------------------------------------
    -- Registro secuencial de estado
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- Logica combinacional de proximo estado
    ---------------------------------------------------------------------------
    next_state_logic : process(
        state_now,
        start_i,
        command_i,
        write_length_i,
        sx1262_busy_i,
        serializer_done,
        dio1_sync_2,
        rx_status_ready,
        rx_payload_ready
    )
    begin
        state_next<=state_now;

        case state_now is
            when ST_IDLE =>
                if start_i='1' then
                    case command_i is
                        when CMD_RESET =>
                            state_next<=ST_RESET_ASSERT;
                        when CMD_APPLY_CONFIG =>
                            state_next<=ST_CONFIG_SET_STANDBY;
                        when CMD_TX =>
                            if write_length_i>0 then
                                state_next<=ST_TX_WRITE_BUFFER;
                            else
                                state_next<=ST_COMMAND_ERROR;
                            end if;
                        when CMD_RX =>
                            state_next<=ST_RX_SET_RX;
                        when others =>
                            state_next<=ST_COMMAND_ERROR;
                    end case;
                end if;

            when ST_RESET_ASSERT =>
                state_next<=ST_RESET_RELEASE;

            when ST_RESET_RELEASE =>
                state_next<=ST_COMMAND_DONE;

            -- Cada estado representa un frame SPI completo de configuracion.
            -- La MEF avanza solamente cuando el serializador completo todos
            -- sus bytes y el SX1262 libero nuevamente BUSY.
            when ST_CONFIG_SET_STANDBY =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_CONFIG_SET_PACKET_TYPE;
                end if;

            when ST_CONFIG_SET_PACKET_TYPE =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_CONFIG_SET_RF_FREQUENCY;
                end if;

            when ST_CONFIG_SET_RF_FREQUENCY =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_CONFIG_SET_TX_PARAMS;
                end if;

            when ST_CONFIG_SET_TX_PARAMS =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_CONFIG_SET_MODULATION_PARAMS;
                end if;

            when ST_CONFIG_SET_MODULATION_PARAMS =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_CONFIG_SET_PACKET_PARAMS;
                end if;

            when ST_CONFIG_SET_PACKET_PARAMS =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_CONFIG_SET_BUFFER_BASE_ADDRESS;
                end if;

            when ST_CONFIG_SET_BUFFER_BASE_ADDRESS =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_COMMAND_DONE;
                end if;

            when ST_TX_WRITE_BUFFER =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_TX_SET_PACKET_PARAMS;
                end if;

            when ST_TX_SET_PACKET_PARAMS =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_TX_SET_TX;
                end if;

            when ST_TX_SET_TX =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_TX_WAIT_DIO1;
                end if;

            when ST_TX_WAIT_DIO1 =>
                if sx1262_dio1_i='1' then
                    state_next<=ST_COMMAND_DONE;
                end if;

            when ST_RX_SET_RX =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_RX_WAIT_DIO1;
                end if;

            when ST_RX_WAIT_DIO1 =>
                if dio1_sync_2='1' then
                    state_next<=ST_RX_GET_BUFFER_STATUS;
                end if;

            when ST_RX_GET_BUFFER_STATUS =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_RX_READ_BUFFER_STATUS;
                end if;

            when ST_RX_READ_BUFFER_STATUS =>
                if rx_status_ready='1' then
                    state_next<=ST_RX_READ_BUFFER;
                end if;

            when ST_RX_READ_BUFFER =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_RX_READ_PAYLOAD;
                end if;

            when ST_RX_READ_PAYLOAD =>
                if rx_payload_ready='1' then
                    state_next<=ST_RX_CLEAR_IRQ_STATUS;
                end if;

            when ST_RX_CLEAR_IRQ_STATUS =>
                if serializer_done='1' and sx1262_busy_i='0' then
                    state_next<=ST_COMMAND_DONE;
                end if;

            when ST_COMMAND_DONE =>
                state_next<=ST_IDLE;

            when ST_COMMAND_ERROR =>
                state_next<=ST_IDLE;
        end case;
    end process;

    ---------------------------------------------------------------------------
    -- Logica combinacional de salidas (MEF Moore)
    ---------------------------------------------------------------------------
    output_logic : process(
        state_now,
        rx_data_reg,
        rx_length_reg,
        rx_result_valid
    )
    begin
        busy_o<='0';
        done_o<='0';
        error_o<='0';
        read_info_o<=rx_data_reg;
        read_length_o<=rx_length_reg;
        read_valid_o<='0';
        sx1262_reset_o<='1';
        case state_now is
            when ST_IDLE =>
                null;

            when ST_RESET_ASSERT =>
                sx1262_reset_o<='0';

            when ST_CONFIG_SET_STANDBY |
                 ST_CONFIG_SET_PACKET_TYPE |
                 ST_CONFIG_SET_RF_FREQUENCY |
                 ST_CONFIG_SET_TX_PARAMS |
                 ST_CONFIG_SET_MODULATION_PARAMS |
                 ST_CONFIG_SET_PACKET_PARAMS |
                 ST_CONFIG_SET_BUFFER_BASE_ADDRESS =>
                busy_o<='1';

            when ST_TX_WRITE_BUFFER |
                 ST_TX_SET_PACKET_PARAMS |
                 ST_TX_SET_TX |
                 ST_TX_WAIT_DIO1 =>
                busy_o<='1';

            when ST_RX_SET_RX |
                 ST_RX_WAIT_DIO1 |
                 ST_RX_GET_BUFFER_STATUS |
                 ST_RX_READ_BUFFER_STATUS |
                 ST_RX_READ_BUFFER |
                 ST_RX_READ_PAYLOAD |
                 ST_RX_CLEAR_IRQ_STATUS =>
                busy_o<='1';

            when ST_RESET_RELEASE =>

            when ST_COMMAND_DONE =>
                done_o<='1';
                read_valid_o<=rx_result_valid;

            when ST_COMMAND_ERROR =>
                error_o<='1';

            when others =>
                null;

            end case;
    end process;

end Behavioral;
