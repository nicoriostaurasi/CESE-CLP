----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 26.09.2026
-- Design Name:
-- Module Name: sx1278_config_registers - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Banco de registros que conserva los parametros configurables
--              del SX1278 recibidos desde la interfaz de comandos UART.
--
-- Dependencies: sx1278_controller_pkg
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.sx1278_controller_pkg.all;

entity sx1278_config_registers is
    port (
        -- Reloj del banco de registros.
        clk : in std_logic;
        -- Reset sincrono de todos los parametros.
        rst : in std_logic;
        -- Habilitacion de escritura de un parametro.
        wr_ena_i : in std_logic;
        -- Direccion simbolica del parametro seleccionado.
        addr_i : in std_logic_vector(8-1 downto 0);
        -- Valor recibido desde el decodificador UART.
        data_i : in std_logic_vector(8-1 downto 0);
        -- Byte mas significativo de la frecuencia RF codificada.
        frf_msb_o : out std_logic_vector(8-1 downto 0);
        -- Byte intermedio de la frecuencia RF codificada.
        frf_mid_o : out std_logic_vector(8-1 downto 0);
        -- Byte menos significativo de la frecuencia RF codificada.
        frf_lsb_o : out std_logic_vector(8-1 downto 0);
        -- Codigo de ancho de banda LoRa.
        bandwidth_o : out std_logic_vector(8-1 downto 0);
        -- Codigo de tasa de codificacion LoRa.
        coding_rate_o : out std_logic_vector(8-1 downto 0);
        -- Factor de ensanchamiento LoRa.
        spreading_factor_o : out std_logic_vector(8-1 downto 0);
        -- Byte mas significativo de la longitud de preambulo.
        preamble_msb_o : out std_logic_vector(8-1 downto 0);
        -- Byte menos significativo de la longitud de preambulo.
        preamble_lsb_o : out std_logic_vector(8-1 downto 0);
        -- Valor RegPaConfig ya codificado para el SX1278.
        pa_config_o : out std_logic_vector(8-1 downto 0)
    );
end sx1278_config_registers;

architecture Behavioral of sx1278_config_registers is

    signal frf_msb_reg : std_logic_vector(8-1 downto 0);
    signal frf_mid_reg : std_logic_vector(8-1 downto 0);
    signal frf_lsb_reg : std_logic_vector(8-1 downto 0);
    signal bandwidth_reg : std_logic_vector(8-1 downto 0);
    signal coding_rate_reg : std_logic_vector(8-1 downto 0);
    signal spreading_factor_reg : std_logic_vector(8-1 downto 0);
    signal preamble_msb_reg : std_logic_vector(8-1 downto 0);
    signal preamble_lsb_reg : std_logic_vector(8-1 downto 0);
    signal pa_config_reg : std_logic_vector(8-1 downto 0);
    signal pa_config_value : std_logic_vector(8-1 downto 0);

begin

    -- El banco desacopla la recepcion UART de la aplicacion SPI. Cada comando
    -- modifica un parametro y el controlador puede aplicar luego una fotografia
    -- coherente de todos los valores mediante la secuencia CONFIG.
    config_registers : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                frf_msb_reg<=(others=>'0');
                frf_mid_reg<=(others=>'0');
                frf_lsb_reg<=(others=>'0');
                bandwidth_reg<=(others=>'0');
                coding_rate_reg<=(others=>'0');
                spreading_factor_reg<=(others=>'0');
                preamble_msb_reg<=(others=>'0');
                preamble_lsb_reg<=(others=>'0');
                -- PA_BOOST, MaxPower=7 y OutputPower=0 corresponden a 2 dBm.
                pa_config_reg<=x"F0";
            elsif wr_ena_i='1' then
                case addr_i is
                    when CFG_FRF_MSB =>
                        frf_msb_reg<=data_i;
                    when CFG_FRF_MID =>
                        frf_mid_reg<=data_i;
                    when CFG_FRF_LSB =>
                        frf_lsb_reg<=data_i;
                    when CFG_BANDWIDTH =>
                        bandwidth_reg<=data_i;
                    when CFG_CODING_RATE =>
                        coding_rate_reg<=data_i;
                    when CFG_SPREADING_FACTOR =>
                        spreading_factor_reg<=data_i;
                    when CFG_PREAMBLE_MSB =>
                        preamble_msb_reg<=data_i;
                    when CFG_PREAMBLE_LSB =>
                        preamble_lsb_reg<=data_i;
                    when CFG_TX_POWER_DBM =>
                        pa_config_reg<=pa_config_value;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- La interfaz recibe la potencia en dBm. El mux la convierte al formato
    -- PA_BOOST, MaxPower y OutputPower utilizado por RegPaConfig.
    with data_i select
        pa_config_value <= x"F0" when x"02",
                           x"F1" when x"03",
                           x"F2" when x"04",
                           x"F3" when x"05",
                           x"F4" when x"06",
                           x"F5" when x"07",
                           x"F6" when x"08",
                           x"F7" when x"09",
                           x"F8" when x"0A",
                           x"F9" when x"0B",
                           x"FA" when x"0C",
                           x"FB" when x"0D",
                           x"FC" when x"0E",
                           x"FD" when x"0F",
                           x"FE" when x"10",
                           x"FF" when x"11",
                           x"F0" when others;

    frf_msb_o<=frf_msb_reg;
    frf_mid_o<=frf_mid_reg;
    frf_lsb_o<=frf_lsb_reg;
    bandwidth_o<=bandwidth_reg;
    coding_rate_o<=coding_rate_reg;
    spreading_factor_o<=spreading_factor_reg;
    preamble_msb_o<=preamble_msb_reg;
    preamble_lsb_o<=preamble_lsb_reg;
    pa_config_o<=pa_config_reg;

end Behavioral;
