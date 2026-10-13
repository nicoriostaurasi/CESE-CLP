----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2026 01:31:09
-- Design Name: 
-- Module Name: block_ram - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Memoria sincrona de doble puerto simple. Permite una escritura
-- y una lectura por ciclo. El dato leido queda registrado en rd_data_o.
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

entity block_ram is
    generic (
        DATA_WIDTH : integer := 8;
        DEPTH      : integer := 512
    );
    port (
        -- Reloj sincrono de lectura y escritura.
        clk : in std_logic;
        -- Reset sincrono de la memoria y del registro de salida.
        rst : in std_logic;
        -- Puerto de escritura
        -- Habilita la escritura durante el flanco ascendente.
        wr_en_i   : in std_logic;
        -- Direccion donde se almacena wr_data_i.
        wr_addr_i : in integer range 0 to DEPTH-1;
        -- Dato que se escribe en la memoria.
        wr_data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);

        -- Puerto de lectura
        -- Direccion presentada al puerto de lectura sincrono.
        rd_addr_i : in  integer range 0 to DEPTH-1;
        -- Dato registrado obtenido de rd_addr_i.
        rd_data_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end block_ram;

architecture Behavioral of block_ram is
    type ram_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_t;
begin
    -- Reset sincrono. El borrado completo facilita la simulacion, aunque para
    -- inferir una Block RAM fisica puede convenir resetear solo rd_data_o y
    -- administrar la validez del contenido mediante punteros externos.
    ram_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                ram <= (others => (others => '0'));
                rd_data_o <= (others => '0');
            else
                if wr_en_i = '1' then
                    ram(wr_addr_i) <= wr_data_i;
                end if;
    
                rd_data_o <= ram(rd_addr_i);
            end if;
        end if;
    end process;
end Behavioral;
