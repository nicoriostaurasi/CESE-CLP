----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 22:52:03
-- Design Name: 
-- Module Name: contador_binario_N_bits_estructural - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Contador binario estructural generico de N bits.
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

entity contador_binario_N_bits_estructural is
    Generic (
        N : integer := 4
    );
    Port (
        ena : in  STD_LOGIC;
        rst : in  STD_LOGIC;
        clk : in  STD_LOGIC;
        q   : out STD_LOGIC_VECTOR(N-1 downto 0)
    );
end contador_binario_N_bits_estructural;

architecture Behavioral of contador_binario_N_bits_estructural is

    signal ena_aux : STD_LOGIC_VECTOR(N+1-1 downto 0);

begin

    ena_aux(0) <= ena;

    celdas : for i in 0 to N-1 generate
        celda_instance : entity work.celda_unitaria_contador_binario
            port map (
                ena_in  => ena_aux(i),
                rst     => rst,
                clk     => clk,
                q       => q(i),
                ena_out => ena_aux(i + 1)
            );
    end generate celdas;

end Behavioral;
