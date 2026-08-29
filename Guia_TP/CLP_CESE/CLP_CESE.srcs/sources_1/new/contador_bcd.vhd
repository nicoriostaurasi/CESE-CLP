----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:14:29
-- Design Name: 
-- Module Name: contador_bcd - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Contador BCD estructural de un digito con enable y acarreo.
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

entity contador_bcd is
    Port ( ena : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           q   : out STD_LOGIC_VECTOR(4-1 downto 0);
           co  : out STD_LOGIC);
end contador_bcd;

architecture Behavioral of contador_bcd is

    signal d_reg  : STD_LOGIC_VECTOR(3 downto 0);
    signal q_reg  : STD_LOGIC_VECTOR(3 downto 0);
    signal q_inc  : STD_LOGIC_VECTOR(3 downto 0);
    signal igual9 : STD_LOGIC;
    signal co_aux : STD_LOGIC;

begin

    q <= q_reg;
    co <= ena and igual9;

    adder_instance : entity work.adder_4_bits
        port map (
            ci => '0',
            a  => q_reg,
            b  => "0001",
            s  => q_inc,
            co => co_aux
        );

    comparador_instance : entity work.comparador_igual
        generic map (
            N => 4
        )
        port map (
            a     => q_reg,
            b     => "1001",
            igual => igual9
        );

    -- Cuando el valor actual es 9, el siguiente valor debe ser 0.
    mux_bcd : for i in 0 to 3 generate
        mux_instance : entity work.mux_2_a_1
            port map (
                a   => q_inc(i),
                b   => '0',
                sel => igual9,
                mux => d_reg(i)
            );
    end generate mux_bcd;

    registro_instance : entity work.registro_N_bits
        generic map (
            N => 4
        )
        port map (
            d   => d_reg,
            ena => ena,
            rst => rst,
            clk => clk,
            q   => q_reg
        );

end Behavioral;
