----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2026 22:54:28
-- Design Name: 
-- Module Name: sx1262_spi_manager_tb - Behavioral
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

entity sx1262_spi_manager_tb is
--  Port ( );
end sx1262_spi_manager_tb;

architecture Behavioral of sx1262_spi_manager_tb is

    constant CLK_PERIOD : time := 10 ns;
    constant MAX_DATA_BYTES : integer := 50;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- Entradas y salidas de la interfaz de comandos.
    signal command_i : std_logic_vector(3-1 downto 0) := "000";
    signal start_i : std_logic := '0';
    signal busy_o : std_logic;
    signal done_o : std_logic;
    signal error_o : std_logic;

    -- Interfaz del banco de registros de configuracion.
    signal config_wr_i : std_logic := '0';
    signal config_addr_i : std_logic_vector(4-1 downto 0) := (others=>'0');
    signal config_data_i : std_logic_vector(32-1 downto 0) := (others=>'0');
    signal config_data_o : std_logic_vector(32-1 downto 0);

    signal write_info_i : std_logic_vector(MAX_DATA_BYTES*8-1 downto 0) :=
        (others=>'0');
    signal write_length_i : integer range 0 to MAX_DATA_BYTES := 0;
    signal read_length_i : integer range 0 to MAX_DATA_BYTES := 0;
    signal read_info_o : std_logic_vector(MAX_DATA_BYTES*8-1 downto 0);
    signal read_length_o : integer range 0 to MAX_DATA_BYTES;
    signal read_valid_o : std_logic;

    -- Interfaz fisica del SX1262.
    signal spi_sclk_o : std_logic;
    signal spi_mosi_o : std_logic;
    signal spi_miso_i : std_logic := '0';
    signal spi_nss_o : std_logic;
    signal sx1262_busy_i : std_logic := '0';
    signal sx1262_dio1_i : std_logic := '0';
    signal sx1262_reset_o : std_logic;

    type byte_array_t is array (natural range <>) of
        std_logic_vector(8-1 downto 0);

