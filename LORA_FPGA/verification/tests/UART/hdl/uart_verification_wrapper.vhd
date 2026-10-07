----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03.10.2026
-- Module Name: uart_verification_wrapper - Behavioral
-- Description: Wrapper de verificacion para probar myUart como DUT aislado.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_verification_wrapper is
    generic (
        BAUD_RATE : integer := 100_000;
        CLK_FREQ_HZ : integer := 1_000_000;
        DATA_SIZE : integer := 8
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        dataWr : in std_logic;
        dataTx : in std_logic_vector(DATA_SIZE-1 downto 0);
        ready : out std_logic;
        tx : out std_logic;
        dataRd : out std_logic;
        dataRx : out std_logic_vector(DATA_SIZE-1 downto 0);
        rx : in std_logic
    );
end uart_verification_wrapper;

architecture Behavioral of uart_verification_wrapper is
begin
    dut : entity work.myUart
        generic map (
            baudRate => BAUD_RATE,
            sysClk => CLK_FREQ_HZ,
            dataSize => DATA_SIZE
        )
        port map (
            clk => clk, rst => rst, dataWr => dataWr, dataTx => dataTx,
            ready => ready, tx => tx, dataRd => dataRd, dataRx => dataRx,
            rx => rx
        );
end Behavioral;
