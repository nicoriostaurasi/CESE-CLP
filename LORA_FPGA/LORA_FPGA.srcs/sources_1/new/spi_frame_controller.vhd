----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2026 19:55:02
-- Design Name: 
-- Module Name: spi_frame_controller - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Controlador de tramas SPI con memorias TX/RX. Los bytes se
-- cargan en la RAM TX antes de iniciar la transaccion. Durante la transaccion
-- mantiene NSS activo, encadena transferencias de un byte y almacena la
-- respuesta recibida en la RAM RX.
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
use IEEE.MATH_REAL.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity spi_frame_controller is
generic (
    RAM_DEPTH  : integer := 512;
    CLK_FREQ_HZ : integer := 100_000_000;
    SPI_FREQ_HZ : integer := 5_000_000;
    INTER_FRAME_DELAY_US : integer := 1;
    CPOL         : std_logic := '0';
    CPHA         : std_logic := '0';
    IDLE_VALUE   : std_logic := '1'
);
port (
    -- Reloj principal.
    clk : in std_logic;
    -- Reset sincrono de memorias, punteros y control.
    rst : in std_logic;
    -- Carga de la trama
    -- Byte que se agrega a la memoria TX.
    byte_i      : in std_logic_vector(8-1 downto 0);
    -- Pulso de escritura de byte_i.
    charge_byte : in std_logic;
    -- Control
    -- Pulso que inicia la transferencia de los bytes cargados.
    start_spi_transfer : in std_logic;
    -- Indica que el frame se encuentra en ejecucion.
    busy               : out std_logic;
    -- Pulso generado al finalizar el frame completo.
    done               : out std_logic;
    -- Lectura de la memoria de recepcion
    -- Pulso que avanza el puntero de lectura RX.
    rx_ram_read   : in  std_logic;
    -- Indica que no quedan bytes RX por leer.
    rx_ram_empty  : out std_logic;
    -- Byte presente en la salida de la memoria RX.
    rx_ram_data_o : out std_logic_vector(8-1 downto 0);
    -- Pines SPI
    -- Reloj SPI hacia el periferico.
    spi_sclk_o : out std_logic;
    -- Datos SPI hacia el periferico.
    spi_mosi_o : out std_logic;
    -- Datos SPI desde el periferico.
    spi_miso_i : in  std_logic;
    -- Seleccion SPI mantenida activa durante todo el frame.
    spi_nss_o  : out std_logic
);
end spi_frame_controller;

architecture Behavioral of spi_frame_controller is
    -- Este bloque no utiliza una MEF enumerada: el flujo se representa con
    -- writing_flag e inter_frame_waiting.
    -- Cantidad de bits necesaria para direccionar la RAM configurada.
    constant N_RAM_ADDR : integer := integer(ceil(log2(real(RAM_DEPTH))));
    constant INTER_FRAME_DELAY_CYCLES : integer :=
        (CLK_FREQ_HZ/1_000_000)*INTER_FRAME_DELAY_US;
    constant N_INTER_FRAME_COUNTER : integer :=
        integer(ceil(log2(real(INTER_FRAME_DELAY_CYCLES+1))));

    -- Memoria y control de la trama a transmitir. Se separan los punteros de
    -- carga y lectura para poder preparar el frame antes de activar NSS.
    -- La inicializacion evita conversiones to_integer sobre valores U durante
    -- la elaboracion, antes de que el primer flanco de reset sea aplicado.
    signal tx_wr_addr : unsigned(N_RAM_ADDR-1 downto 0) := (others=>'0');
    signal tx_rd_addr : unsigned(N_RAM_ADDR-1 downto 0) := (others=>'0');
    signal byte_data_counter : unsigned(N_RAM_ADDR-1 downto 0);
    signal tx_ram_data : std_logic_vector(8-1 downto 0);

    -- Memoria y control de los bytes recibidos. SPI es full-duplex, por lo que
    -- se conserva un byte RX por cada byte TX aunque el acceso sea escritura.
    signal rx_wr_addr : unsigned(N_RAM_ADDR-1 downto 0) := (others=>'0');
    signal rx_rd_addr : unsigned(N_RAM_ADDR-1 downto 0) := (others=>'0');
    signal rx_data_counter : unsigned(N_RAM_ADDR-1 downto 0);
    signal rx_ram_data : std_logic_vector(8-1 downto 0);
    signal rx_read_enable : std_logic;
    signal rx_ram_empty_reg : std_logic;

    -- Interconexion con el driver encargado de transferir un unico byte.
    signal driver_rx_data : std_logic_vector(8-1 downto 0);
    signal driver_tx_data : std_logic_vector(8-1 downto 0);
    signal driver_busy : std_logic;
    signal driver_done : std_logic;
    signal driver_start_transfer : std_logic;

    -- Estado y eventos principales de una trama.
    signal writing_flag : std_logic;
    signal start_frame : std_logic;
    signal frame_finished : std_logic;
    signal inter_frame_waiting : std_logic;
    signal inter_frame_counter : unsigned(N_INTER_FRAME_COUNTER-1 downto 0);
    signal inter_frame_done : std_logic;

