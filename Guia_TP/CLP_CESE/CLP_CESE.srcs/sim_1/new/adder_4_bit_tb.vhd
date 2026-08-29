----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:00:24
-- Design Name: 
-- Module Name: adder_4_bit_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
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

entity adder_4_bit_tb is
--  Port ( );
end adder_4_bit_tb;

architecture Behavioral of adder_4_bit_tb is

    -- inputs
    signal ci : STD_LOGIC;
    signal a  : STD_LOGIC_VECTOR(3 downto 0);
    signal b  : STD_LOGIC_VECTOR(3 downto 0);

    -- outputs
    signal s  : STD_LOGIC_VECTOR(3 downto 0);
    signal co : STD_LOGIC;

begin

    uut : entity work.adder_4_bits
        port map (
            ci => ci,
            a  => a,
            b  => b,
            s  => s,
            co => co
        );

    stim_proc : process
    begin
        -- 0 + 0 + 0 = 0
        a <= "0000"; b <= "0000"; ci <= '0';
        wait for 10 ns;
        assert (co = '0' and s = "0000")
            report "Error: 0 + 0 + 0" severity error;

        -- 1 + 1 + 0 = 2
        a <= "0001"; b <= "0001"; ci <= '0';
        wait for 10 ns;
        assert (co = '0' and s = "0010")
            report "Error: 1 + 1 + 0" severity error;

        -- 5 + 3 + 0 = 8
        a <= "0101"; b <= "0011"; ci <= '0';
        wait for 10 ns;
        assert (co = '0' and s = "1000")
            report "Error: 5 + 3 + 0" severity error;

        -- 5 + 3 + 1 = 9: comprueba ci
        a <= "0101"; b <= "0011"; ci <= '1';
        wait for 10 ns;
        assert (co = '0' and s = "1001")
            report "Error: 5 + 3 + 1" severity error;

        -- 7 + 1 + 0 = 8: propagacion de acarreo interno
        a <= "0111"; b <= "0001"; ci <= '0';
        wait for 10 ns;
        assert (co = '0' and s = "1000")
            report "Error: 7 + 1 + 0" severity error;

        -- 15 + 0 + 1 = 16: ci propagado por los cuatro bits
        a <= "1111"; b <= "0000"; ci <= '1';
        wait for 10 ns;
        assert (co = '1' and s = "0000")
            report "Error: 15 + 0 + 1" severity error;

        -- 9 + 9 + 0 = 18: resultado con acarreo de salida
        a <= "1001"; b <= "1001"; ci <= '0';
        wait for 10 ns;
        assert (co = '1' and s = "0010")
            report "Error: 9 + 9 + 0" severity error;

        -- 15 + 15 + 1 = 31: valor maximo
        a <= "1111"; b <= "1111"; ci <= '1';
        wait for 10 ns;
        assert (co = '1' and s = "1111")
            report "Error: 15 + 15 + 1" severity error;

        report "Los 8 casos del sumador de 4 bits pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
