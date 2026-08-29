----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:36:34
-- Design Name: 
-- Module Name: mux_2_a_1 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Multiplexor combinacional de dos entradas de 1 bit.
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

entity mux_2_a_1 is
    Port (  a : in STD_LOGIC;
            b : in STD_LOGIC;
           sel: in STD_LOGIC;
           mux: out STD_LOGIC);
end mux_2_a_1;

architecture Behavioral of mux_2_a_1 is

begin
    mux<= a when sel='0' else b;
end Behavioral;
