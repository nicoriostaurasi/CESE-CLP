----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 23:39:21
-- Design Name: 
-- Module Name: contador_bcd_comportamiento - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Contador BCD de un digito descripto por comportamiento.
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

entity contador_bcd_comportamiento is
    Port (
        ena : in  STD_LOGIC;
        rst : in  STD_LOGIC;
        clk : in  STD_LOGIC;
        q   : out STD_LOGIC_VECTOR(4-1 downto 0)
    );
end contador_bcd_comportamiento;

architecture Behavioral of contador_bcd_comportamiento is

    signal q_now  : STD_LOGIC_VECTOR(4-1 downto 0);
    signal q_inc  : STD_LOGIC_VECTOR(4-1 downto 0);
    signal d_next : STD_LOGIC_VECTOR(4-1 downto 0);
    signal igual9 : STD_LOGIC;

begin

    -- Incrementador combinacional.
    q_inc <= STD_LOGIC_VECTOR(unsigned(q_now) + to_unsigned(1, 4));

    -- Comparador combinacional con el valor BCD 9.
    igual9 <= '1' when q_now = "1001" else '0';

    -- MUX: despues del 9 carga cero; en otro caso carga Q + 1.
    d_next <= "0000" when igual9 = '1' else q_inc;

    -- Registro de estado con reset sincrono.
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                q_now <= (others => '0');
            elsif ena = '1' then
                q_now <= d_next;
            end if;
        end if;
    end process;

    q <= q_now;

end Behavioral;
