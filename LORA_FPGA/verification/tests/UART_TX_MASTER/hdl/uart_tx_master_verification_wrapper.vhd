----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03.10.2026
-- Module Name: uart_tx_master_verification_wrapper - Behavioral
-- Description: Wrapper del arbitro y serializadores de salida UART.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_tx_master_verification_wrapper is
    generic (MAX_DATA_BYTES : integer := 50);
    port (
        clk : in std_logic; rst : in std_logic;
        response_start_i : in std_logic;
        response_command_i : in std_logic_vector(8-1 downto 0);
        response_status_i : in std_logic_vector(8-1 downto 0);
        response_data_i : in std_logic_vector(8-1 downto 0);
        rx_packet_valid_i : in std_logic;
        rx_packet_length_i : in std_logic_vector(6-1 downto 0);
        rx_packet_index_o : out std_logic_vector(6-1 downto 0);
        rx_packet_data_i : in std_logic_vector(8-1 downto 0);
        rx_packet_sent_o : out std_logic;
        uart_ready_i : in std_logic;
        uart_data_o : out std_logic_vector(8-1 downto 0);
        uart_wr_o : out std_logic
    );
end uart_tx_master_verification_wrapper;

architecture Behavioral of uart_tx_master_verification_wrapper is
begin
    dut : entity work.uart_tx_master
        generic map (MAX_DATA_BYTES => MAX_DATA_BYTES)
        port map (
            clk => clk, rst => rst,
            response_start_i => response_start_i,
            response_command_i => response_command_i,
            response_status_i => response_status_i,
            response_data_i => response_data_i,
            rx_packet_valid_i => rx_packet_valid_i,
            rx_packet_length_i => rx_packet_length_i,
            rx_packet_index_o => rx_packet_index_o,
            rx_packet_data_i => rx_packet_data_i,
            rx_packet_sent_o => rx_packet_sent_o,
            uart_ready_i => uart_ready_i,
            uart_data_o => uart_data_o, uart_wr_o => uart_wr_o
        );
end Behavioral;
