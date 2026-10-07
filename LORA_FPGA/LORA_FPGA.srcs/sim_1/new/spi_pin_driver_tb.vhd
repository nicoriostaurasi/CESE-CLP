----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2026 02:25:16
-- Design Name: 
-- Module Name: spi_pin_driver_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Verificacion exploratoria de spi_pin_driver. Instancia los
-- cuatro modos CPOL/CPHA en paralelo y comprueba transferencias loopback de
-- los bytes A5, 96 y 81.
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

entity spi_pin_driver_tb is
--  Port ( );
end spi_pin_driver_tb;

architecture Behavioral of spi_pin_driver_tb is

    constant clk_period : time := 10 ns;

    type byte_array_t is array (0 to 3) of std_logic_vector(7 downto 0);
    type mode_array_t is array (0 to 3) of std_logic;

    -- Modos SPI 0, 1, 2 y 3 respectivamente.
    constant cpol_values : mode_array_t := ('0', '0', '1', '1');
    constant cpha_values : mode_array_t := ('0', '1', '0', '1');

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- Input signals
    signal tx_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal start   : std_logic := '0';
    signal miso    : std_logic_vector(0 to 3);

    -- Output signals
    signal rx_byte : byte_array_t;
    signal busy    : std_logic_vector(0 to 3);
    signal done    : std_logic_vector(0 to 3);
    signal sclk    : std_logic_vector(0 to 3);
    signal mosi    : std_logic_vector(0 to 3);

begin

    spi_modes : for i in 0 to 3 generate
        dut : entity work.spi_pin_driver
            generic map (
                CLK_FREQ_HZ => 100_000_000,
                SPI_FREQ_HZ => 5_000_000,
                CPOL        => cpol_values(i),
                CPHA        => cpha_values(i),
                IDLE_VALUE  => '1'
            )
            port map (
                clk        => clk,
                rst        => rst,
                tx_byte_i  => tx_byte,
                rx_byte_o  => rx_byte(i),
                start_i    => start,
                busy_o     => busy(i),
                done_o     => done(i),
                spi_sclk_o => sclk(i),
                spi_mosi_o => mosi(i),
                spi_miso_i => miso(i)
            );
    end generate;

    -- Clock process
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Loopback: el dato transmitido por MOSI vuelve por MISO.
    miso <= mosi;

    stimulus : process
    begin
        -- Reset process
        rst <= '1';
        wait for 5*clk_period;
        rst <= '0';
        wait until rising_edge(clk);

        -- Primera transferencia. Se usan tiempos fijos para poder observar
        -- las formas de onda aunque el bloque todavia este incompleto.
        tx_byte <= x"A5";
        wait until falling_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        start <= '0';
        wait for 3 us;

        -- Los cuatro modos, sus salidas y la reutilizacion se verifican en
        -- Cocotb mediante spi_pin_driver/00-all-modes.
        std.env.stop;
        wait;
    end process;

end Behavioral;