begin

    uut : entity work.sx1262_spi_manager
        generic map (
            MAX_DATA_BYTES => MAX_DATA_BYTES,
            CLK_FREQ_HZ    => 100_000_000,
            SPI_FREQ_HZ    => 5_000_000
        )
        port map (
            clk              => clk,
            rst              => rst,
            command_i        => command_i,
            start_i          => start_i,
            busy_o           => busy_o,
            done_o           => done_o,
            error_o          => error_o,
            config_wr_i      => config_wr_i,
            config_addr_i    => config_addr_i,
            config_data_i    => config_data_i,
            config_data_o    => config_data_o,
            write_info_i     => write_info_i,
            write_length_i   => write_length_i,
            read_length_i    => read_length_i,
            read_info_o      => read_info_o,
            read_length_o    => read_length_o,
            read_valid_o     => read_valid_o,
            spi_sclk_o       => spi_sclk_o,
            spi_mosi_o       => spi_mosi_o,
            spi_miso_i       => spi_miso_i,
            spi_nss_o        => spi_nss_o,
            sx1262_busy_i    => sx1262_busy_i,
            sx1262_dio1_i    => sx1262_dio1_i,
            sx1262_reset_o   => sx1262_reset_o
        );

    -- Reloj de sistema de 100 MHz.
    clk_process : process
    begin
        clk<='0';
        wait for CLK_PERIOD/2;
        clk<='1';
        wait for CLK_PERIOD/2;
    end process;

    -- Reset inicial sincrono.
    reset_process : process
    begin
        rst<='1';
        wait for 50 ns;
        rst<='0';
        wait;
    end process;

    -- Modelo simplificado de BUSY del SX1262. Luego de recibir cada frame,
    -- el transceptor mantiene BUSY activo mientras procesa el comando. La MEF
    -- debe esperar su liberacion antes de comenzar el frame siguiente.
    sx1262_busy_process : process
    begin
        sx1262_busy_i<='0';
        wait until falling_edge(rst);

        loop
            wait until rising_edge(spi_nss_o);
            sx1262_busy_i<='1';
            wait for 300 ns;
            sx1262_busy_i<='0';
        end loop;
    end process;

    -- Modelo de las respuestas SPI necesarias para probar RX. Para los demas
    -- comandos devuelve cero. Los bits se presentan LSB primero.
    sx1262_miso_process : process
        variable opcode : std_logic_vector(8-1 downto 0);
        variable response_byte : std_logic_vector(8-1 downto 0);
        variable byte_index : integer;
    begin
        spi_miso_i<='0';

        loop
            wait until falling_edge(spi_nss_o);
            opcode:=(others=>'0');

            -- Captura el opcode transmitido por el manager.
            for bit_index in 0 to 7 loop
                wait until rising_edge(spi_sclk_o);
                opcode(bit_index):=spi_mosi_o;
            end loop;

            byte_index:=1;

            while spi_nss_o='0' loop
                response_byte:=(others=>'0');

                if opcode=x"13" then
                    -- GetRxBufferStatus: status, length=5, offset=0x20.
                    case byte_index is
                        when 2 => response_byte:=x"05";
                        when 3 => response_byte:=x"20";
                        when others => null;
                    end case;
                elsif opcode=x"1E" then
                    -- ReadBuffer: tres bytes de protocolo y payload.
                    case byte_index is
                        when 3 => response_byte:=x"A1";
                        when 4 => response_byte:=x"B2";
                        when 5 => response_byte:=x"C3";
                        when 6 => response_byte:=x"D4";
                        when 7 => response_byte:=x"E5";
                        when others => null;
                    end case;
                end if;

                spi_miso_i<=response_byte(0);
                for bit_index in 0 to 7 loop
                    wait until rising_edge(spi_sclk_o) or spi_nss_o='1';
                    exit when spi_nss_o='1';
                    if bit_index<7 then
                        wait until falling_edge(spi_sclk_o);
                        spi_miso_i<=response_byte(bit_index+1);
                    end if;
                end loop;

                byte_index:=byte_index+1;
            end loop;

            spi_miso_i<='0';
        end loop;
    end process;

    stimulus : process

        -- Escribe una posicion del banco de configuracion durante un ciclo.
        procedure write_config(
            constant address_value : in integer;
            constant data_value : in std_logic_vector(32-1 downto 0)
        ) is
        begin
            config_addr_i<=std_logic_vector(to_unsigned(address_value,4));
            config_data_i<=data_value;
            config_wr_i<='1';
            wait until rising_edge(clk);
            config_wr_i<='0';
            wait until rising_edge(clk);
        end procedure;

        -- Captura un frame SPI modo 0. El driver transmite primero el bit 0.
        procedure check_spi_frame(
            constant expected : in byte_array_t;
            constant frame_name : in string
        ) is
            variable received_byte : std_logic_vector(8-1 downto 0);
        begin
            wait until falling_edge(spi_nss_o);

            for byte_index in expected'range loop
                received_byte:=(others=>'0');

                for bit_index in 0 to 7 loop
                    wait until rising_edge(spi_sclk_o);
                    received_byte(bit_index):=spi_mosi_o;
                end loop;

                assert received_byte=expected(byte_index)
                    report frame_name & ": byte " & integer'image(byte_index) &
                           " incorrecto. Recibido=" &
                           integer'image(to_integer(unsigned(received_byte))) &
                           ", esperado=" &
                           integer'image(to_integer(unsigned(expected(byte_index))))
                    severity failure;
            end loop;

            wait until rising_edge(spi_nss_o);
        end procedure;

    begin
        wait until falling_edge(rst);
        wait until rising_edge(clk);

        -- Valores identificables para comprobar el orden de todos los bytes.
        write_config(0,  x"12345678"); -- RF frequency ya codificada.
        write_config(1,  x"00000007"); -- Spreading factor.
        write_config(2,  x"00000004"); -- Bandwidth.
        write_config(3,  x"00000001"); -- Coding rate.
        write_config(4,  x"00001234"); -- Preamble length.
        write_config(5,  x"00000000"); -- Header explicito.
        write_config(6,  x"00000001"); -- CRC habilitado.
        write_config(7,  x"00000000"); -- IQ normal.
        write_config(8,  x"00000016"); -- TX power.
        write_config(10, x"00001234"); -- TX timeout de 24 bits.
        write_config(11, x"00000001"); -- Low data rate optimization.

        -- Solicita la secuencia completa de configuracion.
        command_i<="010";
        start_i<='1';
        wait until rising_edge(clk);
        start_i<='0';

        check_spi_frame((x"80", x"00"),
                        "SetStandby");
        check_spi_frame((x"8A", x"01"),
                        "SetPacketType");
        check_spi_frame((x"86", x"12", x"34", x"56", x"78"),
                        "SetRfFrequency");
        check_spi_frame((x"8E", x"16", x"04"),
                        "SetTxParams");
        check_spi_frame((x"8B", x"07", x"04", x"01", x"01"),
                        "SetModulationParams");
        check_spi_frame((x"8C", x"12", x"34", x"00", x"32", x"01", x"00"),
                        "SetPacketParams");
        check_spi_frame((x"8F", x"00", x"00"),
                        "SetBufferBaseAddress");

        -- NSS sube al terminar el ultimo frame; la MEF necesita luego sus
        -- ciclos de reloj para pasar por COMMAND_DONE y regresar a IDLE.
        if busy_o='1' then
            wait until busy_o='0' for 1 us;
        end if;

        assert busy_o='0'
            report "El manager continuo ocupado despues de la configuracion"
            severity failure;

        assert done_o='1'
            report "El manager no genero done al completar la configuracion"
            severity failure;

        assert error_o='0'
            report "El manager informo error durante la configuracion"
            severity failure;

        report "Secuencia de configuracion SX1262 verificada correctamente"
            severity note;

        -- Deja que COMMAND_DONE regrese a IDLE antes del comando siguiente.
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        ----------------------------------------------------------------------
        -- Prueba del comando TX con un payload de cuatro bytes.
        ----------------------------------------------------------------------
        write_info_i<=(others=>'0');
        write_info_i(7 downto 0)<=x"41";
        write_info_i(15 downto 8)<=x"42";
        write_info_i(23 downto 16)<=x"43";
        write_info_i(31 downto 24)<=x"44";
        write_length_i<=4;
        command_i<="011";
        start_i<='1';
        wait until rising_edge(clk);
        start_i<='0';

        check_spi_frame((x"0E", x"00", x"41", x"42", x"43", x"44"),
                        "TxWriteBuffer");
        check_spi_frame((x"8C", x"12", x"34", x"00", x"04", x"01", x"00"),
                        "TxSetPacketParams");
        check_spi_frame((x"83", x"00", x"12", x"34"),
                        "TxSetTx");

        -- Aunque finalizaron los frames SPI, TX no termina hasta recibir
        -- DIO1, que representa la interrupcion TxDone del SX1262.
        wait for 500 ns;
        assert busy_o='1' and done_o='0'
            report "TX termino antes de recibir DIO1"
            severity failure;

        sx1262_dio1_i<='1';
        wait until done_o='1' for 2 us;

        assert done_o='1'
            report "El manager no genero done despues de DIO1"
            severity failure;

        sx1262_dio1_i<='0';

        assert error_o='0'
            report "El manager informo error durante TX"
            severity failure;

        report "Secuencia TX del SX1262 verificada correctamente"
            severity note;

        -- Deja que COMMAND_DONE vuelva a IDLE.
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        ----------------------------------------------------------------------
        -- Prueba RX. El modelo devuelve cinco bytes desde el offset 0x20.
        ----------------------------------------------------------------------
        read_length_i<=MAX_DATA_BYTES;
        command_i<="100";
        start_i<='1';
        wait until rising_edge(clk);
        start_i<='0';

        check_spi_frame((x"82", x"FF", x"FF", x"FF"),
                        "RxSetRxContinuous");

        -- Sin DIO1 el manager debe permanecer esperando indefinidamente.
        wait for 500 ns;
        assert busy_o='1' and done_o='0'
            report "RX termino sin recibir DIO1"
            severity failure;

        sx1262_dio1_i<='1';

        check_spi_frame((x"13", x"00", x"00", x"00"),
                        "RxGetBufferStatus");
        check_spi_frame((x"1E", x"20", x"00", x"00", x"00", x"00",
                         x"00", x"00"),
                        "RxReadBuffer");
        check_spi_frame((x"02", x"FF", x"FF"),
                        "RxClearIrqStatus");

        wait until done_o='1' for 2 us;

        assert done_o='1' and read_valid_o='1'
            report "El manager no valido la informacion recibida"
            severity failure;

        assert read_length_o=5
            report "La longitud RX recuperada no es 5"
            severity failure;

        assert read_info_o(39 downto 0)=x"E5D4C3B2A1"
            report "El payload RX recuperado es incorrecto"
            severity failure;

        sx1262_dio1_i<='0';

        report "Secuencia RX del SX1262 verificada correctamente"
            severity note;

        wait for 100 ns;
        wait;
    end process;

end Behavioral;
