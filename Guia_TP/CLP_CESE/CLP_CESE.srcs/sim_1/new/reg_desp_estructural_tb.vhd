----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:59:22
-- Design Name: 
-- Module Name: reg_desp_estructural_tb - Behavioral
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

entity reg_desp_estructural_tb is
--  Port ( );
end reg_desp_estructural_tb;

architecture Behavioral of reg_desp_estructural_tb is

    constant clk_period : time := 10 ns;

    -- inputs
    signal E   : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal S : STD_LOGIC;

begin

    uut : entity work.reg_desp_estructural
        port map (
            E   => E,
            S   => S,
            rst => rst,
            clk => clk
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
        E <= '0';

        -- Espera a que termine el reset sincrono.
        wait until falling_edge(rst);
        wait for 1 ns;
        assert (S = '0')
            report "Error: S no quedo en 0 despues del reset" severity error;

        -- Carga en serie la secuencia 1, 0, 1, 1.
        E <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '0')
            report "Error despues de desplazar el primer bit" severity error;

        E <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '0')
            report "Error despues de desplazar el segundo bit" severity error;

        E <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '0')
            report "Error despues de desplazar el tercer bit" severity error;

        E <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '1')
            report "Error: no aparecio el primer bit cargado en S" severity error;

        -- Inserta ceros y comprueba la salida restante: 0, 1, 1.
        E <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '0')
            report "Error: segundo bit desplazado incorrecto" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '1')
            report "Error: tercer bit desplazado incorrecto" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '1')
            report "Error: cuarto bit desplazado incorrecto" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert (S = '0')
            report "Error: el registro no se vacio con ceros" severity error;

        report "Todas las pruebas del registro de desplazamiento pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
