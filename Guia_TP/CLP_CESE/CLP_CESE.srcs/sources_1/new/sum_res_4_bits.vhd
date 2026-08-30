----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 20:18:12
-- Design Name: 
-- Module Name: sum_res_4_bits - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Sumador/restador de 4 bits controlado por la entrada sr.
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

entity sum_res_4_bits is
    Port ( sr : in STD_LOGIC;
            a : in STD_LOGIC_VECTOR(4-1 downto 0);
            b : in STD_LOGIC_VECTOR(4-1 downto 0);
            s : out STD_LOGIC_VECTOR(4-1 downto 0);
           co : out STD_LOGIC);
end sum_res_4_bits;

architecture Behavioral of sum_res_4_bits is

    signal b_sum_res  : STD_LOGIC_VECTOR(3 downto 0);
    signal ci_sum_res : STD_LOGIC;

begin
    -- Funciona como CA2 cuando SR = 1, es decir, cuando se quiere restar. 
    -- Cuando SR = 0, funciona como suma.
    b_sum_res  <= b when sr = '0' else not(b);
    ci_sum_res <= sr;

    adder_4_bits_instance : entity work.adder_4_bits
        port map (
            ci => ci_sum_res,
            a  => a,
            b  => b_sum_res,
            s  => s,
            co => co
        );

end Behavioral;
