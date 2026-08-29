----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 21:35:34
-- Design Name: 
-- Module Name: barrel_shifter_tb - Behavioral
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

entity barrel_shifter_tb is
--  Port ( );
end barrel_shifter_tb;

architecture Behavioral of barrel_shifter_tb is

    constant N : integer := 8;
    constant M : integer := 3;

    -- inputs
    signal a   : STD_LOGIC_VECTOR(N-1 downto 0);
    signal des : STD_LOGIC_VECTOR(M-1 downto 0);

    -- outputs
    signal s : STD_LOGIC_VECTOR(N-1 downto 0);

begin

    uut : entity work.barrel_shifter
        generic map (
            N => N,
            M => M
        )
        port map (
            a   => a,
            des => des,
            s   => s
        );

    stim_proc : process
    begin
        -- Patron elegido para distinguir claramente cada desplazamiento.
        a <= "10110101";

        des <= "000";
        wait for 10 ns;
        assert (s = "10110101")
            report "Error al desplazar 0 posiciones" severity error;

        des <= "001";
        wait for 10 ns;
        assert (s = "01011010")
            report "Error al desplazar 1 posicion" severity error;

        des <= "010";
        wait for 10 ns;
        assert (s = "00101101")
            report "Error al desplazar 2 posiciones" severity error;

        des <= "011";
        wait for 10 ns;
        assert (s = "00010110")
            report "Error al desplazar 3 posiciones" severity error;

        des <= "100";
        wait for 10 ns;
        assert (s = "00001011")
            report "Error al desplazar 4 posiciones" severity error;

        des <= "101";
        wait for 10 ns;
        assert (s = "00000101")
            report "Error al desplazar 5 posiciones" severity error;

        des <= "110";
        wait for 10 ns;
        assert (s = "00000010")
            report "Error al desplazar 6 posiciones" severity error;

        des <= "111";
        wait for 10 ns;
        assert (s = "00000001")
            report "Error al desplazar 7 posiciones" severity error;

        report "Todas las pruebas del barrel shifter pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
