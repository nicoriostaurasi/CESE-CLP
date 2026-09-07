----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.09.2026 12:03:59
-- Design Name: 
-- Module Name: sx1278_controller_pkg - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package sx1278_controller_pkg is
    constant CFG_FRF_MSB            : std_logic_vector(3 downto 0) := "0000";
    constant CFG_FRF_MID            : std_logic_vector(3 downto 0) := "0001";
    constant CFG_FRF_LSB            : std_logic_vector(3 downto 0) := "0010";
    constant CFG_BANDWIDTH          : std_logic_vector(3 downto 0) := "0011";
    constant CFG_CODING_RATE        : std_logic_vector(3 downto 0) := "0100";
    constant CFG_SPREADING_FACTOR   : std_logic_vector(3 downto 0) := "0101";
    constant CFG_PREAMBLE_MSB       : std_logic_vector(3 downto 0) := "0110";
    constant CFG_PREAMBLE_LSB       : std_logic_vector(3 downto 0) := "0111";
    constant CFG_TX_POWER_DBM       : std_logic_vector(3 downto 0) := "1000";
end package sx1278_controller_pkg;
