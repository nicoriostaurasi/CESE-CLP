----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:56:18
-- Design Name: 
-- Module Name: contador_bcd_4_digitos_tb - Behavioral
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

entity contador_bcd_4_digitos_tb is
--  Port ( );
end contador_bcd_4_digitos_tb;

architecture Behavioral of contador_bcd_4_digitos_tb is

    constant clk_period : time := 10 ns;

    -- inputs
    signal ena : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal clk : STD_LOGIC := '0';

    -- outputs
    signal bcd0 : STD_LOGIC_VECTOR(3 downto 0);
    signal bcd1 : STD_LOGIC_VECTOR(3 downto 0);
    signal bcd2 : STD_LOGIC_VECTOR(3 downto 0);
    signal bcd3 : STD_LOGIC_VECTOR(3 downto 0);
    signal co   : STD_LOGIC;

begin

    uut : entity work.contador_bcd_4_digitos
        port map (
            ena  => ena,
            rst  => rst,
            clk  => clk,
            bcd0 => bcd0,
            bcd1 => bcd1,
            bcd2 => bcd2,
            bcd3 => bcd3,
            co   => co
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
        variable esperado : integer;
    begin
        ena <= '0';

        wait until falling_edge(rst);
        wait for 1 ns;
        assert (bcd3 = "0000" and bcd2 = "0000" and
                bcd1 = "0000" and bcd0 = "0000")
            report "Error: el contador no quedo en 0000 despues del reset"
            severity error;

        -- Con ena=0 debe conservar 0000.
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (bcd3 = "0000" and bcd2 = "0000" and
                bcd1 = "0000" and bcd0 = "0000")
            report "Error: el contador cambio con ena=0" severity error;

        -- Cuenta hasta 1000 para comprobar el acarreo a los cuatro digitos.
        ena <= '1';
        for i in 1 to 1000 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            esperado := i;

            assert (bcd0 = STD_LOGIC_VECTOR(to_unsigned(esperado mod 10, 4)) and
                    bcd1 = STD_LOGIC_VECTOR(to_unsigned((esperado / 10) mod 10, 4)) and
                    bcd2 = STD_LOGIC_VECTOR(to_unsigned((esperado / 100) mod 10, 4)) and
                    bcd3 = STD_LOGIC_VECTOR(to_unsigned((esperado / 1000) mod 10, 4)))
                report "Error durante la secuencia del contador BCD de 4 digitos"
                severity error;

            assert (co = '0')
                report "Error: co se activo antes de 9999" severity error;
        end loop;

        -- Al deshabilitarlo debe quedar detenido en 1000.
        ena <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert (bcd3 = "0001" and bcd2 = "0000" and
                bcd1 = "0000" and bcd0 = "0000")
            report "Error: no mantuvo 1000 con ena=0" severity error;

        report "Todas las pruebas del contador BCD de 4 digitos pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
