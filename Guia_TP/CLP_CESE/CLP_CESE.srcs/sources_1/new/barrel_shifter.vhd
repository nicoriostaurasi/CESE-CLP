----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 21:34:59
-- Design Name: 
-- Module Name: barrel_shifter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Barrel shifter generico con desplazamiento logico a derecha.
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

entity barrel_shifter is
    Generic (
        N : integer := 8;
        M : integer := 3
    );
    Port (
        a   : in  STD_LOGIC_VECTOR(N-1 downto 0);
        des : in  STD_LOGIC_VECTOR(M-1 downto 0);
        s   : out STD_LOGIC_VECTOR(N-1 downto 0)
    );
end barrel_shifter;

architecture Behavioral of barrel_shifter is

begin

    s <= STD_LOGIC_VECTOR(shift_right(unsigned(a), to_integer(unsigned(des))));

end Behavioral;