begin

    -- Se acepta un inicio solamente si el controlador esta libre y hay al
    -- menos un byte cargado en la RAM TX.
    start_frame <= '1' when start_spi_transfer='1' and writing_flag='0' and
                            inter_frame_waiting='0' and
                            byte_data_counter/=TO_UNSIGNED(0,N_RAM_ADDR)
                   else '0';

    -- El contador representa los bytes pendientes luego del byte activo.
    -- Cuando el driver termina con el contador en cero finaliza la trama.
    frame_finished <= '1' when writing_flag='1' and driver_done='1' and
                               byte_data_counter=TO_UNSIGNED(0,N_RAM_ADDR)
                      else '0';

    -- RAM que almacena la trama cargada por la interfaz externa.
    tx_ram : entity work.block_ram
        generic map (
            DATA_WIDTH => 8,
            DEPTH      => RAM_DEPTH
        )
        port map (
            clk       => clk,
            rst       => rst,
            wr_en_i   => charge_byte,
            wr_addr_i => to_integer(tx_wr_addr),
            wr_data_i => byte_i,
            rd_addr_i => to_integer(tx_rd_addr),
            rd_data_o => tx_ram_data
        );

    -- RAM que conserva un byte por cada transferencia SPI realizada.
    rx_ram : entity work.block_ram
        generic map (
            DATA_WIDTH => 8,
            DEPTH      => RAM_DEPTH
        )
        port map (
            clk       => clk,
            rst       => rst,
            wr_en_i   => driver_done,
            wr_addr_i => to_integer(rx_wr_addr),
            wr_data_i => driver_rx_data,
            rd_addr_i => to_integer(rx_rd_addr),
            rd_data_o => rx_ram_data
        );

    -- Driver fisico: genera SCLK/MOSI y captura MISO para un byte.
    byte_driver : entity work.spi_pin_driver
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            CPOL        => CPOL,
            CPHA        => CPHA,
            IDLE_VALUE  => IDLE_VALUE
        )
        port map (
            clk        => clk,
            rst        => rst,
            tx_byte_i  => driver_tx_data,
            rx_byte_o  => driver_rx_data,
            start_i    => driver_start_transfer,
            busy_o     => driver_busy,
            done_o     => driver_done,
            spi_sclk_o => spi_sclk_o,
            spi_mosi_o => spi_mosi_o,
            spi_miso_i => spi_miso_i
        );
        
    -- Administra la carga de TX, los bytes pendientes y la direccion de
    -- lectura utilizada por el driver.
    tx_data_manager : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                tx_wr_addr<= TO_UNSIGNED(0, N_RAM_ADDR);
                byte_data_counter<= TO_UNSIGNED(0, N_RAM_ADDR);
                tx_rd_addr<=TO_UNSIGNED(0, N_RAM_ADDR);
            else
                if charge_byte = '1' then
                    tx_wr_addr<=tx_wr_addr+TO_UNSIGNED(1,N_RAM_ADDR);
                    byte_data_counter<=byte_data_counter+TO_UNSIGNED(1,N_RAM_ADDR);
                end if;

                if start_frame='1' then
                    byte_data_counter<=byte_data_counter-TO_UNSIGNED(1,N_RAM_ADDR);                    
                    tx_rd_addr<=TO_UNSIGNED(0, N_RAM_ADDR);
                end if;

                if writing_flag='1' and driver_done='1' then
                    if frame_finished='1' then
                        -- La proxima carga comienza nuevamente en RAM TX(0).
                        tx_wr_addr<=TO_UNSIGNED(0, N_RAM_ADDR);
                        tx_rd_addr<=TO_UNSIGNED(0, N_RAM_ADDR);
                    else
                        byte_data_counter<=byte_data_counter-TO_UNSIGNED(1,N_RAM_ADDR);
                    end if;
                end if;

                if driver_start_transfer='1' then
                    tx_rd_addr<=tx_rd_addr+TO_UNSIGNED(1,N_RAM_ADDR);
                end if;
            end if;
        end if;
    end process;

    -- Escribe cada byte completado en RX RAM y consume una posicion cuando
    -- la interfaz externa genera un pulso rx_ram_read.
    rx_data_manager : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' or start_frame='1' then
                rx_wr_addr<=TO_UNSIGNED(0, N_RAM_ADDR);
                rx_rd_addr<=TO_UNSIGNED(0, N_RAM_ADDR);
                rx_data_counter<=TO_UNSIGNED(0, N_RAM_ADDR);
            else
                if driver_done='1' then
                    rx_wr_addr<=rx_wr_addr+TO_UNSIGNED(1, N_RAM_ADDR);
                end if;

                if rx_read_enable='1' then
                    rx_rd_addr<=rx_rd_addr+TO_UNSIGNED(1, N_RAM_ADDR);
                end if;

                if driver_done='1' and rx_read_enable='0' then
                    rx_data_counter<=rx_data_counter+TO_UNSIGNED(1, N_RAM_ADDR);
                elsif driver_done='0' and rx_read_enable='1' then
                    rx_data_counter<=rx_data_counter-TO_UNSIGNED(1, N_RAM_ADDR);
                end if;
            end if;
        end if;
    end process;

    -- Genera una pausa con NSS inactivo entre tramas completas. No introduce
    -- huecos dentro de una trama: NSS permanece bajo mientras writing_flag=1.
    inter_frame_delay : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                inter_frame_waiting<='0';
                inter_frame_counter<=TO_UNSIGNED(0,N_INTER_FRAME_COUNTER);
                inter_frame_done<='0';
            else
                inter_frame_done<='0';

                if frame_finished='1' then
                    inter_frame_waiting<='1';
                    inter_frame_counter<=TO_UNSIGNED(0,N_INTER_FRAME_COUNTER);
                elsif inter_frame_waiting='1' then
                    if inter_frame_counter=TO_UNSIGNED(INTER_FRAME_DELAY_CYCLES-1,
                                                       N_INTER_FRAME_COUNTER) then
                        inter_frame_waiting<='0';
                        inter_frame_counter<=TO_UNSIGNED(0,N_INTER_FRAME_COUNTER);
                        inter_frame_done<='1';
                    else
                        inter_frame_counter<=inter_frame_counter+
                                             TO_UNSIGNED(1,N_INTER_FRAME_COUNTER);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Secuencia los pulsos start del driver y genera done al completar todos
    -- los bytes, manteniendo writing_flag activo durante la trama completa.
    frame_manager : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                driver_start_transfer<='0';
                writing_flag<='0';
                done<='0';
            else
                done<='0';
                driver_start_transfer<='0';

                if start_frame='1' then
                    driver_start_transfer<='1';
                    writing_flag<='1';
                elsif frame_finished='1' then
                    writing_flag<='0';
                elsif writing_flag='1' and driver_done='1' then
                    driver_start_transfer<='1';
                elsif inter_frame_done='1' then
                    done<='1';
                end if;
            end if;
        end if;
    end process;

    -- Conexiones combinacionales entre memorias, control e interfaz externa.
    driver_tx_data <= tx_ram_data;
    spi_nss_o <= not writing_flag;
    busy <= writing_flag or inter_frame_waiting;

    rx_ram_empty_reg <= '1' when rx_data_counter=TO_UNSIGNED(0,N_RAM_ADDR) else '0';
    rx_read_enable <= rx_ram_read when rx_ram_empty_reg='0' else '0';
    rx_ram_empty <= rx_ram_empty_reg;
    rx_ram_data_o <= rx_ram_data;

end Behavioral;
