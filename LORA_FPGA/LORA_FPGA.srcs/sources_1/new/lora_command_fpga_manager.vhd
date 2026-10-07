----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 12.09.2026 23:40:10
-- Design Name:
-- Module Name: lora_command_fpga_manager - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Top del controlador LoRa. Integra UART, decodificador de
--              comandos, controlador SPI del SX1278 y señales de placa.
--
-- Dependencies: myUart, command_decoder, sx1278_controller,
--               uart_tx_master, led_status_controller
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.sx1278_controller_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lora_command_fpga_manager is
    generic (
        CLK_FREQ_HZ : integer := 125_000_000;
        SPI_FREQ_HZ : integer := 5_000_000;
        UART_BAUDRATE : integer := 115_200;
        RESET_TIME_MS : integer := 10;
        HEARTBEAT_HALF_PERIOD_MS : integer := 500;
        UART_ACTIVITY_TIME_MS : integer := 100;
        MAX_DATA_BYTES : integer := 50
    );
    port (
        -- Reloj de la placa Zybo.
        clk : in std_logic;
        -- Reset general sincrono activo en alto.
        rst : in std_logic;

        -- Linea serie recibida desde el host.
        uart_rx_i : in std_logic;
        -- Linea serie transmitida hacia el host.
        uart_tx_o : out std_logic;

        -- Reloj SPI generado para el SX1278.
        spi_sclk_o : out std_logic;
        -- Datos SPI enviados al SX1278.
        spi_mosi_o : out std_logic;
        -- Datos SPI recibidos desde el SX1278.
        spi_miso_i : in std_logic;
        -- Seleccion activa en bajo del SX1278.
        spi_nss_o : out std_logic;

        -- Interrupcion DIO0 producida por RxDone o TxDone.
        sx1278_dio0_i : in std_logic;
        -- Reset fisico del SX1278, activo en bajo.
        sx1278_reset_o : out std_logic;
        -- Indicadores de heartbeat, UART, actividad y error.
        status_led_o : out std_logic_vector(4-1 downto 0)
    );
end lora_command_fpga_manager;

architecture Behavioral of lora_command_fpga_manager is

    -- Frontera UART byte a byte. myUart solamente resuelve la temporizacion
    -- serie; el significado de cada byte pertenece a command_decoder.
    signal uart_data_wr : std_logic;
    signal uart_data_tx : std_logic_vector(7 downto 0);
    signal uart_tx_ready : std_logic;
    signal uart_data_rd : std_logic;
    signal uart_data_rx : std_logic_vector(7 downto 0);

    -- Respuesta ya decodificada. uart_tx_master encapsula el serializador
    -- que agrega delimitadores y checksum antes de entregarla a myUart.
    signal response_start : std_logic;
    signal response_command : std_logic_vector(7 downto 0);
    signal response_status : std_logic_vector(7 downto 0);
    signal response_data : std_logic_vector(7 downto 0);

    -- Interfaz de configuracion del SX1278. Las escrituras modifican el banco
    -- local; config_start ordena aplicar posteriormente el conjunto completo.
    signal config_wr_ena : std_logic;
    signal config_addr : std_logic_vector(8-1 downto 0);
    signal config_data : std_logic_vector(7 downto 0);
    signal config_start : std_logic;

    -- Interfaz de datos LoRa. TX se carga byte a byte antes de tx_start. En RX
    -- el controlador expone el paquete en paralelo y el serializador lo recorre
    -- mediante rx_stream_index sin incorporar logica de protocolo en este top.
    signal tx_payload_data : std_logic_vector(7 downto 0);
    signal tx_payload_valid : std_logic;
    signal tx_begin : std_logic;
    signal tx_start : std_logic;
    signal rx_start : std_logic;
    signal rx_payload_data : std_logic_vector(8-1 downto 0);
    signal rx_payload_length : std_logic_vector(6-1 downto 0);
    signal rx_payload_valid : std_logic;
    signal rx_packet_pending : std_logic;
    signal rx_stream_index : std_logic_vector(6-1 downto 0);
    signal rx_stream_data : std_logic_vector(8-1 downto 0);
    signal rx_packet_sent : std_logic;
    signal peripheral_reset_request : std_logic;

    -- Handshake comun entre el decodificador UART y el controlador LoRa.
    -- Permite responder cuando la operacion real termina y no solamente cuando
    -- la orden fue recibida.
    signal controller_busy : std_logic;
    signal controller_done : std_logic;
    signal controller_error : std_logic;

    signal peripheral_reset_active : std_logic;

