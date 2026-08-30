----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:18:36
-- Design Name: 
-- Module Name: sum_res_4_bits_tb - Behavioral
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

entity sum_res_4_bits_tb is
--  Port ( );
end sum_res_4_bits_tb;

architecture Behavioral of sum_res_4_bits_tb is

    -- inputs
    signal sr : STD_LOGIC;
    signal a  : STD_LOGIC_VECTOR(3 downto 0);
    signal b  : STD_LOGIC_VECTOR(3 downto 0);

    -- outputs
    signal s  : STD_LOGIC_VECTOR(3 downto 0);
    signal co : STD_LOGIC;

begin

    uut : entity work.sum_res_4_bits
        port map (
            sr => sr,
            a  => a,
            b  => b,
            s  => s,
            co => co
        );

    stim_proc : process
    begin
        ------------------------------------------------------------------------
        -- SUMAS: sr = 0
        ------------------------------------------------------------------------

        -- 0 + 0 = 0
        sr <= '0'; a <= "0000"; b <= "0000";
        wait for 10 ns;
        assert (co = '0' and s = "0000")
            report "Error en suma: 0 + 0" severity error;

        -- 1 + 1 = 2
        sr <= '0'; a <= "0001"; b <= "0001";
        wait for 10 ns;
        assert (co = '0' and s = "0010")
            report "Error en suma: 1 + 1" severity error;

        -- 5 + 3 = 8
        sr <= '0'; a <= "0101"; b <= "0011";
        wait for 10 ns;
        assert (co = '0' and s = "1000")
            report "Error en suma: 5 + 3" severity error;

        -- 7 + 8 = 15
        sr <= '0'; a <= "0111"; b <= "1000";
        wait for 10 ns;
        assert (co = '0' and s = "1111")
            report "Error en suma: 7 + 8" severity error;

        -- 15 + 0 = 15
        sr <= '0'; a <= "1111"; b <= "0000";
        wait for 10 ns;
        assert (co = '0' and s = "1111")
            report "Error en suma: 15 + 0" severity error;

        -- 15 + 1 = 16
        sr <= '0'; a <= "1111"; b <= "0001";
        wait for 10 ns;
        assert (co = '1' and s = "0000")
            report "Error en suma: 15 + 1" severity error;

        -- 9 + 9 = 18
        sr <= '0'; a <= "1001"; b <= "1001";
        wait for 10 ns;
        assert (co = '1' and s = "0010")
            report "Error en suma: 9 + 9" severity error;

        -- 15 + 15 = 30
        sr <= '0'; a <= "1111"; b <= "1111";
        wait for 10 ns;
        assert (co = '1' and s = "1110")
            report "Error en suma: 15 + 15" severity error;

        report "Los 8 casos de suma pasaron correctamente" severity note;

        ------------------------------------------------------------------------
        -- RESTAS: sr = 1
        -- co = 1 indica que no hubo borrow; co = 0 indica borrow.
        ------------------------------------------------------------------------

        -- 0 - 0 = 0
        sr <= '1'; a <= "0000"; b <= "0000";
        wait for 10 ns;
        assert (co = '1' and s = "0000")
            report "Error en resta: 0 - 0" severity error;

        -- 7 - 3 = 4
        sr <= '1'; a <= "0111"; b <= "0011";
        wait for 10 ns;
        assert (co = '1' and s = "0100")
            report "Error en resta: 7 - 3" severity error;

        -- 15 - 1 = 14
        sr <= '1'; a <= "1111"; b <= "0001";
        wait for 10 ns;
        assert (co = '1' and s = "1110")
            report "Error en resta: 15 - 1" severity error;

        -- 8 - 8 = 0
        sr <= '1'; a <= "1000"; b <= "1000";
        wait for 10 ns;
        assert (co = '1' and s = "0000")
            report "Error en resta: 8 - 8" severity error;

        -- 3 - 5 = -2 = 1110 en complemento a dos
        sr <= '1'; a <= "0011"; b <= "0101";
        wait for 10 ns;
        assert (co = '0' and s = "1110")
            report "Error en resta: 3 - 5" severity error;

        -- 0 - 1 = -1 = 1111 en complemento a dos
        sr <= '1'; a <= "0000"; b <= "0001";
        wait for 10 ns;
        assert (co = '0' and s = "1111")
            report "Error en resta: 0 - 1" severity error;

        -- 2 - 9 = -7 = 1001 en complemento a dos
        sr <= '1'; a <= "0010"; b <= "1001";
        wait for 10 ns;
        assert (co = '0' and s = "1001")
            report "Error en resta: 2 - 9" severity error;

        -- 15 - 0 = 15
        sr <= '1'; a <= "1111"; b <= "0000";
        wait for 10 ns;
        assert (co = '1' and s = "1111")
            report "Error en resta: 15 - 0" severity error;

        report "Los 8 casos de resta pasaron correctamente" severity note;
        report "Todos los casos del sumador/restador pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
