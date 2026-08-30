----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.08.2026 00:12:55
-- Design Name: 
-- Module Name: contador_N_clk - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Generador de un pulso de habilitacion cada N ciclos de reloj.
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
use IEEE.MATH_REAL.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity contador_N_clk is
    Generic (
        N : integer := 5
    );
    Port (
        rst : in  STD_LOGIC;
        clk : in  STD_LOGIC;
        s   : out STD_LOGIC
    );
end contador_N_clk;

architecture Behavioral of contador_N_clk is
    -- calculo dinamico de la cantidad de bits necesarios para contar hasta N-1
    constant M : integer := integer(ceil(log2(real(N))));
    signal q : unsigned(M-1 downto 0);

begin

    assert (N > 1)
        report "N debe ser mayor que 1"
        severity failure;

    s <= '1' when q = to_unsigned(N-1, M) else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                q <= to_unsigned(0, M);
            elsif q = to_unsigned(N-1, M) then
                q <= to_unsigned(0, M);
            else
                q <= q + to_unsigned(1, M);
            end if;
        end if;
    end process;

end Behavioral;
