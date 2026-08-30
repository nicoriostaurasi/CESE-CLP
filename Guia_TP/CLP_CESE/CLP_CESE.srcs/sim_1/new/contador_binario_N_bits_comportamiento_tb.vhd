----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:04:48
-- Design Name: 
-- Module Name: contador_binario_N_bits_comportamiento_tb - Behavioral
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

entity contador_binario_N_bits_comportamiento_tb is
--  Port ( );
end contador_binario_N_bits_comportamiento_tb;

architecture Behavioral of contador_binario_N_bits_comportamiento_tb is

    constant N          : integer := 5;
    constant clk_period : time := 10 ns;

    -- inputs
    signal ena : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal q : STD_LOGIC_VECTOR(N-1 downto 0);

begin

    uut : entity work.contador_binario_N_bits_comportamiento
        generic map (
            N => N
        )
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
        assert (q = STD_LOGIC_VECTOR(to_unsigned(0, N)))
            report "Error: el contador no quedo en cero despues del reset"
            severity error;

        -- Con ena=0 debe conservar el valor.
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = STD_LOGIC_VECTOR(to_unsigned(0, N)))
            report "Error: el contador cambio con ena=0" severity error;

        -- Recorre los 2**N estados y comprueba el rollover.
        ena <= '1';
        for i in 1 to 2**N loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert (q = STD_LOGIC_VECTOR(to_unsigned(i mod (2**N), N)))
                report "Error durante la secuencia del contador generico"
                severity error;
        end loop;

        -- Luego del rollover debe permanecer detenido en cero.
        ena <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = STD_LOGIC_VECTOR(to_unsigned(0, N)))
            report "Error: no mantuvo el valor con ena=0" severity error;

        -- Al reanudar debe avanzar a uno.
        ena <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (q = STD_LOGIC_VECTOR(to_unsigned(1, N)))
            report "Error: no reanudo el conteo correctamente" severity error;

        report "Todas las pruebas del contador generico por comportamiento pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
