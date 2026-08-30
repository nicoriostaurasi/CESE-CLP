----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 21:21:13
-- Design Name: 
-- Module Name: reg_desp_comportamiento - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Registro de desplazamiento serie de 4 bits por comportamiento.
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

entity reg_desp_comportamiento is
    Port ( E : in STD_LOGIC;
           S : out STD_LOGIC;
           rst : in STD_LOGIC;
           clk : in STD_LOGIC);
end reg_desp_comportamiento;

architecture Behavioral of reg_desp_comportamiento is
    signal q: STD_LOGIC_VECTOR(4-1 downto 0);
begin
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                q<=(others=>'0');
            else
                q<= E & q(4-1 downto 1);
            end if;                
        end if;
    end process;
    S <= q(0);    

end Behavioral;
