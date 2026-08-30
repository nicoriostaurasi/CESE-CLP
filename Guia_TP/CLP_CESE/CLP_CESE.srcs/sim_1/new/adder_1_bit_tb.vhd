----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 19:27:30
-- Design Name: 
-- Module Name: adder_1_bit_tb - Behavioral
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

entity adder_1_bit_tb is
--  Port ( );
end adder_1_bit_tb;

architecture Behavioral of adder_1_bit_tb is
    component adder_1_bit is
        Port(  ci : in STD_LOGIC;
                a : in STD_LOGIC;
                b : in STD_LOGIC;
                s : out STD_LOGIC;
               co : out STD_LOGIC);
    end component;
    
    -- inputs
    signal ci: STD_LOGIC;
    signal  a: STD_LOGIC;
    signal  b: STD_LOGIC;
    
    -- outputs
    signal  s: STD_LOGIC;
    signal co: STD_LOGIC;
    
begin
    
    uut: adder_1_bit
    port map( ci=>ci,
               a=>a,
               b=>b,
               s=>s,
              co=>co);
    
    stimProc: process
    begin
        a <= '0'; b <= '0'; ci <= '0';
        wait for 10 ns;
        assert (co = '0' and s = '0') report "Error: a=0, b=0, ci=0" severity error;

        a <= '0'; b <= '0'; ci <= '1';
        wait for 10 ns;
        assert (co = '0' and s = '1') report "Error: a=0, b=0, ci=1" severity error;

        a <= '0'; b <= '1'; ci <= '0';
        wait for 10 ns;
        assert (co = '0' and s = '1') report "Error: a=0, b=1, ci=0" severity error;

        a <= '0'; b <= '1'; ci <= '1';
        wait for 10 ns;
        assert (co = '1' and s = '0') report "Error: a=0, b=1, ci=1" severity error;

        a <= '1'; b <= '0'; ci <= '0';
        wait for 10 ns;
        assert (co = '0' and s = '1') report "Error: a=1, b=0, ci=0" severity error;

        a <= '1'; b <= '0'; ci <= '1';
        wait for 10 ns;
        assert (co = '1' and s = '0') report "Error: a=1, b=0, ci=1" severity error;

        a <= '1'; b <= '1'; ci <= '0';
        wait for 10 ns;
        assert (co = '1' and s = '0') report "Error: a=1, b=1, ci=0" severity error;

        a <= '1'; b <= '1'; ci <= '1';
        wait for 10 ns;
        assert (co = '1' and s = '1') report "Error: a=1, b=1, ci=1" severity error;

        report "Todas las combinaciones pasaron correctamente" severity note;
        wait;
    end process;    
    

end Behavioral;
