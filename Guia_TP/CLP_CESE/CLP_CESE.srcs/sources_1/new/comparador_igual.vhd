----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:27:44
-- Design Name: 
-- Module Name: comparador_igual - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Comparador de igualdad generico para dos palabras de N bits.
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

entity comparador_igual is
    Generic (
        N : integer := 4
    );
    Port ( a     : in  STD_LOGIC_VECTOR(N-1 downto 0);
           b     : in  STD_LOGIC_VECTOR(N-1 downto 0);
           igual : out STD_LOGIC
    );
end comparador_igual;

architecture Behavioral of comparador_igual is

begin
    igual <= '1' when a = b else '0';

end Behavioral;
