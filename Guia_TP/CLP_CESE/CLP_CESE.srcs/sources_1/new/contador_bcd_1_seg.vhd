----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.08.2026 00:32:06
-- Design Name: 
-- Module Name: contador_bcd_1_seg - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Top level de contador BCD con avance periodico y enable general.
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

entity contador_bcd_1_seg is
    Generic (
        SYS_CLK : integer := 100000000
    );
    Port (
        ena : in  STD_LOGIC;
        rst : in  STD_LOGIC;
        clk : in  STD_LOGIC;
        q   : out STD_LOGIC_VECTOR(3 downto 0)
    );
end contador_bcd_1_seg;

architecture Behavioral of contador_bcd_1_seg is

    signal pulso_1s : STD_LOGIC;
    signal ena_bcd  : STD_LOGIC;

begin

    ena_bcd <= ena and pulso_1s;

    generador_1s_instance : entity work.contador_N_clk
        generic map (
            N => SYS_CLK
        )
        port map (
            rst => rst,
            clk => clk,
            s   => pulso_1s
        );

    contador_bcd_instance : entity work.contador_bcd
        port map (
            ena => ena_bcd,
            rst => rst,
            clk => clk,
            q   => q,
            co  => open
        );

end Behavioral;
