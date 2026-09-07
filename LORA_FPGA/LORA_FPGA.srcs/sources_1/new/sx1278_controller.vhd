----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.09.2026 21:59:01
-- Design Name: 
-- Module Name: sx1278_controller - Behavioral
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
use IEEE.NUMERIC_STD.ALL;
use work.sx1278_controller_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sx1278_controller is
    generic (
        MAX_DATA_BYTES : integer := 50;
        CLK_FREQ_HZ    : integer := 100_000_000;
        SPI_FREQ_HZ    : integer := 5_000_000
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- Interfaz de escritura del banco de configuracion.
        -- Cada pulso de config_wr_ena_i registra config_data_i en la
        -- direccion indicada por config_addr_i.
        -- 0: FRF_MSB, 1: FRF_MID, 2: FRF_LSB, 3: BW, 4: CR,
        -- 5: SF, 6: PREAMBLE_MSB, 7: PREAMBLE_LSB, 8: TX_POWER_DBM.
        config_wr_ena_i : in  std_logic;
        config_addr_i   : in  std_logic_vector(4-1 downto 0);
        config_data_i   : in  std_logic_vector(8-1 downto 0);

        -- Comandos de alto nivel. Cada entrada se utilizara como un pulso
        -- de solicitud independiente.
        start_config_i : in std_logic;
        rst_periph_i   : in std_logic;
        tx_data_i      : in std_logic;
        rx_data_i      : in std_logic;

        -- Estado general del controlador.
        busy_o  : out std_logic;
        done_o  : out std_logic;
        error_o : out std_logic;

        -- Interfaz SPI fisica. El SX1278 utiliza modo 0.
        spi_sclk_o : out std_logic;
        spi_mosi_o : out std_logic;
        spi_miso_i : in std_logic;
        spi_nss_o  : out std_logic;

        -- GPIO asociados al SX1278.
        sx1278_dio0_i  : in  std_logic;
        sx1278_reset_o : out std_logic
    );
end sx1278_controller;

architecture Behavioral of sx1278_controller is

    signal frf_msb_reg          : std_logic_vector(8-1 downto 0);
    signal frf_mid_reg          : std_logic_vector(8-1 downto 0);
    signal frf_lsb_reg          : std_logic_vector(8-1 downto 0);
    signal bandwidth_reg        : std_logic_vector(8-1 downto 0);
    signal coding_rate_reg      : std_logic_vector(8-1 downto 0);
    signal spreading_factor_reg : std_logic_vector(8-1 downto 0);
    signal preamble_msb_reg     : std_logic_vector(8-1 downto 0);
    signal preamble_lsb_reg     : std_logic_vector(8-1 downto 0);
    signal tx_power_dbm_reg     : std_logic_vector(8-1 downto 0);

    type t_state is (
        ST_IDLE,
        ST_CONFIG_LOAD_ADDRESS,
        ST_CONFIG_LOAD_DATA,
        ST_CONFIG_START_FRAME,
        ST_CONFIG_WAIT_FRAME,
        ST_CONFIG_DONE
    );

    signal state_now  : t_state;
    signal state_next : t_state;

    -- Secuencia completa de configuracion. Cada posicion contiene un frame
    -- independiente de dos bytes: direccion SPI y dato.
    type t_config_sequence is array (0 to 15-1) of
        std_logic_vector(16-1 downto 0);

    signal config_sequence      : t_config_sequence;
    signal config_step          : unsigned(4-1 downto 0);
    signal frame_byte           : std_logic_vector(8-1 downto 0);
    signal frame_charge_byte    : std_logic;
    signal frame_start_transfer : std_logic;
    signal frame_busy           : std_logic;
    signal frame_done           : std_logic;
    signal frame_rx_empty       : std_logic;
    signal frame_rx_data        : std_logic_vector(8-1 downto 0);
    signal pa_config_value      : std_logic_vector(8-1 downto 0);

