----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 19:23:36
-- Design Name: 
-- Module Name: adder_1_bit - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Sumador completo de 1 bit con acarreo de entrada y salida.
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

entity adder_1_bit is
    Port ( ci : in STD_LOGIC;
           a : in STD_LOGIC;
           b : in STD_LOGIC;
           s : out STD_LOGIC;
           co : out STD_LOGIC);
end adder_1_bit;

architecture Behavioral of adder_1_bit is

begin
    
    s<= a xor b xor ci;
    co<= (a and b) or (b and ci) or (a and ci);

end Behavioral;
