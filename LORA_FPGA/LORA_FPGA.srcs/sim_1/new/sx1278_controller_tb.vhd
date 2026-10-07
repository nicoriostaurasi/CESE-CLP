----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.09.2026 20:14:43
-- Design Name: 
-- Module Name: sx1278_controller_tb - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sx1278_controller_tb is
--  Port ( );
end sx1278_controller_tb;

architecture Behavioral of sx1278_controller_tb is

    constant clk_period : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- Input signals
    signal config_wr_ena_i : std_logic := '0';
    signal config_addr_i   : std_logic_vector(8-1 downto 0) := (others=>'0');
    signal config_data_i   : std_logic_vector(8-1 downto 0) := (others=>'0');
    signal config_start_i  : std_logic := '0';
    signal peripheral_reset_request_i : std_logic := '0';
    signal tx_begin_i : std_logic := '0';
    signal tx_start_i      : std_logic := '0';
    signal tx_data_i       : std_logic_vector(7 downto 0) := (others=>'0');
    signal tx_data_valid_i : std_logic := '0';
    signal rx_data_i       : std_logic := '0';
    signal spi_miso_i      : std_logic := '0';
    signal sx1278_dio0_i   : std_logic := '0';

    -- Output signals
    signal busy_o          : std_logic;
    signal done_o          : std_logic;
    signal error_o         : std_logic;
    signal spi_sclk_o      : std_logic;
    signal spi_mosi_o      : std_logic;
    signal spi_nss_o       : std_logic;
    signal sx1278_reset_o  : std_logic;

    signal checked_frames : integer range 0 to 15 := 0;
    signal tx_command_sent : std_logic := '0';

    type t_expected_frames is array (0 to 15-1) of
        std_logic_vector(16-1 downto 0);

    constant EXPECTED_FRAMES : t_expected_frames := (
        x"8188", x"8189", x"866C", x"8740", x"8800",
        x"9D72", x"9E74", x"A604", x"A000", x"A108",
        x"89FC", x"8C23", x"8E00", x"8F00", x"92FF"
    );

begin

    dut : entity work.sx1278_controller
        generic map (
            MAX_DATA_BYTES => 50,
            CLK_FREQ_HZ     => 100_000_000,
            SPI_FREQ_HZ     => 10_000_000
        )
        port map (
            clk               => clk,
            rst               => rst,
            config_wr_ena_i   => config_wr_ena_i,
            config_addr_i     => config_addr_i,
            config_data_i     => config_data_i,
            config_start_i    => config_start_i,
            tx_start_i        => tx_start_i,
            peripheral_reset_request_i => peripheral_reset_request_i,
            tx_begin_i => tx_begin_i,
            tx_data_i         => tx_data_i,
            tx_data_valid_i   => tx_data_valid_i,
            rx_start_i        => '0',
            rx_read_index_i   => (others=>'0'),
            rx_data_o         => open,
            rx_length_o       => open,
            rx_valid_o        => open,
            rx_packet_pending_o => open,
            rx_stream_index_i => (others=>'0'),
            rx_stream_data_o  => open,
            rx_packet_sent_i  => '0',
            busy_o            => busy_o,
            done_o            => done_o,
            error_o           => error_o,
            spi_sclk_o        => spi_sclk_o,
            spi_mosi_o        => spi_mosi_o,
            spi_miso_i        => spi_miso_i,
            spi_nss_o         => spi_nss_o,
            sx1278_dio0_i     => sx1278_dio0_i,
            sx1278_reset_o    => sx1278_reset_o,
            peripheral_reset_active_o => open
        );

    -- Clock process
    clk_process : process
    begin
        clk<='0';
        wait for clk_period/2;
        clk<='1';
        wait for clk_period/2;
    end process;

    -- Reset process
    reset_process : process
    begin
        rst<='1';
        wait for 5*clk_period;
        rst<='0';
        wait;
    end process;

    stimulus : process
    begin
        wait until falling_edge(rst);

        -- Smoke test: escritura directa de un registro y comienzo de CONFIG.
        wait until falling_edge(clk);
        config_addr_i<=CFG_SPREADING_FACTOR;
        config_data_i<=x"07";
        config_wr_ena_i<='1';
        wait until falling_edge(clk);
        config_wr_ena_i<='0';
        config_start_i<='1';
        wait until falling_edge(clk);
        config_start_i<='0';
        wait for 50 us;
        std.env.stop;
        wait;
    end process;


end Behavioral;
