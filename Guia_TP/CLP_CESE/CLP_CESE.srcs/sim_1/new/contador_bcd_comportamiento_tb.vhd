----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:40:15
-- Design Name: 
-- Module Name: contador_bcd_comportamiento_tb - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity contador_bcd_comportamiento_tb is
--  Port ( );
end contador_bcd_comportamiento_tb;

architecture Behavioral of contador_bcd_comportamiento_tb is

    constant clk_period : time := 10 ns;

    -- inputs
    signal ena : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal q : STD_LOGIC_VECTOR(3 downto 0);

begin

    uut : entity work.contador_bcd_comportamiento
        port map (
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
        ena <= '0';

        wait until falling_edge(rst);
        wait for 1 ns;
        assert (q = "0000")
            report "Error: el contador BCD no quedo en cero despues del reset"
            severity error;

        -- Con ena=0 debe conservar el valor.
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = "0000")
            report "Error: el contador BCD cambio con ena=0" severity error;

        -- Comprueba dos vueltas completas de 0 a 9.
        ena <= '1';
        for i in 1 to 20 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert (q = STD_LOGIC_VECTOR(to_unsigned(i mod 10, q'length)))
                report "Error durante la secuencia del contador BCD"
                severity error;
        end loop;

        -- Detiene el contador en cero.
        ena <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = "0000")
            report "Error: el contador BCD no mantuvo el valor" severity error;

        -- Reanuda el conteo desde cero.
        ena <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = "0001")
            report "Error: el contador BCD no reanudo correctamente"
            severity error;

        report "Todas las pruebas del contador BCD por comportamiento pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
