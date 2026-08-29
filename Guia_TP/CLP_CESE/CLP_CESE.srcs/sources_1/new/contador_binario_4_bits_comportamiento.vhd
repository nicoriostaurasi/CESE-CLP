----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 22:35:24
-- Design Name: 
-- Module Name: contador_binario_4_bits_comportamiento - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Contador binario de 4 bits descripto por comportamiento.
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity contador_binario_4_bits_comportamiento is
    Port ( ena : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           q   : out STD_LOGIC_VECTOR(4-1 downto 0));
end contador_binario_4_bits_comportamiento;

architecture Behavioral of contador_binario_4_bits_comportamiento is
    signal q_now, q_next: unsigned(4-1 downto 0);
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                q_now<=to_unsigned(0,4);
            else
                if ena = '1' then 
                    q_now<=q_next;
                end if;
            end if;            
        end if;    
    end process;
    
    q_next <= q_now + to_unsigned(1, 4);
    q <= std_logic_vector(q_now);

end Behavioral;
