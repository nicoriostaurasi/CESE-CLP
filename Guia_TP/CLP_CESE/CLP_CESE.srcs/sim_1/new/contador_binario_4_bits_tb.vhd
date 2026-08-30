----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 22:25:30
-- Design Name: 
-- Module Name: contador_binario_4_bits_tb - Behavioral
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

entity contador_binario_4_bits_tb is
--  Port ( );
end contador_binario_4_bits_tb;

architecture Behavioral of contador_binario_4_bits_tb is

    constant clk_period : time := 10 ns;

    -- inputs
    signal ena : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal q : STD_LOGIC_VECTOR(3 downto 0);

begin

    uut : entity work.contador_binario_4_bits
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
            report "Error: el contador no quedo en cero despues del reset"
            severity error;

        -- Con ena=0 el contador debe conservar su valor.
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = "0000")
            report "Error: el contador cambio con ena=0" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = "0000")
            report "Error: el contador cambio con ena=0" severity error;

        -- Recorre los 16 estados y comprueba el retorno de 15 a 0.
        ena <= '1';
        for i in 1 to 16 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert (q = STD_LOGIC_VECTOR(to_unsigned(i mod 16, q'length)))
                report "Error durante la secuencia de conteo"
                severity error;
        end loop;

        -- Vuelve a deshabilitarlo y comprueba que permanezca en cero.
        ena <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = "0000")
            report "Error: no mantuvo el valor luego del conteo" severity error;

        -- Al habilitarlo nuevamente debe continuar desde el valor retenido.
        ena <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = "0001")
            report "Error: no reanudo el conteo correctamente" severity error;

        report "Todas las pruebas del contador binario pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
