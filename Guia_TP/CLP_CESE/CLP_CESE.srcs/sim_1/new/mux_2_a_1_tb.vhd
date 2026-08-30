----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:37:14
-- Design Name: 
-- Module Name: mux_2_a_1_tb - Behavioral
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

entity mux_2_a_1_tb is
--  Port ( );
end mux_2_a_1_tb;

architecture Behavioral of mux_2_a_1_tb is

    -- inputs
    signal a   : STD_LOGIC;
    signal b   : STD_LOGIC;
    signal sel : STD_LOGIC;

    -- outputs
    signal mux : STD_LOGIC;

begin

    uut : entity work.mux_2_a_1
        port map (
            a   => a,
            b   => b,
            sel => sel,
            mux => mux
        );

    stim_proc : process
    begin
        -- sel = 0: la salida debe ser a
        a <= '0'; b <= '0'; sel <= '0';
        wait for 10 ns;
        assert (mux = '0')
            report "Error: a=0, b=0, sel=0" severity error;

        a <= '0'; b <= '1'; sel <= '0';
        wait for 10 ns;
        assert (mux = '0')
            report "Error: a=0, b=1, sel=0" severity error;

        a <= '1'; b <= '0'; sel <= '0';
        wait for 10 ns;
        assert (mux = '1')
            report "Error: a=1, b=0, sel=0" severity error;

        a <= '1'; b <= '1'; sel <= '0';
        wait for 10 ns;
        assert (mux = '1')
            report "Error: a=1, b=1, sel=0" severity error;

        -- sel = 1: la salida debe ser b
        a <= '0'; b <= '0'; sel <= '1';
        wait for 10 ns;
        assert (mux = '0')
            report "Error: a=0, b=0, sel=1" severity error;

        a <= '0'; b <= '1'; sel <= '1';
        wait for 10 ns;
        assert (mux = '1')
            report "Error: a=0, b=1, sel=1" severity error;

        a <= '1'; b <= '0'; sel <= '1';
        wait for 10 ns;
        assert (mux = '0')
            report "Error: a=1, b=0, sel=1" severity error;

        a <= '1'; b <= '1'; sel <= '1';
        wait for 10 ns;
        assert (mux = '1')
            report "Error: a=1, b=1, sel=1" severity error;

        report "Las 8 combinaciones del multiplexor pasaron correctamente"
            severity note;

        wait;
    end process;

end Behavioral;
