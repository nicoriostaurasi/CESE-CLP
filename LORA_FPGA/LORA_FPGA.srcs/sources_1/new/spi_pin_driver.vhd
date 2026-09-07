----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2026 01:33:13
-- Design Name: 
-- Module Name: spi_pin_driver - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Driver SPI full-duplex para transferencias de un byte. Genera
-- SCLK, serializa MOSI, captura MISO y soporta los cuatro modos CPOL/CPHA.
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
use ieee.math_real.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity spi_pin_driver is
    generic (
        CLK_FREQ_HZ : integer := 100000000;
        SPI_FREQ_HZ : integer :=   5000000;
        CPOL        : std_logic := '0';
        CPHA        : std_logic := '0';
        IDLE_VALUE  : std_logic := '1'
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        -- DATA INTERFACE
        tx_byte_i : in  std_logic_vector(8-1 downto 0);
        rx_byte_o : out std_logic_vector(8-1 downto 0);
        -- FLOW CONTROL
        start_i   : in  std_logic;
        busy_o    : out std_logic;
        done_o    : out std_logic;
        -- Phisical PINS
        spi_sclk_o : out std_logic;
        spi_mosi_o : out std_logic;
        spi_miso_i : in  std_logic
    );
end spi_pin_driver;

architecture Behavioral of spi_pin_driver is
    constant DATA_SIZE : integer := 8;
    constant SYS_CLK_BAUD_RATE : integer := CLK_FREQ_HZ/SPI_FREQ_HZ;
    constant N_SPI_DATA_RATE : integer :=
        integer(ceil(log2(real(CLK_FREQ_HZ/SPI_FREQ_HZ))));

    -- Pulsos de temporizacion de mitad y fin del periodo SPI.
    signal tc_spi_data_rate : std_logic;
    signal tc_spi_data_rate_2 : std_logic;
    signal baudrate_counter : unsigned(N_SPI_DATA_RATE-1 downto 0);

    -- Registros serie y contador de bits de la transferencia activa.
    signal tx_reg_data : std_logic_vector(8-1 downto 0);
    signal rx_reg_data : std_logic_vector(8-1 downto 0);
    signal data_counter : unsigned(4-1 downto 0);
    signal mosi_reg : std_logic;
    signal clk_reg : std_logic;

    -- Estado y control interno.
    signal busy_reg : std_logic;
    signal done_reg : std_logic;
    signal enable_main_counter : std_logic;

    -- Eventos derivados de CPHA y datos seleccionados para cada fase.
    signal capture_data : std_logic;
    signal change_data : std_logic;
    signal next_mosi : std_logic;
    signal start_mosi : std_logic;
    signal end_transfer : std_logic;
    signal final_rx_data : std_logic_vector(8-1 downto 0);
begin

    -- CPHA selecciona en cual de los dos flancos se captura MISO y en cual
    -- se prepara el siguiente dato MOSI.
    capture_data <= tc_spi_data_rate_2 when CPHA = '0' else tc_spi_data_rate;
    change_data  <= tc_spi_data_rate   when CPHA = '0' else tc_spi_data_rate_2;
    -- SPI transmite el bit mas significativo primero. Para CPHA=0 el bit 7
    -- queda presentado antes del primer flanco; para CPHA=1 se presenta en
    -- el primer flanco de cambio.
    next_mosi    <= tx_reg_data(6)     when CPHA = '0' else tx_reg_data(7);
    start_mosi   <= tx_byte_i(7)       when CPHA = '0' else IDLE_VALUE;
    end_transfer <= '0' when busy_reg /= '1' else
                    '1' when (CPHA = '0' and data_counter = to_unsigned(DATA_SIZE-1,4)) or
                                  (CPHA = '1' and data_counter = to_unsigned(DATA_SIZE,4))
                    else '0';
    final_rx_data <= rx_reg_data when CPHA = '0'
                     else rx_reg_data(8-2 downto 0) & spi_miso_i;
    
    -- Divide clk en un pulso de mitad de bit y otro de fin de bit.
    spi_data_rate_counter : process(clk)
    begin
        if(rising_edge(clk)) then
            if (rst='1' or start_i='1' or enable_main_counter='0') then
                baudrate_counter<=to_unsigned(0,N_spi_data_rate);
                tc_spi_data_rate<='0';                
                tc_spi_data_rate_2<='0';
            else
                baudrate_counter<=baudrate_counter+1;
                tc_spi_data_rate<='0';
                tc_spi_data_rate_2<='0';
                if(baudrate_counter = (SYS_CLK_BAUD_RATE/2)-1) then
                    tc_spi_data_rate_2<='1';
                end if;
                if(baudrate_counter = (SYS_CLK_BAUD_RATE-1)) then
                    tc_spi_data_rate<='1';
                    baudrate_counter<=to_unsigned(0,N_spi_data_rate);
                end if;                
            end if;        
        end if;        
    end process;

    -- Registros de transmision/recepcion y handshake de un byte.
    serial_data : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                tx_reg_data<=(others=>IDLE_VALUE);
                mosi_reg<=IDLE_VALUE;
                data_counter<=to_unsigned(0,4);
                rx_reg_data<=(others=>'0');
                busy_reg<= '0';
                done_reg<= '0';
                enable_main_counter<='0';
                rx_byte_o<=(others=>'0');
            else
                done_reg<='0';

                if start_i='1' then
                    tx_reg_data<=tx_byte_i;
                    mosi_reg<=start_mosi;
                    data_counter<=to_unsigned(0,4);
                    rx_reg_data<=(others=>'0');
                    busy_reg<= '1';
                    done_reg<= '0';
                    enable_main_counter<='1';
                    rx_byte_o<=(others=>'0');
                end if;

                if change_data='1' then
                    mosi_reg<=next_mosi;
                    tx_reg_data<=tx_reg_data(8-2 downto 0) & IDLE_VALUE;
                    data_counter<=data_counter+1;
                end if;

                if capture_data='1' then
                    rx_reg_data<=rx_reg_data(8-2 downto 0) & spi_miso_i;
                end if;

                -- El byte termina en el trailing edge. De esta manera CPHA=1
                -- conserva el tiempo necesario para capturar el octavo bit.
                if tc_spi_data_rate='1' and end_transfer='1' then
                    done_reg<='1';
                    busy_reg<='0';
                    enable_main_counter<='0';
                    rx_byte_o<=final_rx_data;
                    mosi_reg<=IDLE_VALUE;
                end if;

                
                if enable_main_counter = '0' then
                    done_reg<='0';
                end if;
        
            end if;                
        end if;
    end process;

    -- Registro de SCLK. CPOL determina tanto el reposo como la direccion de
    -- los flancos leading y trailing.
    clk_control : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                clk_reg<=CPOL;

            elsif busy_reg = '0' then
                -- SCLK permanece en la polaridad configurada durante reposo.
                clk_reg<=CPOL;

            elsif tc_spi_data_rate_2 = '1' then
                -- Leading edge: primer flanco del periodo SPI.
                clk_reg<=not CPOL;

            elsif tc_spi_data_rate = '1' then
                -- Trailing edge: regreso al nivel de reposo.
                clk_reg<=CPOL;

            end if;
        end if;
    end process;
    
    spi_sclk_o<= clk_reg;
    spi_mosi_o<= mosi_reg;
    done_o<= done_reg;
    busy_o<= busy_reg;
end Behavioral;
