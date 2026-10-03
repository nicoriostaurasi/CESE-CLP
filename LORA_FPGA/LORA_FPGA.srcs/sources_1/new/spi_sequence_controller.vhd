----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 26.09.2026
-- Design Name:
-- Module Name: spi_sequence_controller - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Ejecuta una secuencia de uno o mas accesos SPI de dos bytes.
--              El indice expuesto selecciona externamente el frame actual,
--              permitiendo reutilizar el bloque con distintas secuencias.
--
-- Dependencies: spi_register_access
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_sequence_controller is
    generic (
        CLK_FREQ_HZ : integer := 100_000_000;
        SPI_FREQ_HZ : integer := 5_000_000;
        N_STEP : integer := 4
    );
    port (
        -- Reloj principal.
        clk : in std_logic;
        -- Reset sincrono de la MEF y del contador de pasos.
        rst : in std_logic;
        -- Pulso que inicia la secuencia de frames.
        start_i : in std_logic;
        -- Frame de 16 bits seleccionado externamente.
        frame_i : in std_logic_vector(16-1 downto 0);
        -- Indice del ultimo frame que debe ejecutarse.
        last_step_i : in std_logic_vector(N_STEP-1 downto 0);
        -- Indica que el frame actual es una lectura.
        read_i : in std_logic;
        -- Indice del frame actualmente solicitado.
        step_o : out std_logic_vector(N_STEP-1 downto 0);
        -- Indica que la secuencia esta en ejecucion.
        busy_o : out std_logic;
        -- Pulso de fin de secuencia.
        done_o : out std_logic;
        -- Dato obtenido de la ultima lectura SPI.
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
end spi_sequence_controller;

architecture Behavioral of spi_sequence_controller is

    -- Recorre una secuencia sin conocer su contenido. step_o selecciona el
    -- frame externo y last_step_i determina cuándo termina. El índice avanza
    -- únicamente después de access_done para no sobrescribir una operación
    -- todavía activa. Diagrama: doc/diagrams/spi_sequence_fsm.puml
    type t_state is (ST_IDLE, ST_START_ACCESS, ST_WAIT_ACCESS, ST_DONE);

    signal state_now : t_state;
    signal state_next : t_state;
    signal step_q : unsigned(N_STEP-1 downto 0);
    signal step_d : unsigned(N_STEP-1 downto 0);
    signal last_step_q : unsigned(N_STEP-1 downto 0);
    signal last_step_d : unsigned(N_STEP-1 downto 0);
    signal read_q : std_logic;
    signal read_d : std_logic;
    signal access_start : std_logic;
    signal access_done : std_logic;

begin

    register_access : entity work.spi_register_access
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            SPI_FREQ_HZ => SPI_FREQ_HZ
        )
        port map (
            clk => clk,
            rst => rst,
            start_i => access_start,
            first_byte_i => frame_i(16-1 downto 8),
            second_byte_i => frame_i(8-1 downto 0),
            read_i => read_q,
            busy_o => open,
            done_o => access_done,
            read_data_o => read_data_o,
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
                step_q<=TO_UNSIGNED(0,step_q'length);
                last_step_q<=TO_UNSIGNED(0,last_step_q'length);
                read_q<='0';
            else
                state_now<=state_next;
                step_q<=step_d;
                last_step_q<=last_step_d;
                read_q<=read_d;
            end if;
        end if;
    end process;

    next_state_logic : process(state_now,start_i,access_done,step_q,last_step_q)
    begin
        state_next<=state_now;

        case state_now is
            when ST_IDLE =>
                if start_i='1' then
                    state_next<=ST_START_ACCESS;
                end if;
            when ST_START_ACCESS =>
                state_next<=ST_WAIT_ACCESS;
            when ST_WAIT_ACCESS =>
                if access_done='1' then
                    if step_q=last_step_q then
                        state_next<=ST_DONE;
                    else
                        state_next<=ST_START_ACCESS;
                    end if;
                end if;
            when ST_DONE =>
                state_next<=ST_IDLE;
        end case;
    end process;

    output_logic : process(state_now,start_i,last_step_i,read_i,
                           step_q,last_step_q,read_q,access_done)
    begin
        step_d<=step_q;
        last_step_d<=last_step_q;
        read_d<=read_q;

        if state_now=ST_IDLE and start_i='1' then
            step_d<=TO_UNSIGNED(0,step_d'length);
            last_step_d<=unsigned(last_step_i);
            read_d<=read_i;
        elsif state_now=ST_WAIT_ACCESS and access_done='1' and
              step_q<last_step_q then
            step_d<=step_q+TO_UNSIGNED(1,step_q'length);
        elsif state_now=ST_DONE then
            -- Se deja el indice preparado para que un cambio de operacion no
            -- indexe transitoriamente una secuencia mas corta.
            step_d<=TO_UNSIGNED(0,step_d'length);
        end if;
    end process;

    access_start<='1' when state_now=ST_START_ACCESS else '0';
    step_o<=std_logic_vector(step_q);
    busy_o<='0' when state_now=ST_IDLE else '1';
    done_o<='1' when state_now=ST_DONE else '0';

end Behavioral;