begin

    frame_controller : entity work.spi_frame_controller
        generic map (
            RAM_DEPTH   => 4,
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            CPOL        => '0',
            CPHA        => '0',
            IDLE_VALUE  => '0'
        )
        port map (
            clk                => clk,
            rst                => rst,
            byte_i             => frame_byte,
            charge_byte        => frame_charge_byte,
            start_spi_transfer => frame_start_transfer,
            busy               => frame_busy,
            done               => frame_done,
            rx_ram_read        => '0',
            rx_ram_empty       => frame_rx_empty,
            rx_ram_data_o      => frame_rx_data,
            spi_sclk_o         => spi_sclk_o,
            spi_mosi_o         => spi_mosi_o,
            spi_miso_i         => spi_miso_i,
            spi_nss_o          => spi_nss_o
        );

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
                tx_power_dbm_reg<=(others=>'0');
            elsif config_wr_ena_i='1' then
                if config_addr_i=CFG_FRF_MSB then
                    frf_msb_reg<=config_data_i;
                elsif config_addr_i=CFG_FRF_MID then
                    frf_mid_reg<=config_data_i;
                elsif config_addr_i=CFG_FRF_LSB then
                    frf_lsb_reg<=config_data_i;
                elsif config_addr_i=CFG_BANDWIDTH then
                    bandwidth_reg<=config_data_i;
                elsif config_addr_i=CFG_CODING_RATE then
                    coding_rate_reg<=config_data_i;
                elsif config_addr_i=CFG_SPREADING_FACTOR then
                    spreading_factor_reg<=config_data_i;
                elsif config_addr_i=CFG_PREAMBLE_MSB then
                    preamble_msb_reg<=config_data_i;
                elsif config_addr_i=CFG_PREAMBLE_LSB then
                    preamble_lsb_reg<=config_data_i;
                elsif config_addr_i=CFG_TX_POWER_DBM then
                    tx_power_dbm_reg<=config_data_i;
                end if;
            end if;
        end if;
    end process;

    -- Conversion directa de potencia solicitada en dBm al valor de
    -- RegPaConfig para PA_BOOST.
    with tx_power_dbm_reg select
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

    -- Construccion de los 15 frames de configuracion. Los ocho bits altos
    -- contienen la direccion SPI y los ocho bajos contienen el dato.
    config_sequence(0)<=x"81" & x"88";
    config_sequence(1)<=x"81" & x"89";
    config_sequence(2)<=x"86" & frf_msb_reg;
    config_sequence(3)<=x"87" & frf_mid_reg;
    config_sequence(4)<=x"88" & frf_lsb_reg;
    config_sequence(5)<=x"9D" & bandwidth_reg(4-1 downto 0) &
                                  coding_rate_reg(3-1 downto 0) & '0';
    config_sequence(6)<=x"9E" & spreading_factor_reg(4-1 downto 0) & "0100";
    config_sequence(7)<=x"A6" & x"04";
    config_sequence(8)<=x"A0" & preamble_msb_reg;
    config_sequence(9)<=x"A1" & preamble_lsb_reg;
    config_sequence(10)<=x"89" & pa_config_value;
    config_sequence(11)<=x"8C" & x"23";
    config_sequence(12)<=x"8E" & x"00";
    config_sequence(13)<=x"8F" & x"00";
    config_sequence(14)<=x"92" & x"FF";

    state_register : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state_now<=ST_IDLE;
            else
                state_now<=state_next;
            end if;
        end if;
    end process;

    next_state_logic : process(state_now, start_config_i, frame_done, config_step)
    begin
        state_next<=state_now;

        case state_now is
            when ST_IDLE =>
                if start_config_i='1' then
                    state_next<=ST_CONFIG_LOAD_ADDRESS;
                end if;

            when ST_CONFIG_LOAD_ADDRESS =>
                state_next<=ST_CONFIG_LOAD_DATA;

            when ST_CONFIG_LOAD_DATA =>
                state_next<=ST_CONFIG_START_FRAME;

            when ST_CONFIG_START_FRAME =>
                state_next<=ST_CONFIG_WAIT_FRAME;

            when ST_CONFIG_WAIT_FRAME =>
                if frame_done='1' then
                    if config_step=TO_UNSIGNED(14,4) then
                        state_next<=ST_CONFIG_DONE;
                    else
                        state_next<=ST_CONFIG_LOAD_ADDRESS;
                    end if;
                end if;

            when ST_CONFIG_DONE =>
                state_next<=ST_IDLE;
        end case;
    end process;

    config_step_counter : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                config_step<=TO_UNSIGNED(0,4);
            elsif state_now=ST_IDLE then
                config_step<=TO_UNSIGNED(0,4);
            elsif state_now=ST_CONFIG_WAIT_FRAME and frame_done='1' then
                if config_step<TO_UNSIGNED(14,4) then
                    config_step<=config_step+TO_UNSIGNED(1,4);
                end if;
            end if;
        end if;
    end process;

    frame_control : process(state_now, config_step, config_sequence)
    begin
        frame_byte<=(others=>'0');
        frame_charge_byte<='0';
        frame_start_transfer<='0';

        case state_now is
            when ST_CONFIG_LOAD_ADDRESS =>
                frame_byte<=config_sequence(to_integer(config_step))(16-1 downto 8);
                frame_charge_byte<='1';

            when ST_CONFIG_LOAD_DATA =>
                frame_byte<=config_sequence(to_integer(config_step))(8-1 downto 0);
                frame_charge_byte<='1';

            when ST_CONFIG_START_FRAME =>
                frame_start_transfer<='1';

            when others =>
                null;
        end case;
    end process;

    output_logic : process(state_now, rst_periph_i)
    begin
        busy_o<='1';
        done_o<='0';
        error_o<='0';
        sx1278_reset_o<=not rst_periph_i;

        case state_now is
            when ST_IDLE =>
                busy_o<='0';

            when ST_CONFIG_DONE =>
                done_o<='1';

            when others =>
                null;
        end case;
    end process;

end Behavioral;
