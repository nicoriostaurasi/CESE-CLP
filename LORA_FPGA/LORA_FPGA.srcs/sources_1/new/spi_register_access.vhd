----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 26.09.2026
-- Design Name:
-- Module Name: spi_register_access - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Adapta una operacion SPI de dos bytes a la interfaz de carga
--              del spi_frame_controller. Para una lectura tambien descarta
--              el byte recibido mientras se transmite la direccion y entrega
--              el byte de datos recibido a continuacion.
--
-- Dependencies: spi_frame_controller
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_register_access is
    generic (
        CLK_FREQ_HZ : integer := 100_000_000;
        SPI_FREQ_HZ : integer := 5_000_000
    );
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono del adaptador y del controlador de frame.
        rst : in std_logic;
        -- Pulso que inicia el acceso SPI de dos bytes.
        start_i : in std_logic;
        -- Primer byte, normalmente direccion y bit R/W.
        first_byte_i : in std_logic_vector(8-1 downto 0);
        -- Segundo byte, dato de escritura o valor dummy.
        second_byte_i : in std_logic_vector(8-1 downto 0);
        -- Selecciona una operacion de lectura.
        read_i : in std_logic;
        -- Indica que el acceso esta en curso.
        busy_o : out std_logic;
        -- Pulso generado al terminar el acceso.
        done_o : out std_logic;
        -- Segundo byte recibido durante una lectura.
        read_data_o : out std_logic_vector(8-1 downto 0);
        -- Reloj SPI hacia el periferico.
        spi_sclk_o : out std_logic;
        -- Datos SPI hacia el periferico.
        spi_mosi_o : out std_logic;
        -- Datos SPI desde el periferico.
        spi_miso_i : in std_logic;
        -- Seleccion SPI activa en bajo.
        spi_nss_o : out std_logic
    );
end spi_register_access;

architecture Behavioral of spi_register_access is

    -- Adapta una operación lógica de dos bytes al protocolo del frame
    -- controller. Para lecturas se descarta el byte simultáneo a la dirección
    -- y se conserva el recibido durante el byte dummy.
    type t_state is (ST_IDLE, ST_LOAD_FIRST, ST_LOAD_SECOND,
                     ST_START_FRAME, ST_WAIT_FRAME,
                     ST_SKIP_FIRST_RX, ST_WAIT_SECOND_RX,
                     ST_CAPTURE_RX, ST_DONE);

    signal state_now : t_state;
    signal state_next : t_state;
    signal first_byte_reg : std_logic_vector(8-1 downto 0);
    signal second_byte_reg : std_logic_vector(8-1 downto 0);
    signal read_reg : std_logic;
    signal read_data_reg : std_logic_vector(8-1 downto 0);
    signal frame_byte : std_logic_vector(8-1 downto 0);
    signal frame_charge_byte : std_logic;
    signal frame_start_transfer : std_logic;
    signal frame_done : std_logic;
    signal frame_rx_data : std_logic_vector(8-1 downto 0);
    signal frame_rx_read : std_logic;

begin

    frame_controller : entity work.spi_frame_controller
        generic map (
            RAM_DEPTH => 3,
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            CPOL => '0',
            CPHA => '0',
            IDLE_VALUE => '0'
        )
        port map (
            clk => clk,
            rst => rst,
            byte_i => frame_byte,
            charge_byte => frame_charge_byte,
            start_spi_transfer => frame_start_transfer,
            busy => open,
            done => frame_done,
            rx_ram_read => frame_rx_read,
            rx_ram_empty => open,
            rx_ram_data_o => frame_rx_data,
            spi_sclk_o => spi_sclk_o,
            spi_mosi_o => spi_mosi_o,
            spi_miso_i => spi_miso_i,
            spi_nss_o => spi_nss_o
        );

    register_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state_now<=ST_IDLE;
                first_byte_reg<=(others=>'0');
                second_byte_reg<=(others=>'0');
                read_reg<='0';
                read_data_reg<=(others=>'0');
            else
                state_now<=state_next;

                -- Los parámetros se registran al comenzar para que puedan
                -- permanecer estables durante toda la transaccion interna.
                if state_now=ST_IDLE and start_i='1' then
                    first_byte_reg<=first_byte_i;
                    second_byte_reg<=second_byte_i;
                    read_reg<=read_i;
                end if;

                if state_now=ST_CAPTURE_RX then
                    read_data_reg<=frame_rx_data;
                end if;
            end if;
        end if;
    end process;

    next_state_logic : process(state_now,start_i,frame_done,read_reg)
    begin
        state_next<=state_now;

        case state_now is
            when ST_IDLE =>
                if start_i='1' then
                    state_next<=ST_LOAD_FIRST;
                end if;
            when ST_LOAD_FIRST =>
                state_next<=ST_LOAD_SECOND;
            when ST_LOAD_SECOND =>
                state_next<=ST_START_FRAME;
            when ST_START_FRAME =>
                state_next<=ST_WAIT_FRAME;
            when ST_WAIT_FRAME =>
                if frame_done='1' then
                    if read_reg='1' then
                        state_next<=ST_SKIP_FIRST_RX;
                    else
                        state_next<=ST_DONE;
                    end if;
                end if;
            when ST_SKIP_FIRST_RX =>
                state_next<=ST_WAIT_SECOND_RX;
            when ST_WAIT_SECOND_RX =>
                state_next<=ST_CAPTURE_RX;
            when ST_CAPTURE_RX =>
                state_next<=ST_DONE;
            when ST_DONE =>
                state_next<=ST_IDLE;
        end case;
    end process;

    frame_byte<=first_byte_reg when state_now=ST_LOAD_FIRST
        else second_byte_reg;

    frame_charge_byte<='1' when state_now=ST_LOAD_FIRST or
                                    state_now=ST_LOAD_SECOND
        else '0';

    frame_start_transfer<='1' when state_now=ST_START_FRAME else '0';
    frame_rx_read<='1' when state_now=ST_SKIP_FIRST_RX else '0';
    busy_o<='0' when state_now=ST_IDLE else '1';
    done_o<='1' when state_now=ST_DONE else '0';
    read_data_o<=read_data_reg;

end Behavioral;
