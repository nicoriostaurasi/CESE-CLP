library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity lora_top_verification_wrapper is
    generic (
        CLK_FREQ_HZ : integer := 1_000_000;
        SPI_FREQ_HZ : integer := 100_000;
        UART_BAUDRATE : integer := 100_000;
        MAX_DATA_BYTES : integer := 50
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        dataWr : in std_logic;
        dataTx : in std_logic_vector(8-1 downto 0);
        ready : out std_logic;
        dataRd : out std_logic;
        dataRx : out std_logic_vector(8-1 downto 0);

        spi_sclk_o : out std_logic;
        spi_mosi_o : out std_logic;
        spi_miso_i : in std_logic;
        spi_nss_o : out std_logic;
        sx1278_dio0_i : in std_logic;
        sx1278_reset_o : out std_logic;
        status_led_o : out std_logic_vector(4-1 downto 0)
    );
end lora_top_verification_wrapper;

architecture Behavioral of lora_top_verification_wrapper is
    signal pc_tx : std_logic;
    signal pc_rx : std_logic;
begin
    pc_uart_tx : entity work.uart_tx
        generic map (
            baudRate => UART_BAUDRATE,
            sysClk => CLK_FREQ_HZ,
            dataSize => 8
        )
        port map (
            clk => clk,
            rst => rst,
            dataWr => dataWr,
            dataTx => dataTx,
            ready => ready,
            tx => pc_tx
        );

    pc_uart_rx : entity work.uart_rx
        generic map (
            baudRate => UART_BAUDRATE,
            sysClk => CLK_FREQ_HZ,
            dataSize => 8
        )
        port map (
            clk => clk,
            rst => rst,
            dataRd => dataRd,
            dataRx => dataRx,
            rx => pc_rx
        );

    dut : entity work.lora_command_fpga_manager
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            UART_BAUDRATE => UART_BAUDRATE,
            RESET_TIME_MS => 1,
            HEARTBEAT_HALF_PERIOD_MS => 2,
            UART_ACTIVITY_TIME_MS => 1,
            MAX_DATA_BYTES => MAX_DATA_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            uart_rx_i => pc_tx,
            uart_tx_o => pc_rx,
            spi_sclk_o => spi_sclk_o,
            spi_mosi_o => spi_mosi_o,
            spi_miso_i => spi_miso_i,
            spi_nss_o => spi_nss_o,
            sx1278_dio0_i => sx1278_dio0_i,
            sx1278_reset_o => sx1278_reset_o,
            status_led_o => status_led_o
        );
end Behavioral;

