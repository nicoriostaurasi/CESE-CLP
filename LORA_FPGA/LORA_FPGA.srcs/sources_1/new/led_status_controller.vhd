----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.09.2026 22:33:38
-- Design Name: 
-- Module Name: led_status_controller - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Controla los cuatro LED de estado de la placa Zybo.
--              LED0: heartbeat.
--              LED1: actividad UART visible durante un tiempo minimo.
--              LED2: controlador SX1278 ocupado.
--              LED3: error retenido hasta el reset general.
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
use work.uart_command_pkg.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led_status_controller is
    generic (
        CLK_FREQ_HZ : integer := 125_000_000;
        HEARTBEAT_HALF_PERIOD_MS : integer := 500;
        UART_ACTIVITY_TIME_MS : integer := 100
    );
    port (
        -- Reloj principal del sistema.
        clk : in std_logic;
        -- Reset sincrono de indicadores y contadores.
        rst : in std_logic;

        -- Pulso generado al recibir una trama UART completa.
        uart_frame_received_i : in std_logic;
        -- Indica que el controlador SX1278 ejecuta una operacion.
        controller_busy_i : in std_logic;
        -- Indica un error informado por el controlador SX1278.
        controller_error_i : in std_logic;
        -- Estado ACK/NACK de la ultima respuesta UART.
        response_status_i : in std_logic_vector(8-1 downto 0);

        -- LED3..LED0 de estado conectados a la placa.
        leds_o : out std_logic_vector(4-1 downto 0)
    );
end led_status_controller;

architecture Behavioral of led_status_controller is

    constant HEARTBEAT_CYCLES : integer := (CLK_FREQ_HZ/1_000)*HEARTBEAT_HALF_PERIOD_MS;
    constant N_HEARTBEAT_COUNTER : integer := integer(ceil(log2(real(HEARTBEAT_CYCLES+1))));

    constant UART_ACTIVITY_CYCLES : integer := (CLK_FREQ_HZ/1_000)*UART_ACTIVITY_TIME_MS;
    constant N_UART_ACTIVITY_COUNTER : integer := integer(ceil(log2(real(UART_ACTIVITY_CYCLES+1))));

    signal heartbeat_counter : unsigned(N_HEARTBEAT_COUNTER-1 downto 0);
    signal uart_activity_counter : unsigned(N_UART_ACTIVITY_COUNTER-1 downto 0);

    signal heartbeat_led : std_logic;
    signal uart_activity_led : std_logic;
    signal error_led : std_logic;
    signal uart_nack_event : std_logic;
begin

    -- Genera una indicacion periodica de que el clock y el diseño funcionan.
    heartbeat : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                heartbeat_counter<=TO_UNSIGNED(0,N_HEARTBEAT_COUNTER);
                heartbeat_led<='0';
            elsif heartbeat_counter=TO_UNSIGNED(HEARTBEAT_CYCLES-1,N_HEARTBEAT_COUNTER) then
                heartbeat_counter<=TO_UNSIGNED(0,N_HEARTBEAT_COUNTER);
                heartbeat_led<=not heartbeat_led;
            else
                heartbeat_counter<=heartbeat_counter+TO_UNSIGNED(1,N_HEARTBEAT_COUNTER);
            end if;
        end if;
    end process;

    -- Estira el pulso de trama recibida mediante un contador descendente.
    uart_activity : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                uart_activity_counter<=TO_UNSIGNED(0,N_UART_ACTIVITY_COUNTER);
                uart_activity_led<='0';
            elsif uart_frame_received_i='1' then
                uart_activity_led<='1';
                uart_activity_counter<=TO_UNSIGNED(UART_ACTIVITY_CYCLES,N_UART_ACTIVITY_COUNTER);
            elsif uart_activity_counter/=TO_UNSIGNED(0,N_UART_ACTIVITY_COUNTER) then
                uart_activity_counter<=uart_activity_counter-TO_UNSIGNED(1,N_UART_ACTIVITY_COUNTER);

                if uart_activity_counter=TO_UNSIGNED(1,N_UART_ACTIVITY_COUNTER) then
                    uart_activity_led<='0';
                end if;
            end if;
        end if;
    end process;

    -- Reune las dos causas de error antes del registro que las memoriza.
    uart_nack_event<='1' when uart_frame_received_i='1' and response_status_i=UART_NACK else '0';

    -- Retiene cualquier NACK o error del controlador hasta el reset general.
    error_memory : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                error_led<='0';
            elsif (controller_error_i='1' or uart_nack_event='1') then
                error_led<='1';
            end if;
        end if;
    end process;

    leds_o<=error_led & controller_busy_i & uart_activity_led & heartbeat_led;

end Behavioral;