begin

    uart_interface : entity work.myUart
        generic map (
            baudRate => UART_BAUDRATE,
            sysClk => CLK_FREQ_HZ,
            dataSize => 8
        )
        port map (
            clk => clk,
            rst => rst,
            dataWr => uart_data_wr,
            dataTx => uart_data_tx,
            ready => uart_tx_ready,
            tx => uart_tx_o,
            dataRd => uart_data_rd,
            dataRx => uart_data_rx,
            rx => uart_rx_i
        );

    uart_command_decoder : entity work.command_decoder
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            uart_data_rd_i => uart_data_rd,
            uart_data_rx_i => uart_data_rx,
            controller_busy_i => controller_busy,
            peripheral_reset_active_i => peripheral_reset_active,
            config_wr_ena_o => config_wr_ena,
            config_addr_o => config_addr,
            config_data_o => config_data,
            config_start_o => config_start,
            tx_data_o => tx_payload_data,
            tx_data_valid_o => tx_payload_valid,
            tx_begin_o => tx_begin,
            tx_start_o => tx_start,
            rx_start_o => rx_start,
            peripheral_reset_request_o => peripheral_reset_request,
            response_start_o => response_start,
            response_command_o => response_command,
            response_status_o => response_status,
            response_data_o => response_data
        );

    sx1278_control : entity work.sx1278_controller
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES,
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            RESET_TIME_MS => RESET_TIME_MS
        )
        port map (
            clk => clk,
            rst => rst,
            config_wr_ena_i => config_wr_ena,
            config_addr_i => config_addr,
            config_data_i => config_data,
            config_start_i => config_start,
            tx_begin_i => tx_begin,
            tx_data_i => tx_payload_data,
            tx_data_valid_i => tx_payload_valid,
            tx_start_i => tx_start,
            rx_start_i => rx_start,
            rx_read_index_i => (others=>'0'),
            rx_data_o => rx_payload_data,
            rx_length_o => rx_payload_length,
            rx_valid_o => rx_payload_valid,
            rx_packet_pending_o => rx_packet_pending,
            rx_stream_index_i => rx_stream_index,
            rx_stream_data_o => rx_stream_data,
            rx_packet_sent_i => rx_packet_sent,
            peripheral_reset_request_i => peripheral_reset_request,
            busy_o => controller_busy,
            done_o => controller_done,
            error_o => controller_error,
            spi_sclk_o => spi_sclk_o,
            spi_mosi_o => spi_mosi_o,
            spi_miso_i => spi_miso_i,
            spi_nss_o => spi_nss_o,
            sx1278_dio0_i => sx1278_dio0_i,
            sx1278_reset_o => sx1278_reset_o,
            peripheral_reset_active_o => peripheral_reset_active
        );

    uart_output_master : entity work.uart_tx_master
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            response_start_i => response_start,
            response_command_i => response_command,
            response_status_i => response_status,
            response_data_i => response_data,
            rx_packet_valid_i => rx_packet_pending,
            rx_packet_length_i => rx_payload_length,
            rx_packet_index_o => rx_stream_index,
            rx_packet_data_i => rx_stream_data,
            rx_packet_sent_o => rx_packet_sent,
            uart_ready_i => uart_tx_ready,
            uart_data_o => uart_data_tx,
            uart_wr_o => uart_data_wr
        );

    status_led_control : entity work.led_status_controller
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            HEARTBEAT_HALF_PERIOD_MS => HEARTBEAT_HALF_PERIOD_MS,
            UART_ACTIVITY_TIME_MS => UART_ACTIVITY_TIME_MS
        )
        port map (
            clk => clk,
            rst => rst,
            uart_frame_received_i => response_start,
            controller_busy_i => controller_busy,
            controller_error_i => controller_error,
            response_status_i => response_status,
            leds_o => status_led_o
        );

end Behavioral;
