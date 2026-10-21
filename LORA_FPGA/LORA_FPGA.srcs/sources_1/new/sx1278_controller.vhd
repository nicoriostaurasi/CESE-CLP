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
-- Description: Top del controlador SX1278. Integra managers independientes
--              para CONFIG, TX y RX, y arbitra su acceso al secuenciador SPI.
--
-- Dependencies: sx1278_controller_pkg, sx1278_config_manager,
--               sx1278_tx_manager, sx1278_rx_manager,
--               sx1278_config_registers, spi_sequence_controller
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
use work.sx1278_controller_pkg.all;

entity sx1278_controller is
    generic (
        MAX_DATA_BYTES : integer := 50;
        CLK_FREQ_HZ : integer := 100_000_000;
        SPI_FREQ_HZ : integer := 5_000_000;
        RESET_TIME_MS : integer := 10
    );
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset general sincrono.
        rst : in std_logic;
        -- Habilita la escritura del banco de configuracion.
        config_wr_ena_i : in std_logic;
        -- Direccion del parametro de configuracion.
        config_addr_i : in std_logic_vector(8-1 downto 0);
        -- Valor del parametro de configuracion.
        config_data_i : in std_logic_vector(8-1 downto 0);
        -- Pulso que aplica por SPI la configuracion almacenada.
        config_start_i : in std_logic;
        -- Solicitud de reset fisico del SX1278.
        peripheral_reset_request_i : in std_logic;
        -- Inicia un payload TX nuevo y vacia su buffer.
        tx_begin_i : in std_logic;
        -- Byte que se agrega al payload TX.
        tx_data_i : in std_logic_vector(8-1 downto 0);
        -- Pulso que valida tx_data_i.
        tx_data_valid_i : in std_logic;
        -- Pulso que inicia la transmision del payload cargado.
        tx_start_i : in std_logic;
        -- Pulso que inicia la recepcion de un paquete.
        rx_start_i : in std_logic;
        -- Indice para lectura del buffer RX.
        rx_read_index_i : in std_logic_vector(6-1 downto 0);
        -- Byte RX seleccionado por rx_read_index_i.
        rx_data_o : out std_logic_vector(8-1 downto 0);
        -- Longitud del ultimo paquete RX valido.
        rx_length_o : out std_logic_vector(6-1 downto 0);
        -- Indica que existe un paquete RX valido.
        rx_valid_o : out std_logic;
        -- Indica que el paquete RX espera ser enviado por UART.
        rx_packet_pending_o : out std_logic;
        -- Indice de lectura utilizado por el serializador UART.
        rx_stream_index_i : in std_logic_vector(6-1 downto 0);
        -- Byte RX seleccionado para el flujo UART.
        rx_stream_data_o : out std_logic_vector(8-1 downto 0);
        -- Pulso que libera el paquete luego de enviarlo por UART.
        rx_packet_sent_i : in std_logic;
        -- Indica que alguno de los managers ejecuta una operacion.
        busy_o : out std_logic;
        -- Pulso de finalizacion de la operacion activa.
        done_o : out std_logic;
        -- Indica error detectado durante la operacion activa.
        error_o : out std_logic;
        -- Reloj SPI hacia el SX1278.
        spi_sclk_o : out std_logic;
        -- Datos SPI hacia el SX1278.
        spi_mosi_o : out std_logic;
        -- Datos SPI desde el SX1278.
        spi_miso_i : in std_logic;
        -- Seleccion SPI activa en bajo.
        spi_nss_o : out std_logic;
        -- Entrada asincronica DIO0 del SX1278.
        sx1278_dio0_i : in std_logic;
        -- Reset fisico activo en bajo del SX1278.
        sx1278_reset_o : out std_logic;
        -- Indica que el generador interno mantiene activo el reset.
        peripheral_reset_active_o : out std_logic
    );
end sx1278_controller;

