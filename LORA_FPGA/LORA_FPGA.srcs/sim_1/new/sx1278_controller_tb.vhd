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

    -- Verifica la secuencia TX y, en particular, que direccion FIFO y los
    -- tres bytes de payload se transmitan dentro de una unica ventana NSS.
    tx_spi_monitor : process
        procedure check_spi_frame(
            constant expected_frame : std_logic_vector
        ) is
            variable received_frame : std_logic_vector(expected_frame'range);
        begin
            wait until falling_edge(spi_nss_o);

            for bit_index in expected_frame'range loop
                wait until rising_edge(spi_sclk_o);
                received_frame(bit_index):=spi_mosi_o;
            end loop;

            wait until rising_edge(spi_nss_o);
            assert received_frame=expected_frame
                report "Frame SPI de transmision incorrecto"
                severity error;
        end procedure;
    begin
        wait until checked_frames=15;
        check_spi_frame(x"8189");
        report "TX_BEGIN: STDBY verificado" severity note;
        check_spi_frame(x"8D00");
        report "TX_BEGIN: puntero FIFO verificado" severity note;
        check_spi_frame(x"80A5");
        report "TX_WRITE: A5 verificado" severity note;
        check_spi_frame(x"8096");
        report "TX_WRITE: 96 verificado" severity note;
        check_spi_frame(x"8081");
        report "TX_WRITE: 81 verificado" severity note;
        check_spi_frame(x"A203");
        report "TX_START: longitud verificada" severity note;
        check_spi_frame(x"92FF");
        report "TX_START: IRQ limpiadas" severity note;
        check_spi_frame(x"C040");
        report "TX_START: DIO0 configurado" severity note;
        check_spi_frame(x"818B");
        report "TX_START: modo TX verificado" severity note;
        tx_command_sent<='1';
        check_spi_frame(x"9208");
        wait;
    end process;

    -- Reset process
    reset_process : process
    begin
        rst<='1';
        wait for 5*clk_period;
        rst<='0';
        wait;
    end process;

    -- Captura MOSI en el flanco ascendente de SCLK (SPI modo 0) y verifica
    -- que cada par direccion/dato tenga su propia ventana de NSS.
    spi_monitor : process
        variable received_frame : std_logic_vector(16-1 downto 0);
    begin
        for frame_index in EXPECTED_FRAMES'range loop
            wait until falling_edge(spi_nss_o);

            for bit_index in 16-1 downto 0 loop
                wait until rising_edge(spi_sclk_o);
                received_frame(bit_index):=spi_mosi_o;
            end loop;

            wait until rising_edge(spi_nss_o);

            assert received_frame=EXPECTED_FRAMES(frame_index)
                report "Frame SPI de configuracion incorrecto. Indice=" &
                       integer'image(frame_index)
                severity error;

            checked_frames<=frame_index+1;
        end loop;

        wait;
    end process;

    stimulus : process
        procedure write_config_register(
            constant address_value : std_logic_vector(4-1 downto 0);
            constant data_value    : std_logic_vector(8-1 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            config_addr_i<=address_value;
            config_data_i<=data_value;
            config_wr_ena_i<='1';

            wait until falling_edge(clk);
            config_wr_ena_i<='0';
        end procedure;

        procedure send_tx_byte(
            constant data_value : std_logic_vector(8-1 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            tx_data_i<=data_value;
            tx_data_valid_i<='1';
            wait until falling_edge(clk);
            tx_data_valid_i<='0';
            wait until done_o='1' for 20 us;
            assert done_o='1'
                report "La escritura del byte en la FIFO no finalizo"
                severity error;
            wait until falling_edge(clk);
        end procedure;
    begin
        wait until falling_edge(rst);

        -- FRF=0x6C4000: 433 MHz con cristal de 32 MHz.
        write_config_register(CFG_FRF_MSB, x"6C");
        write_config_register(CFG_FRF_MID, x"40");
        write_config_register(CFG_FRF_LSB, x"00");

        -- BW=7 (125 kHz), CR=1 (4/5), SF=7.
        write_config_register(CFG_BANDWIDTH, x"07");
        write_config_register(CFG_CODING_RATE, x"01");
        write_config_register(CFG_SPREADING_FACTOR, x"07");

        -- Preambulo de 8 simbolos y potencia de 14 dBm.
        write_config_register(CFG_PREAMBLE_MSB, x"00");
        write_config_register(CFG_PREAMBLE_LSB, x"08");
        write_config_register(CFG_TX_POWER_DBM, x"0E");

        wait until falling_edge(clk);
        config_start_i<='1';
        wait until falling_edge(clk);
        config_start_i<='0';

        wait until busy_o='1' for 1 us;
        assert busy_o='1'
            report "El controlador no activo busy_o"
            severity error;

        wait until done_o='1' for 100 us;
        assert done_o='1'
            report "La secuencia de configuracion no finalizo"
            severity error;

        wait for clk_period;
        assert checked_frames=15
            report "No se transmitieron los 15 frames de configuracion"
            severity error;
        assert error_o='0'
            report "error_o se activo durante la configuracion"
            severity error;

        wait until falling_edge(clk);
        assert busy_o='0'
            report "busy_o no volvio a cero"
            severity error;
        assert done_o='0'
            report "done_o debe durar un unico ciclo"
            severity error;

        -- Abre un payload nuevo; el manager reinicia su puntero interno.
        tx_begin_i<='1';
        wait until falling_edge(clk);
        tx_begin_i<='0';

        -- Cada byte se escribe mediante una trama SPI independiente.
        send_tx_byte(x"A5");
        send_tx_byte(x"96");
        send_tx_byte(x"81");

        wait until busy_o='0';
        wait until falling_edge(clk);
        tx_start_i<='1';
        wait until falling_edge(clk);
        tx_start_i<='0';

        wait until tx_command_sent='1' for 30 us;
        assert tx_command_sent='1'
            report "No se transmitio el comando TX"
            severity error;

        -- DIO0 representa TxDone en la configuracion utilizada.
        wait until falling_edge(clk);
        sx1278_dio0_i<='1';

        wait until done_o='1' for 10 us;
        assert done_o='1'
            report "La secuencia TX no finalizo"
            severity error;
        sx1278_dio0_i<='0';

        report "Fin de las pruebas CONFIG y TX del SX1278"
            severity note;
        wait;
    end process;


end Behavioral;
