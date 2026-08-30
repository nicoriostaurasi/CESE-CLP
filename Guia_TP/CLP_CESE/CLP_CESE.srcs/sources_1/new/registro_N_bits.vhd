----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:34:00
-- Design Name: 
-- Module Name: registro_N_bits - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Registro paralelo generico de N bits con enable y reset sincrono.
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

entity registro_N_bits is
    Generic (
        N : integer := 4
    );
    Port (
        d   : in  STD_LOGIC_VECTOR(N-1 downto 0);
        ena : in  STD_LOGIC;
        rst : in  STD_LOGIC;
        clk : in  STD_LOGIC;
        q   : out STD_LOGIC_VECTOR(N-1 downto 0)
    );
end registro_N_bits;

architecture Behavioral of registro_N_bits is

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                q <= (others => '0');
            elsif ena = '1' then
                q <= d;
            end if;
        end if;
    end process;

end Behavioral;