architecture Behavioral of sx1278_controller is
    constant RESET_CYCLES : integer := (CLK_FREQ_HZ/1_000)*RESET_TIME_MS;
    constant N_RESET_COUNTER : integer := integer(ceil(log2(real(RESET_CYCLES+1))));

    signal reset_counter : unsigned(N_RESET_COUNTER-1 downto 0);
    signal reset_active : std_logic;
    signal operation_reset : std_logic;
    signal dio0_sync_reg : std_logic_vector(3-1 downto 0);
    signal dio0_rising_edge : std_logic;

    signal frf_msb_reg : std_logic_vector(8-1 downto 0);
    signal frf_mid_reg : std_logic_vector(8-1 downto 0);
    signal frf_lsb_reg : std_logic_vector(8-1 downto 0);
    signal bandwidth_reg : std_logic_vector(8-1 downto 0);
    signal coding_rate_reg : std_logic_vector(8-1 downto 0);
    signal spreading_factor_reg : std_logic_vector(8-1 downto 0);
    signal preamble_msb_reg : std_logic_vector(8-1 downto 0);
    signal preamble_lsb_reg : std_logic_vector(8-1 downto 0);
    signal pa_config_reg : std_logic_vector(8-1 downto 0);

    signal config_request : std_logic;
    signal config_sequence_done : std_logic;
    signal config_frame : std_logic_vector(16-1 downto 0);
    signal config_last_step : std_logic_vector(4-1 downto 0);
    signal config_busy : std_logic;
    signal config_done : std_logic;

    signal tx_request : std_logic;
    signal tx_sequence_done : std_logic;
    signal tx_frame : std_logic_vector(16-1 downto 0);
    signal tx_last_step : std_logic_vector(4-1 downto 0);
    signal tx_busy : std_logic;
    signal tx_done : std_logic;

    signal rx_request : std_logic;
    signal rx_sequence_done : std_logic;
    signal rx_frame : std_logic_vector(16-1 downto 0);
    signal rx_last_step : std_logic_vector(4-1 downto 0);
    signal rx_read : std_logic;
    signal rx_busy : std_logic;
    signal rx_done : std_logic;
    signal rx_error : std_logic;

    type t_arbiter_state is (ST_ARB_IDLE, ST_ARB_START, ST_ARB_WAIT, ST_ARB_DONE);
    type t_sequence_owner is (OWNER_NONE, OWNER_CONFIG, OWNER_TX, OWNER_RX);
    signal arbiter_state_now : t_arbiter_state;
    signal arbiter_state_next : t_arbiter_state;
    signal owner_d : t_sequence_owner;
    signal owner_q : t_sequence_owner;

    signal sequence_start : std_logic;
    signal sequence_frame : std_logic_vector(16-1 downto 0);
    signal sequence_last_step : std_logic_vector(4-1 downto 0);
    signal sequence_read : std_logic;
    signal sequence_step : std_logic_vector(4-1 downto 0);
    signal sequence_done : std_logic;
    signal sequence_rx_data : std_logic_vector(8-1 downto 0);
