----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:53:00
-- Design Name: 
-- Module Name: ffd_tb - Behavioral
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

entity ffd_tb is
--  Port ( );
end ffd_tb;

architecture Behavioral of ffd_tb is

    constant clk_period : time := 10 ns;

    -- inputs
    signal d   : STD_LOGIC := '0';
    signal ena : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal q : STD_LOGIC;

begin

    uut : entity work.ffd
        port map (
            d   => d,
            ena => ena,
            rst => rst,
            clk => clk,
            q   => q
        );

    -- Clock process
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Reset process
    resetProc : process
    begin
        rst <= '1';
        wait for 50 ns;
        rst <= '0';
        wait;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        d   <= '0';
        ena <= '0';

        -- Espera a que termine el reset.
        wait until falling_edge(rst);
        wait for 1 ns;
        assert (q = '0')
            report "Error: q no quedo en 0 despues del reset" severity error;

        -- Con enable activo, captura d=1 en el siguiente flanco ascendente.
        d   <= '1';
        ena <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = '1')
            report "Error: no capturo d=1 con ena=1" severity error;

        -- Con enable inactivo, debe conservar el valor aunque d cambie.
        d   <= '0';
        ena <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = '1')
            report "Error: q cambio con ena=0" severity error;

        -- Con enable nuevamente activo, captura d=0.
        ena <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = '0')
            report "Error: no capturo d=0 con ena=1" severity error;

        -- Comprueba otra captura de nivel alto.
        d <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = '1')
            report "Error: no realizo la segunda captura de d=1" severity error;

        report "Todas las pruebas del flip-flop D pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
