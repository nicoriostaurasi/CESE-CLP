----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03.10.2026
-- Module Name: spi_verification_wrapper - Behavioral
-- Description: Wrapper de verificacion para spi_frame_controller.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_verification_wrapper is
    generic (
        RAM_DEPTH : integer := 8;
        CLK_FREQ_HZ : integer := 1_000_000;
        SPI_FREQ_HZ : integer := 100_000;
        INTER_FRAME_DELAY_US : integer := 1
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        byte_i : in std_logic_vector(8-1 downto 0);
        charge_byte : in std_logic;
        start_spi_transfer : in std_logic;
        busy : out std_logic;
        done : out std_logic;
        rx_ram_read : in std_logic;
        rx_ram_empty : out std_logic;
        rx_ram_data_o : out std_logic_vector(8-1 downto 0);
        spi_sclk_o : out std_logic;
        spi_mosi_o : out std_logic;
        spi_miso_i : in std_logic;
        spi_nss_o : out std_logic
    );
end spi_verification_wrapper;

architecture Behavioral of spi_verification_wrapper is
begin
    dut : entity work.spi_frame_controller
        generic map (
            RAM_DEPTH => RAM_DEPTH,
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            INTER_FRAME_DELAY_US => INTER_FRAME_DELAY_US,
            CPOL => '0', CPHA => '0', IDLE_VALUE => '1'
        )
        port map (
            clk => clk, rst => rst, byte_i => byte_i,
            charge_byte => charge_byte,
            start_spi_transfer => start_spi_transfer,
            busy => busy, done => done, rx_ram_read => rx_ram_read,
            rx_ram_empty => rx_ram_empty, rx_ram_data_o => rx_ram_data_o,
            spi_sclk_o => spi_sclk_o, spi_mosi_o => spi_mosi_o,
            spi_miso_i => spi_miso_i, spi_nss_o => spi_nss_o
        );
end Behavioral;
