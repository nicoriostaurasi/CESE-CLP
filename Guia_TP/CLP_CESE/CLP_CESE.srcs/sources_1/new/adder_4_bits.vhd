----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 19:49:11
-- Design Name: 
-- Module Name: adder_4_bits - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Sumador estructural de 4 bits formado por cuatro sumadores completos.
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

library work;
use work.adder_1_bit;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity adder_4_bits is
    Port ( ci : in STD_LOGIC;
            a : in STD_LOGIC_VECTOR(4-1 downto 0);
            b : in STD_LOGIC_VECTOR(4-1 downto 0);
            s : out STD_LOGIC_VECTOR(4-1 downto 0);
           co : out STD_LOGIC);
end adder_4_bits;

architecture Behavioral of adder_4_bits is
    signal c_vector : STD_LOGIC_VECTOR(5-1 downto 0);
begin
    c_vector(0) <= ci;
    co <= c_vector(4);

    ciclo : for i in 0 to 3 generate
        adder_1_bit_instance : entity work.adder_1_bit
            port map (
                ci => c_vector(i),
                a  => a(i),
                b  => b(i),
                s  => s(i),
                co => c_vector(i + 1)
            );
    end generate ciclo;
end Behavioral;
