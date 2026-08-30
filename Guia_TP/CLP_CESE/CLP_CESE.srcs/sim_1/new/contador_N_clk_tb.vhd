----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.08.2026 00:13:07
-- Design Name: 
-- Module Name: contador_N_clk_tb - Behavioral
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

entity contador_N_clk_tb is
--  Port ( );
end contador_N_clk_tb;

architecture Behavioral of contador_N_clk_tb is

    constant N          : integer := 5;
    constant clk_period : time := 10 ns;

    -- inputs
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal s : STD_LOGIC;

begin

    uut : entity work.contador_N_clk
        generic map (
            N => N
        )
        port map (
            rst => rst,
            clk => clk,
            s   => s
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
        wait until falling_edge(rst);
        wait for 1 ns;
        assert (s = '0')
            report "Error: s no quedo en cero despues del reset"
            severity error;

        -- Comprueba tres periodos completos de N ciclos.
        for i in 1 to 3*N loop
            wait until rising_edge(clk);
            wait for 1 ns;

            if (i mod N) = (N-1) then
                assert (s = '1')
                    report "Error: falta el pulso de habilitacion"
                    severity error;
            else
                assert (s = '0')
                    report "Error: pulso de habilitacion fuera de tiempo"
                    severity error;
            end if;
        end loop;

        report "Todas las pruebas del generador de habilitacion pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