begin
    -- RESET_PERIPH tambien cancela cualquier operacion CONFIG, TX o RX que
    -- estuviera pendiente. De este modo una recepcion que espera DIO0 no deja
    -- al controlador ocupado despues de resetear fisicamente el SX1278.
    operation_reset<=rst or peripheral_reset_request_i;

    dio0_edge_detector : process(clk)
    begin
        if rising_edge(clk) then
            if operation_reset='1' then
                dio0_sync_reg<=(others=>'0');
            else
                dio0_sync_reg(0)<=sx1278_dio0_i;
                dio0_sync_reg(1)<=dio0_sync_reg(0);
                dio0_sync_reg(2)<=dio0_sync_reg(1);
            end if;
        end if;
    end process;

    dio0_rising_edge<=dio0_sync_reg(1) and not dio0_sync_reg(2);

    peripheral_reset : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                reset_active<='0';
                reset_counter<=TO_UNSIGNED(0,reset_counter'length);
            elsif peripheral_reset_request_i='1' then
                reset_active<='1';
                reset_counter<=TO_UNSIGNED(0,reset_counter'length);
            elsif reset_active='1' then
                if reset_counter=TO_UNSIGNED(RESET_CYCLES-1,reset_counter'length) then
                    reset_active<='0';
                    reset_counter<=TO_UNSIGNED(0,reset_counter'length);
                else
                    reset_counter<=reset_counter+TO_UNSIGNED(1,reset_counter'length);
                end if;
            end if;
        end if;
    end process;

    -- El reset fisico, activo en bajo, puede originarse desde el reset general
    -- de la placa o desde el pulso temporizado solicitado mediante UART.
    sx1278_reset_o<=not (rst or reset_active);
    peripheral_reset_active_o<=reset_active;

    config_register_bank : entity work.sx1278_config_registers
        port map (
            clk => clk,
            rst => rst,
            wr_ena_i => config_wr_ena_i,
            addr_i => config_addr_i,
            data_i => config_data_i,
            frf_msb_o => frf_msb_reg,
            frf_mid_o => frf_mid_reg,
            frf_lsb_o => frf_lsb_reg,
            bandwidth_o => bandwidth_reg,
            coding_rate_o => coding_rate_reg,
            spreading_factor_o => spreading_factor_reg,
            preamble_msb_o => preamble_msb_reg,
            preamble_lsb_o => preamble_lsb_reg,
            pa_config_o => pa_config_reg
        );

    config_manager : entity work.sx1278_config_manager
        port map (
            clk => clk,
            rst => operation_reset,
            start_i => config_start_i,
            frf_msb_i => frf_msb_reg,
            frf_mid_i => frf_mid_reg,
            frf_lsb_i => frf_lsb_reg,
            bandwidth_i => bandwidth_reg(4-1 downto 0),
            coding_rate_i => coding_rate_reg(3-1 downto 0),
            spreading_factor_i => spreading_factor_reg(4-1 downto 0),
            preamble_msb_i => preamble_msb_reg,
            preamble_lsb_i => preamble_lsb_reg,
            pa_config_i => pa_config_reg,
            sequence_request_o => config_request,
            sequence_step_i => sequence_step,
            sequence_frame_o => config_frame,
            sequence_last_step_o => config_last_step,
            sequence_done_i => config_sequence_done,
            busy_o => config_busy,
            done_o => config_done
        );

    tx_manager : entity work.sx1278_tx_manager
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES
        )
        port map (
            clk => clk,
            rst => operation_reset,
            tx_begin_i => tx_begin_i,
            tx_write_i => tx_data_valid_i,
            tx_data_i => tx_data_i,
            tx_start_i => tx_start_i,
            sx1278_dio0_rising_edge_i => dio0_rising_edge,
            spi_sequence_request_o => tx_request,
            spi_sequence_step_i => sequence_step,
            spi_sequence_frame_o => tx_frame,
            spi_sequence_last_step_o => tx_last_step,
            spi_sequence_done_i => tx_sequence_done,
            tx_busy_o => tx_busy,
            tx_done_o => tx_done
        );

    rx_manager : entity work.sx1278_rx_manager
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES
        )
        port map (
            clk => clk,
            rst => operation_reset,
            start_i => rx_start_i,
            dio0_rising_edge_i => dio0_rising_edge,
            sequence_request_o => rx_request,
            sequence_step_i => sequence_step,
            sequence_frame_o => rx_frame,
            sequence_last_step_o => rx_last_step,
            sequence_read_o => rx_read,
            sequence_done_i => rx_sequence_done,
            sequence_read_data_i => sequence_rx_data,
            read_index_i => rx_read_index_i,
            data_o => rx_data_o,
            length_o => rx_length_o,
            valid_o => rx_valid_o,
            packet_pending_o => rx_packet_pending_o,
            stream_index_i => rx_stream_index_i,
            stream_data_o => rx_stream_data_o,
            packet_sent_i => rx_packet_sent_i,
            busy_o => rx_busy,
            done_o => rx_done,
            error_o => rx_error
        );

    sequence_controller : entity work.spi_sequence_controller
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ,
            N_STEP => 4
        )
        port map (
            clk => clk,
            rst => operation_reset,
            start_i => sequence_start,
            frame_i => sequence_frame,
            last_step_i => sequence_last_step,
            read_i => sequence_read,
            step_o => sequence_step,
            busy_o => open,
            done_o => sequence_done,
            read_data_o => sequence_rx_data,
            spi_sclk_o => spi_sclk_o,
            spi_mosi_o => spi_mosi_o,
            spi_miso_i => spi_miso_i,
            spi_nss_o => spi_nss_o
        );

    arbiter_register : process(clk)
    begin
        if rising_edge(clk) then
            if operation_reset='1' then
                arbiter_state_now<=ST_ARB_IDLE;
                owner_q<=OWNER_NONE;
            else
                arbiter_state_now<=arbiter_state_next;
                owner_q<=owner_d;
            end if;
        end if;
    end process;

    arbiter_next_state : process(arbiter_state_now,config_request,tx_request,rx_request,sequence_done)
    begin
        arbiter_state_next<=arbiter_state_now;
        case arbiter_state_now is
            when ST_ARB_IDLE =>
                if rx_request='1' or config_request='1' or tx_request='1' then
                    arbiter_state_next<=ST_ARB_START;
                end if;
            when ST_ARB_START =>
                arbiter_state_next<=ST_ARB_WAIT;
            when ST_ARB_WAIT =>
                if sequence_done='1' then
                    arbiter_state_next<=ST_ARB_DONE;
                end if;
            when ST_ARB_DONE =>
                arbiter_state_next<=ST_ARB_IDLE;
        end case;
    end process;

    arbiter_output_logic : process(arbiter_state_now,owner_q,config_request,tx_request,rx_request)
    begin
        owner_d<=owner_q;
        sequence_start<='0';

        case arbiter_state_now is
            when ST_ARB_IDLE =>
                if rx_request='1' then
                    owner_d<=OWNER_RX;
                elsif config_request='1' then
                    owner_d<=OWNER_CONFIG;
                elsif tx_request='1' then
                    owner_d<=OWNER_TX;
                else
                    owner_d<=OWNER_NONE;
                end if;
            when ST_ARB_START =>
                sequence_start<='1';
            when others =>
                null;
        end case;
    end process;

    config_sequence_done<='1' when arbiter_state_now=ST_ARB_DONE and
                                         owner_q=OWNER_CONFIG else '0';
    tx_sequence_done<='1' when arbiter_state_now=ST_ARB_DONE and
                                     owner_q=OWNER_TX else '0';
    rx_sequence_done<='1' when arbiter_state_now=ST_ARB_DONE and
                                     owner_q=OWNER_RX else '0';

    -- El dueño registrado permanece fijo durante toda la secuencia. Los
    -- managers construyen sus propias tramas y el arbitro solamente las
    -- multiplexa hacia el secuenciador SPI compartido.
    sequence_frame<=config_frame when owner_q=OWNER_CONFIG else
                    tx_frame when owner_q=OWNER_TX else
                    rx_frame when owner_q=OWNER_RX else
                    (others=>'0');
    sequence_last_step<=config_last_step when owner_q=OWNER_CONFIG else
                        tx_last_step when owner_q=OWNER_TX else
                        rx_last_step when owner_q=OWNER_RX else
                        (others=>'0');
    sequence_read<='0' when owner_q=OWNER_CONFIG or owner_q=OWNER_TX else
                   rx_read when owner_q=OWNER_RX else
                   '0';

    busy_o<=config_busy or tx_busy or rx_busy;
    done_o<=config_done or tx_done or rx_done;
    error_o<=rx_error;
end Behavioral;
