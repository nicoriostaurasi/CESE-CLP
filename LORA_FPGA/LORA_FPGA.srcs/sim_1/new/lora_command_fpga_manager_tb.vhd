----------------------------------------------------------------------------------
-- Testbench del top lora_command_fpga_manager.
-- Un transmisor UART envia comandos al top y un receptor UART verifica sus
-- respuestas. Las entradas del bus SPI se mantienen fijas en este test.
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

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- UART que representa a la PC.
    signal pc_data_wr : std_logic := '0';
    signal pc_data_tx : std_logic_vector(7 downto 0) := (others=>'0');
    signal pc_tx_ready : std_logic;
    signal pc_uart_tx : std_logic;
    signal pc_data_rd : std_logic;
    signal pc_data_rx : std_logic_vector(7 downto 0);
    signal pc_uart_rx : std_logic;

    -- Entradas y salidas del top.
    signal spi_sclk : std_logic;
    signal spi_mosi : std_logic;
    signal spi_nss : std_logic;
    signal spi_miso : std_logic := '0';
    signal sx1278_reset : std_logic;
    signal status_led : std_logic_vector(4-1 downto 0);
    signal sx1278_dio0 : std_logic := '0';
    signal rx_test_active : std_logic := '0';

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
            uart_tx_o => pc_uart_rx,
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

    -- Receptor UART: decodifica el ACK o NACK enviado por el top.
    pc_uart_receiver : entity work.uart_rx
        generic map (
            baudRate => UART_BAUDRATE,
            sysClk => CLK_FREQ_HZ,
            dataSize => 8
        )
        port map (
            clk => clk,
            rst => rst,
            dataRd => pc_data_rd,
            dataRx => pc_data_rx,
            rx => pc_uart_rx
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

    -- Modelo minimo del MISO del SX1278 para la secuencia de recepcion.
    -- Primero devuelve un paquete con CRC incorrecto. Luego de que el manager
    -- rearma RXSINGLE entrega longitud 3, direccion FIFO 0 y el payload "ABC".
    rx_spi_model : process
        variable frame_index : integer := 0;
        variable response_frame : std_logic_vector(16-1 downto 0);
    begin
        wait until rx_test_active='1';

        loop
            wait until falling_edge(spi_nss);

            case frame_index is
                when 3 => response_frame:=x"0020";
                when 6 => response_frame:=x"0040";
                when 7 => response_frame:=x"0003";
                when 8 => response_frame:=x"0000";
                when 10 => response_frame:=x"0041";
                when 11 => response_frame:=x"0042";
                when 12 => response_frame:=x"0043";
                when others => response_frame:=(others=>'0');
            end case;

            spi_miso<=response_frame(16-1);
            for bit_index in 16-1 downto 0 loop
                wait until rising_edge(spi_sclk);
                if bit_index>0 then
                    wait until falling_edge(spi_sclk);
                    spi_miso<=response_frame(bit_index-1);
                end if;
            end loop;

            wait until rising_edge(spi_nss);
            spi_miso<='0';
            frame_index:=frame_index+1;
        end loop;
    end process;

    stimulus : process

        procedure send_uart_byte(constant value : std_logic_vector(7 downto 0)) is
        begin
            pc_data_tx<=value;
            wait until rising_edge(clk);
            pc_data_wr<='1';
            wait until rising_edge(clk);
            pc_data_wr<='0';
            wait until rising_edge(pc_tx_ready);
            wait until rising_edge(clk);
        end procedure;

        procedure expect_uart_byte(
            constant expected : std_logic_vector(7 downto 0);
            constant message_text : string) is
        begin
            wait until rising_edge(pc_data_rd) for 150 us;
            assert pc_data_rd='1'
                report "Timeout: " & message_text
                severity failure;
            assert pc_data_rx=expected
                report message_text & ". Recibido=" &
                       integer'image(to_integer(unsigned(pc_data_rx))) &
                       ", esperado=" &
                       integer'image(to_integer(unsigned(expected)))
                severity error;
        end procedure;

        procedure send_uart_frame(
            constant command_value : std_logic_vector(7 downto 0);
            constant parameter_value : std_logic_vector(7 downto 0);
            constant data_value : std_logic_vector(7 downto 0)) is
        begin
            send_uart_byte(UART_FRAME_START);
            send_uart_byte(command_value);
            send_uart_byte(parameter_value);
            send_uart_byte(data_value);
            send_uart_byte(command_value xor parameter_value xor data_value);
            send_uart_byte(UART_FRAME_END);
        end procedure;

        procedure send_uart_frame_bad_checksum(
            constant command_value : std_logic_vector(7 downto 0);
            constant parameter_value : std_logic_vector(7 downto 0);
            constant data_value : std_logic_vector(7 downto 0)) is
        begin
            send_uart_byte(UART_FRAME_START);
            send_uart_byte(command_value);
            send_uart_byte(parameter_value);
            send_uart_byte(data_value);
            send_uart_byte(not (command_value xor parameter_value xor data_value));
            send_uart_byte(UART_FRAME_END);
        end procedure;

        procedure send_uart_frame_bad_end(
            constant command_value : std_logic_vector(7 downto 0);
            constant parameter_value : std_logic_vector(7 downto 0);
            constant data_value : std_logic_vector(7 downto 0)) is
        begin
            send_uart_byte(UART_FRAME_START);
            send_uart_byte(command_value);
            send_uart_byte(parameter_value);
            send_uart_byte(data_value);
            send_uart_byte(command_value xor parameter_value xor data_value);
            send_uart_byte(x"25");
        end procedure;

        procedure expect_uart_response(
            constant command_value : std_logic_vector(7 downto 0);
            constant status_value : std_logic_vector(7 downto 0);
            constant data_value : std_logic_vector(7 downto 0)) is
        begin
            report "Esperando respuesta UART del command_decoder"
                severity note;
            expect_uart_byte(UART_FRAME_START,
                             "Falta el delimitador inicial de respuesta");
            expect_uart_byte(command_value,
                             "La respuesta devolvio otro comando");
            expect_uart_byte(status_value,
                             "La respuesta devolvio otro estado");
            expect_uart_byte(data_value,
                             "La respuesta devolvio otro dato");
            expect_uart_byte(command_value xor status_value xor data_value,
                             "Checksum incorrecto en la respuesta");
            expect_uart_byte(UART_FRAME_END,
                             "Falta el delimitador final de respuesta");
        end procedure;

    begin
        wait until falling_edge(rst);
        wait for 5*CLK_PERIOD;

        -- Una trama alterada debe rechazarse sin ejecutar el comando.
        send_uart_frame_bad_checksum(CMD_CONFIG_WRITE,x"05",x"07");
        expect_uart_response(CMD_CONFIG_WRITE,UART_NACK,x"00");

        -- Un delimitador final corrupto tambien debe informar NACK al host.
        send_uart_frame_bad_end(CMD_CONFIG_WRITE,x"05",x"07");
        expect_uart_response(CMD_CONFIG_WRITE,UART_NACK,x"00");

        -- Misma configuracion enviada por lora_uart_commands.py.
        send_uart_frame(CMD_CONFIG_WRITE,x"00",x"6C");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"6C");
        send_uart_frame(CMD_CONFIG_WRITE,x"01",x"40");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"40");
        send_uart_frame(CMD_CONFIG_WRITE,x"02",x"00");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"00");
        send_uart_frame(CMD_CONFIG_WRITE,x"03",x"07");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"07");
        send_uart_frame(CMD_CONFIG_WRITE,x"04",x"01");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"01");
        send_uart_frame(CMD_CONFIG_WRITE,x"05",x"07");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"07");
        send_uart_frame(CMD_CONFIG_WRITE,x"08",x"0E");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"0E");
        send_uart_frame(CMD_CONFIG_WRITE,x"06",x"00");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"00");
        send_uart_frame(CMD_CONFIG_WRITE,x"07",x"08");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"08");
        send_uart_frame(CMD_CONTROL,CTRL_APPLY_CONFIG,x"00");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"00");

        -- Primera transmision: "SOL".

        send_uart_frame(CMD_CONTROL,CTRL_TX_BEGIN,x"00");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"00");
        send_uart_frame(CMD_TX_WRITE,x"00",x"53");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"53");
        send_uart_frame(CMD_TX_WRITE,x"01",x"4F");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"4F");
        send_uart_frame(CMD_TX_WRITE,x"02",x"4C");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"4C");
        send_uart_frame(CMD_CONTROL,CTRL_TX_START,x"03");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"03");
        -- DIO0 se activa despues de que la MEF completo la carga SPI.
        wait for 20 us;
        sx1278_dio0<='1';
        wait for 1 us;
        sx1278_dio0<='0';
        wait for 20 us;

        -- Segunda transmision consecutiva: "ING NRT".
        send_uart_frame(CMD_CONTROL,CTRL_TX_BEGIN,x"00");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"00");
        send_uart_frame(CMD_TX_WRITE,x"00",x"49");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"49");
        send_uart_frame(CMD_TX_WRITE,x"01",x"4E");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"4E");
        send_uart_frame(CMD_TX_WRITE,x"02",x"47");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"47");
        send_uart_frame(CMD_TX_WRITE,x"03",x"20");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"20");
        send_uart_frame(CMD_TX_WRITE,x"04",x"4E");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"4E");
        send_uart_frame(CMD_TX_WRITE,x"05",x"52");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"52");
        send_uart_frame(CMD_TX_WRITE,x"06",x"54");
        expect_uart_response(CMD_TX_WRITE,UART_ACK,x"54");
        send_uart_frame(CMD_CONTROL,CTRL_TX_START,x"07");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"07");
        wait for 20 us;
        sx1278_dio0<='1';
        wait for 1 us;
        sx1278_dio0<='0';
        wait for 20 us;

        -- Solicita un paquete. El ACK llega luego de configurar RXSINGLE.
        rx_test_active<='1';
        send_uart_frame(CMD_CONTROL,CTRL_RX_START,x"00");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"00");

        -- El primer RxDone informa CRC incorrecto. No debe generar un evento
        -- UART y el manager debe volver a activar RXSINGLE internamente.
        sx1278_dio0<='1';
        wait for 1 us;
        sx1278_dio0<='0';
        wait for 20 us;

        -- El segundo RxDone corresponde al paquete valido "ABC" y no requiere
        -- una nueva peticion RX_START desde el host.
        sx1278_dio0<='1';
        wait for 1 us;
        sx1278_dio0<='0';

        expect_uart_byte(UART_FRAME_START,
                         "Falta inicio del evento RX_PACKET");
        expect_uart_byte(UART_EVENT_RX_PACKET,
                         "No se recibio el evento RX_PACKET");
        expect_uart_byte(x"03",
                         "Longitud incorrecta en RX_PACKET");
        expect_uart_byte(x"41","Primer byte RX automatico incorrecto");
        expect_uart_byte(x"42","Segundo byte RX automatico incorrecto");
        expect_uart_byte(x"43","Tercer byte RX automatico incorrecto");
        expect_uart_byte(x"C3","Checksum incorrecto en RX_PACKET");
        expect_uart_byte(UART_FRAME_END,
                         "Falta fin del evento RX_PACKET");

        -- RESET_PERIPH debe cancelar una recepcion que permanece esperando
        -- DIO0. Luego del reset el controlador debe aceptar comandos nuevos.
        send_uart_frame(CMD_CONTROL,CTRL_RX_START,x"00");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"00");
        send_uart_frame(CMD_CONTROL,CTRL_RESET_PERIPH,x"00");
        expect_uart_response(CMD_CONTROL,UART_ACK,x"00");
        wait for 2 ms;
        send_uart_frame(CMD_CONFIG_WRITE,CFG_SPREADING_FACTOR_ADDR,x"07");
        expect_uart_response(CMD_CONFIG_WRITE,UART_ACK,x"07");

        report "UART verificada: CONFIG, TX, RX y cancelacion de RX mediante RESET correctos"
            severity note;

        wait for 100 ns;
        std.env.stop;
        wait;
    end process;

end Behavioral;
