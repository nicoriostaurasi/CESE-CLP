----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2026 19:55:14
-- Design Name: 
-- Module Name: spi_frame_controller_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Verificacion integral de spi_frame_controller. Carga y
-- transmite dos tramas consecutivas sin reset intermedio, valida NSS/busy/done
-- y comprueba los bytes almacenados en la RAM RX mediante loopback.
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity spi_frame_controller_tb is
--  Port ( );
end spi_frame_controller_tb;

architecture Behavioral of spi_frame_controller_tb is

    constant clk_period : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- Input signals
    signal byte_i             : std_logic_vector(7 downto 0) := (others => '0');
    signal charge_byte        : std_logic := '0';
    signal start_spi_transfer : std_logic := '0';
    signal spi_miso           : std_logic;
    signal rx_ram_read        : std_logic := '0';

    -- Output signals
    signal busy     : std_logic;
    signal done     : std_logic;
    signal spi_sclk : std_logic;
    signal spi_mosi : std_logic;
    signal spi_nss  : std_logic;
    signal rx_ram_empty  : std_logic;
    signal rx_ram_data   : std_logic_vector(7 downto 0);

begin

    dut : entity work.spi_frame_controller
        generic map (
            RAM_DEPTH  => 16,
            CLK_FREQ_HZ => 100_000_000,
            SPI_FREQ_HZ => 5_000_000,
            CPOL         => '0',
            CPHA         => '0',
            IDLE_VALUE   => '1'
        )
        port map (
            clk                => clk,
            rst                => rst,
            byte_i             => byte_i,
            charge_byte        => charge_byte,
            start_spi_transfer => start_spi_transfer,
            busy               => busy,
            done               => done,
            rx_ram_read        => rx_ram_read,
            rx_ram_empty       => rx_ram_empty,
            rx_ram_data_o      => rx_ram_data,
            spi_sclk_o          => spi_sclk,
            spi_mosi_o          => spi_mosi,
            spi_miso_i          => spi_miso,
            spi_nss_o           => spi_nss
        );

    -- Clock process
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Reset process
    reset_process : process
    begin
        rst <= '1';
        wait for 5*clk_period;
        rst <= '0';
        wait;
    end process;

    -- Loopback para observar simultaneamente transmision y recepcion.
    spi_miso <= spi_mosi;

    stimulus : process
        procedure read_and_check_rx(constant expected_data : std_logic_vector(7 downto 0)) is
        begin
            wait until falling_edge(clk);
            assert rx_ram_empty = '0'
                report "RX RAM vacia antes de leer el byte esperado"
                severity warning;
            assert rx_ram_data = expected_data
                report "Dato incorrecto leido de RX RAM"
                severity warning;

            rx_ram_read <= '1';
            wait until rising_edge(clk);
            rx_ram_read <= '0';

            -- La RAM tiene lectura sincrona: se deja un ciclo para que la
            -- siguiente direccion aparezca en rx_ram_data.
            wait until rising_edge(clk);
        end procedure;
    begin
        wait until falling_edge(rst);
        wait until falling_edge(clk);

        wait until rising_edge(clk);
        -- Carga del primer byte de la trama.
        byte_i <= x"A5";
        charge_byte <= '1';
        wait until rising_edge(clk);
        charge_byte <= '0';

        -- Pausa intencional entre los bytes de la trama.
        wait for 200 ns;

        -- Carga del segundo byte de la trama.
        wait until rising_edge(clk);
        byte_i <= x"81";
        charge_byte <= '1';
        wait until rising_edge(clk);
        charge_byte <= '0';

        wait for 200 ns;

        -- Carga del tercer byte de la trama.
        wait until rising_edge(clk);
        byte_i <= x"96";
        charge_byte <= '1';
        wait until rising_edge(clk);
        charge_byte <= '0';

        wait for 200 ns;

        -- Carga del cuarto byte de la trama.
        wait until rising_edge(clk);
        byte_i <= x"3C";
        charge_byte <= '1';
        wait until rising_edge(clk);
        charge_byte <= '0';

        wait for 200 ns;

        -- Inicio de la transferencia de la trama cargada.
        wait until rising_edge(clk);
        start_spi_transfer <= '1';
        wait until rising_edge(clk);
        start_spi_transfer <= '0';

        -- Se comprueba medio ciclo despues para observar las asignaciones
        -- registradas por el DUT en el flanco anterior.
        wait until falling_edge(clk);
        assert busy = '1'
            report "BUSY no se activo al iniciar la trama"
            severity warning;
        assert spi_nss = '0'
            report "NSS no se activo al iniciar la trama"
            severity warning;

        -- Se limita la espera para que un error en la FSM no bloquee el TB.
        wait until done = '1' for 20 us;
        assert done = '1'
            report "La transferencia de cuatro bytes no finalizo"
            severity warning;

        if done = '1' then
            wait until falling_edge(clk);
            assert busy = '0'
                report "BUSY no se libero al finalizar la trama"
                severity warning;
            assert spi_nss = '1'
                report "NSS no volvio a reposo al finalizar la trama"
                severity warning;

            -- En loopback, la RX RAM debe conservar la misma trama enviada.
            read_and_check_rx(x"A5");
            read_and_check_rx(x"81");
            read_and_check_rx(x"96");
            read_and_check_rx(x"3C");

            wait until falling_edge(clk);
            assert rx_ram_empty = '1'
                report "RX RAM no quedo vacia luego de cuatro lecturas"
                severity warning;
        end if;

        -- Segunda trama, sin reset entre transferencias, para comprobar que
        -- el controlador pueda reutilizarse.
        wait for 200 ns;

        wait until rising_edge(clk);
        byte_i <= x"0F";
        charge_byte <= '1';
        wait until rising_edge(clk);
        charge_byte <= '0';

        wait for 200 ns;

        wait until rising_edge(clk);
        byte_i <= x"F0";
        charge_byte <= '1';
        wait until rising_edge(clk);
        charge_byte <= '0';

        wait for 200 ns;

        wait until rising_edge(clk);
        start_spi_transfer <= '1';
        wait until rising_edge(clk);
        start_spi_transfer <= '0';

        wait until falling_edge(clk);
        assert busy = '1'
            report "BUSY no se activo al iniciar la segunda trama"
            severity warning;
        assert spi_nss = '0'
            report "NSS no se activo al iniciar la segunda trama"
            severity warning;

        wait until done = '1' for 20 us;
        assert done = '1'
            report "La segunda transferencia no finalizo"
            severity warning;

        if done = '1' then
            wait until falling_edge(clk);
            assert busy = '0'
                report "BUSY no se libero al finalizar la segunda trama"
                severity warning;
            assert spi_nss = '1'
                report "NSS no volvio a reposo al finalizar la segunda trama"
                severity warning;

            read_and_check_rx(x"0F");
            read_and_check_rx(x"F0");

            wait until falling_edge(clk);
            assert rx_ram_empty = '1'
                report "RX RAM no quedo vacia luego de la segunda trama"
                severity warning;
        end if;

        wait for 100 ns;
        report "Fin de las transmisiones de spi_frame_controller" severity note;
        wait;
    end process;

end Behavioral;
