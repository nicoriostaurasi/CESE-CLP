----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.08.2026 21:52:05
-- Design Name: 
-- Module Name: barrel_shifter_mux - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Barrel shifter de 8 bits implementado con multiplexores de 2 a 1.
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

entity barrel_shifter_mux is
    Port (
        a   : in  STD_LOGIC_VECTOR(8-1 downto 0);
        des : in  STD_LOGIC_VECTOR(3-1 downto 0);
        s   : out STD_LOGIC_VECTOR(8-1 downto 0)
    );
end barrel_shifter_mux;

architecture Behavioral of barrel_shifter_mux is

    signal etapa_1 : STD_LOGIC_VECTOR(8-1 downto 0);
    signal etapa_2 : STD_LOGIC_VECTOR(8-1 downto 0);
    signal etapa_3 : STD_LOGIC_VECTOR(8-1 downto 0);

    signal desp_1 : STD_LOGIC_VECTOR(8-1 downto 0);
    signal desp_2 : STD_LOGIC_VECTOR(8-1 downto 0);
    signal desp_4 : STD_LOGIC_VECTOR(8-1 downto 0);

begin

    -- Desplazamientos fijos armados mediante concatenacion.
    desp_1 <= '0' & a(8-1 downto 1);
    desp_2 <= "00" & etapa_1(8-1 downto 2);
    desp_4 <= "0000" & etapa_2(8-1 downto 4);

    -- Primera etapa: desplaza 0 o 1 posicion.
    mux_desp_1 : for i in 0 to 7 generate
        mux_instance : entity work.mux_2_a_1
            port map (
                a   => a(i),
                b   => desp_1(i),
                sel => des(0),
                mux => etapa_1(i)
            );
    end generate mux_desp_1;

    -- Segunda etapa: desplaza 0 o 2 posiciones.
    mux_desp_2 : for i in 0 to 7 generate
        mux_instance : entity work.mux_2_a_1
            port map (
                a   => etapa_1(i),
                b   => desp_2(i),
                sel => des(1),
                mux => etapa_2(i)
            );
    end generate mux_desp_2;

    -- Tercera etapa: desplaza 0 o 4 posiciones.
    mux_desp_4 : for i in 0 to 7 generate
        mux_instance : entity work.mux_2_a_1
            port map (
                a   => etapa_2(i),
                b   => desp_4(i),
                sel => des(2),
                mux => etapa_3(i)
            );
    end generate mux_desp_4;
    s <= etapa_3;

end Behavioral;
