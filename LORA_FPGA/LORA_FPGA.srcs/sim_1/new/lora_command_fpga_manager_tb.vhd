----------------------------------------------------------------------------------
-- Testbench del top lora_command_fpga_manager.
-- Un transmisor UART envia la configuracion completa al top para observar la
-- secuencia resultante sobre NSS, SCLK y MOSI. MISO permanece fijo en cero.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lora_command_fpga_manager_tb is
end lora_command_fpga_manager_tb;

architecture Behavioral of lora_command_fpga_manager_tb is

    -- Mismos valores utilizados en la implementacion sobre la ZYBO.
    constant CLK_FREQ_HZ : integer := 125_000_000;
    constant UART_BAUDRATE : integer := 115_200;
    constant CLK_PERIOD : time := 8 ns;

    constant CMD_CONFIG_WRITE : std_logic_vector(7 downto 0) := x"01";
    constant CMD_CONTROL : std_logic_vector(7 downto 0) := x"02";
    constant CMD_TX_WRITE : std_logic_vector(7 downto 0) := x"03";
    constant CTRL_TX_START : std_logic_vector(7 downto 0) := x"03";
    constant CTRL_APPLY_CONFIG : std_logic_vector(7 downto 0) := x"01";
    constant CTRL_RESET_PERIPH : std_logic_vector(7 downto 0) := x"02";
    constant CTRL_RX_START : std_logic_vector(7 downto 0) := x"04";
    constant CTRL_TX_BEGIN : std_logic_vector(7 downto 0) := x"05";
    constant CFG_SPREADING_FACTOR_ADDR : std_logic_vector(7 downto 0) := x"05";
    constant UART_ACK : std_logic_vector(7 downto 0) := x"06";
    constant UART_NACK : std_logic_vector(7 downto 0) := x"15";
    constant UART_EVENT_RX_PACKET : std_logic_vector(7 downto 0) := x"80";
    constant UART_FRAME_START : std_logic_vector(7 downto 0) := x"23";
    constant UART_FRAME_END : std_logic_vector(7 downto 0) := x"24";

    -- Configuracion utilizada por el script de demostracion: FRF=0x6C4000,
    -- BW=7, CR=1, SF=7, potencia=14 dBm y preambulo de 8 simbolos.
    -- Cada palabra contiene: #, comando, parametro, valor, checksum XOR y $.
    type t_uart_frame_array is array (natural range <>) of
        std_logic_vector(6*8-1 downto 0);
    constant CONFIG_FRAMES : t_uart_frame_array(0 to 10-1) := (
        x"2301006C6D24", -- FRF MSB
        x"230101404024", -- FRF MID
        x"230102000324", -- FRF LSB
        x"230103070524", -- Bandwidth 7
        x"230104010424", -- Coding rate 1
        x"230105070324", -- Spreading factor 7
        x"2301080E0724", -- Potencia 14 dBm
        x"230106000724", -- Preambulo MSB
        x"230107080E24", -- Preambulo LSB
        x"230201000324"  -- Aplicar configuracion
    );

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- UART que representa a la PC.
    signal pc_data_wr : std_logic := '0';
    signal pc_data_tx : std_logic_vector(7 downto 0) := (others=>'0');
    signal pc_tx_ready : std_logic;
    signal pc_uart_tx : std_logic;

    -- Entradas y salidas del top.
    signal spi_sclk : std_logic;
    signal spi_mosi : std_logic;
    signal spi_nss : std_logic;
    signal spi_miso : std_logic := '0';
    signal sx1278_reset : std_logic;
    signal status_led : std_logic_vector(4-1 downto 0);
    signal sx1278_dio0 : std_logic := '0';

begin

    uut : entity work.lora_command_fpga_manager
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => 5_000_000,
            UART_BAUDRATE => UART_BAUDRATE,
            RESET_TIME_MS => 1,
            HEARTBEAT_HALF_PERIOD_MS => 1
        )
        port map (
            clk => clk,
            rst => rst,
            uart_rx_i => pc_uart_tx,
            uart_tx_o => open,
            spi_sclk_o => spi_sclk,
            spi_mosi_o => spi_mosi,
            spi_miso_i => spi_miso,
            spi_nss_o => spi_nss,
            sx1278_dio0_i => sx1278_dio0,
            sx1278_reset_o => sx1278_reset,
            status_led_o => status_led
        );

    -- Transmisor UART: genera los bytes que enviaria la PC.
    pc_uart_transmitter : entity work.uart_tx
        generic map (
            baudRate => UART_BAUDRATE,
            sysClk => CLK_FREQ_HZ,
            dataSize => 8
        )
        port map (
            clk => clk,
            rst => rst,
            dataWr => pc_data_wr,
            dataTx => pc_data_tx,
            ready => pc_tx_ready,
            tx => pc_uart_tx
        );

    clk_process : process
    begin
        clk<='0';
        wait for CLK_PERIOD/2;
        clk<='1';
        wait for CLK_PERIOD/2;
    end process;

    reset_process : process
    begin
        rst<='1';
        wait for 10*CLK_PERIOD;
        rst<='0';
        wait;
    end process;

    stimulus : process
    begin
        wait until falling_edge(rst);
        wait for 5*CLK_PERIOD;

        -- Carga todos los registros de configuracion y finalmente solicita que
        -- el controlador genere la secuencia SPI correspondiente.
        for frame_index in CONFIG_FRAMES'range loop
            for byte_index in 0 to 6-1 loop
                pc_data_tx<=CONFIG_FRAMES(frame_index)(6*8-1-byte_index*8 downto
                                                       5*8-byte_index*8);
                pc_data_wr<='1';
                wait until rising_edge(clk);
                pc_data_wr<='0';
                wait until rising_edge(pc_tx_ready);
            end loop;

            -- Separacion suficiente para que la respuesta del top termine sin
            -- superponerse con el siguiente comando de configuracion.
            wait for 600 us;
        end loop;

        -- Tiempo de gracia para observar la secuencia SPI completa.
        wait for 1 ms;
        std.env.stop;
        wait;
    end process;

end Behavioral;
