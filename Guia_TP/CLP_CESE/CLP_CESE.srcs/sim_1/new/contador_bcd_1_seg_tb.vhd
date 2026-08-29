----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.08.2026 00:32:25
-- Design Name: 
-- Module Name: contador_bcd_1_seg_tb - Behavioral
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

entity contador_bcd_1_seg_tb is
--  Port ( );
end contador_bcd_1_seg_tb;

architecture Behavioral of contador_bcd_1_seg_tb is

    constant SYS_CLK_SIM : integer := 5;
    constant clk_period  : time := 10 ns;

    -- inputs
    signal ena : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal q : STD_LOGIC_VECTOR(3 downto 0);

begin

    uut : entity work.contador_bcd_1_seg
        generic map (
            SYS_CLK => SYS_CLK_SIM
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
        assert (q = "0000")
            report "Error: el contador no quedo en cero despues del reset"
            severity error;

        -- Sin habilitacion general no debe contar.
        for i in 1 to SYS_CLK_SIM loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        assert (q = "0000")
            report "Error: conto con ena=0" severity error;

        -- Cada SYS_CLK_SIM ciclos debe avanzar un digito BCD.
        ena <= '1';
        for valor in 1 to 12 loop
            for ciclo in 1 to SYS_CLK_SIM loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;

            assert (q = STD_LOGIC_VECTOR(to_unsigned(valor mod 10, q'length)))
                report "Error: el contador BCD no avanzo en el instante esperado"
                severity error;
        end loop;

        -- Detiene el valor 2 durante dos periodos completos.
        ena <= '0';
        for ciclo in 1 to 2*SYS_CLK_SIM loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        assert (q = "0010")
            report "Error: el contador no se detuvo con ena=0" severity error;

        -- Al rehabilitarlo debe continuar en 3.
        ena <= '1';
        for ciclo in 1 to SYS_CLK_SIM loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        assert (q = "0011")
            report "Error: el contador no reanudo correctamente" severity error;

        report "Todas las pruebas del contador BCD de un segundo pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
