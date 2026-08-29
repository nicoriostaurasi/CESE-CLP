----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 22:24:13
-- Design Name: 
-- Module Name: celda_unitaria_contador_binario - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Celda de 1 bit para construir contadores binarios estructurales.
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

entity celda_unitaria_contador_binario is
    Port (
        ena_in  : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        clk     : in  STD_LOGIC;
        q       : out STD_LOGIC;
        ena_out : out STD_LOGIC
    );
end celda_unitaria_contador_binario;

architecture Behavioral of celda_unitaria_contador_binario is

    signal d_aux : STD_LOGIC;
    signal q_aux : STD_LOGIC;

begin

    d_aux   <= q_aux xor ena_in;
    ena_out <= q_aux and ena_in;
    q       <= q_aux;

    ffd_instance : entity work.ffd
        port map (
            d   => d_aux,
            ena => '1',
            rst => rst,
            clk => clk,
            q   => q_aux
        );

end Behavioral;
