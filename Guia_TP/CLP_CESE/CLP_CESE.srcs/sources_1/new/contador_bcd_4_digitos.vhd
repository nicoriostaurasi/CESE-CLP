----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:56:03
-- Design Name: 
-- Module Name: contador_bcd_4_digitos - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Contador BCD de cuatro digitos mediante contadores encadenados.
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

entity contador_bcd_4_digitos is
    Port (
        ena  : in  STD_LOGIC;
        rst  : in  STD_LOGIC;
        clk  : in  STD_LOGIC;
        bcd0 : out STD_LOGIC_VECTOR(3 downto 0);
        bcd1 : out STD_LOGIC_VECTOR(3 downto 0);
        bcd2 : out STD_LOGIC_VECTOR(3 downto 0);
        bcd3 : out STD_LOGIC_VECTOR(3 downto 0);
        co   : out STD_LOGIC
    );
end contador_bcd_4_digitos;

architecture Behavioral of contador_bcd_4_digitos is

    signal ena_aux : STD_LOGIC_VECTOR(4 downto 0);
    signal q_aux   : STD_LOGIC_VECTOR(15 downto 0);

begin

    ena_aux(0) <= ena;
    co <= ena_aux(4);

    bcd0 <= q_aux(3 downto 0);
    bcd1 <= q_aux(7 downto 4);
    bcd2 <= q_aux(11 downto 8);
    bcd3 <= q_aux(15 downto 12);

    digitos : for i in 0 to 3 generate
        contador_instance : entity work.contador_bcd
            port map (
                ena => ena_aux(i),
                rst => rst,
                clk => clk,
                q   => q_aux(4*i+3 downto 4*i),
                co  => ena_aux(i + 1)
            );
    end generate digitos;

end Behavioral;
