----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03.10.2026
-- Module Name: sx1278_controller_verification_wrapper - Behavioral
-- Description: Wrapper para verificar el controlador SX1278 sin UART.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sx1278_controller_verification_wrapper is
    generic (
        MAX_DATA_BYTES : integer := 50;
        CLK_FREQ_HZ : integer := 1_000_000;
        SPI_FREQ_HZ : integer := 100_000;
        RESET_TIME_MS : integer := 1
    );
    port (
        clk : in std_logic; rst : in std_logic;
        config_wr_ena_i : in std_logic;
        config_addr_i : in std_logic_vector(8-1 downto 0);
        config_data_i : in std_logic_vector(8-1 downto 0);
        start_config_i : in std_logic;
        reset_request_i : in std_logic;
        tx_begin_i : in std_logic;
        tx_data_i : in std_logic_vector(8-1 downto 0);
        tx_data_valid_i : in std_logic;
        start_tx_i : in std_logic;
        start_rx_i : in std_logic;
        rx_valid_o : out std_logic;
        rx_length_o : out std_logic_vector(6-1 downto 0);
        rx_read_index_i : in std_logic_vector(6-1 downto 0);
        rx_data_o : out std_logic_vector(8-1 downto 0);
        rx_packet_pending_o : out std_logic;
        rx_stream_index_i : in std_logic_vector(6-1 downto 0);
        rx_stream_data_o : out std_logic_vector(8-1 downto 0);
        rx_packet_sent_i : in std_logic;
        busy_o : out std_logic; done_o : out std_logic; error_o : out std_logic;
        spi_sclk_o : out std_logic; spi_mosi_o : out std_logic;
        spi_miso_i : in std_logic; spi_nss_o : out std_logic;
        sx1278_dio0_i : in std_logic; sx1278_reset_o : out std_logic;
        peripheral_reset_active_o : out std_logic
    );
end sx1278_controller_verification_wrapper;

architecture Behavioral of sx1278_controller_verification_wrapper is
begin
    dut : entity work.sx1278_controller
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES, CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ, RESET_TIME_MS => RESET_TIME_MS
        )
        port map (
            clk => clk, rst => rst, config_wr_ena_i => config_wr_ena_i,
            config_addr_i => config_addr_i, config_data_i => config_data_i,
            config_start_i => start_config_i,
            peripheral_reset_request_i => reset_request_i,
            tx_begin_i => tx_begin_i, tx_data_i => tx_data_i,
            tx_data_valid_i => tx_data_valid_i, tx_start_i => start_tx_i,
            rx_start_i => start_rx_i, rx_valid_o => rx_valid_o,
            rx_length_o => rx_length_o, rx_read_index_i => rx_read_index_i,
            rx_data_o => rx_data_o, rx_packet_pending_o => rx_packet_pending_o,
            rx_stream_index_i => rx_stream_index_i,
            rx_stream_data_o => rx_stream_data_o,
            rx_packet_sent_i => rx_packet_sent_i, busy_o => busy_o,
            done_o => done_o, error_o => error_o, spi_sclk_o => spi_sclk_o,
            spi_mosi_o => spi_mosi_o, spi_miso_i => spi_miso_i,
            spi_nss_o => spi_nss_o, sx1278_dio0_i => sx1278_dio0_i,
            sx1278_reset_o => sx1278_reset_o,
            peripheral_reset_active_o => peripheral_reset_active_o
        );
end Behavioral;
