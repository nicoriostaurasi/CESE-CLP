----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03.10.2026
-- Module Name: command_decoder_verification_wrapper - Behavioral
-- Description: Expone command_decoder sin UART ni controlador SX1278.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity command_decoder_verification_wrapper is
    generic (MAX_DATA_BYTES : integer := 50);
    port (
        clk : in std_logic; rst : in std_logic;
        uart_data_rd_i : in std_logic;
        uart_data_rx_i : in std_logic_vector(8-1 downto 0);
        controller_busy_i : in std_logic;
        peripheral_reset_active_i : in std_logic;
        config_wr_ena_o : out std_logic;
        config_addr_o : out std_logic_vector(8-1 downto 0);
        config_data_o : out std_logic_vector(8-1 downto 0);
        config_start_o : out std_logic;
        tx_data_o : out std_logic_vector(8-1 downto 0);
        tx_data_valid_o : out std_logic;
        tx_begin_o : out std_logic;
        tx_start_o : out std_logic;
        rx_start_o : out std_logic;
        peripheral_reset_request_o : out std_logic;
        response_start_o : out std_logic;
        response_command_o : out std_logic_vector(8-1 downto 0);
        response_status_o : out std_logic_vector(8-1 downto 0);
        response_data_o : out std_logic_vector(8-1 downto 0)
    );
end command_decoder_verification_wrapper;

architecture Behavioral of command_decoder_verification_wrapper is
begin
    dut : entity work.command_decoder
        generic map (MAX_DATA_BYTES => MAX_DATA_BYTES)
        port map (
            clk => clk, rst => rst,
            uart_data_rd_i => uart_data_rd_i,
            uart_data_rx_i => uart_data_rx_i,
            controller_busy_i => controller_busy_i,
            peripheral_reset_active_i => peripheral_reset_active_i,
            config_wr_ena_o => config_wr_ena_o,
            config_addr_o => config_addr_o, config_data_o => config_data_o,
            config_start_o => config_start_o, tx_data_o => tx_data_o,
            tx_data_valid_o => tx_data_valid_o, tx_begin_o => tx_begin_o,
            tx_start_o => tx_start_o, rx_start_o => rx_start_o,
            peripheral_reset_request_o => peripheral_reset_request_o,
            response_start_o => response_start_o,
            response_command_o => response_command_o,
            response_status_o => response_status_o,
            response_data_o => response_data_o
        );
end Behavioral;
