----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:58:49
-- Design Name: 
-- Module Name: reg_desp_estructural - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Registro de desplazamiento serie de 4 bits formado por FFD.
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

entity reg_desp_estructural is
    Port ( E : in STD_LOGIC;
           S : out STD_LOGIC;
           rst : in STD_LOGIC;
           clk : in STD_LOGIC);
end reg_desp_estructural;

architecture Behavioral of reg_desp_estructural is

    signal reg_aux : STD_LOGIC_VECTOR(4 downto 0);

begin

    reg_aux(0) <= E;
    S <= reg_aux(4);

    registro : for i in 0 to 3 generate
        ffd_instance : entity work.ffd
            port map (
                d   => reg_aux(i),
                ena => '1',
                rst => rst,
                clk => clk,
                q   => reg_aux(i + 1)
            );
    end generate registro;

end Behavioral;
