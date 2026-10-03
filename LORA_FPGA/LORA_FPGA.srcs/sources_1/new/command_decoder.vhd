----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 13.09.2026 12:50:19
-- Design Name:
-- Module Name: command_decoder - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Recibe y decodifica solicitudes UART
--              [#][COMANDO][PARAMETRO][VALOR][CHECKSUM][$].
--              Solo procesa la solicitud despues de recibir los seis bytes.
--              Genera ACK cuando la orden fue aceptada para su ejecucion y
--              NACK si es invalida o el controlador esta ocupado. La
--              recepcion LoRa no se consulta desde este bloque:
--              los paquetes se envian automaticamente mediante el
--              uart_response_serializer.
--              La MEF separa el registro de estado, los registros de datos,
--              la logica de estado futuro y la logica de salidas.
--
-- Dependencies: sx1278_controller_pkg, uart_command_pkg,
--               command_acceptance_validator
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sx1278_controller_pkg.all;
use work.uart_command_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity command_decoder is
    generic (
        MAX_DATA_BYTES : integer := 50
    );
    port (
        -- Reloj principal del decodificador.
        clk : in std_logic;
        -- Reset sincrono de la MEF y sus registros.
        rst : in std_logic;

        -- Interfaz con el receptor UART. data_rd indica un byte nuevo.
        -- Pulso de un ciclo que valida uart_data_rx_i.
        uart_data_rd_i : in std_logic;
        -- Ultimo byte recibido por UART.
        uart_data_rx_i : in std_logic_vector(8-1 downto 0);

        -- Handshake con el controlador del SX1278.
        -- Impide aceptar una orden nueva mientras el controlador esta ocupado.
        controller_busy_i : in std_logic;
        -- Indica que se esta ejecutando el pulso de reset del periferico.
        peripheral_reset_active_i : in std_logic;

        -- Escritura de los registros internos de configuracion.
        -- Pulso que habilita una escritura de configuracion.
        config_wr_ena_o : out std_logic;
        -- Direccion del parametro de configuracion.
        config_addr_o : out std_logic_vector(8-1 downto 0);
        -- Valor que se almacena en el parametro seleccionado.
        config_data_o : out std_logic_vector(8-1 downto 0);
        -- Pulso que solicita aplicar la configuracion por SPI.
        config_start_o : out std_logic;

        -- Control de la carga directa de la FIFO TX del SX1278.
        -- Byte que se incorpora al payload de transmision.
        tx_data_o : out std_logic_vector(8-1 downto 0);
        -- Pulso que valida tx_data_o.
        tx_data_valid_o : out std_logic;
        -- Pulso que inicia y vacia el buffer local de TX.
        tx_begin_o : out std_logic;
        -- Pulso que solicita transmitir el payload cargado.
        tx_start_o : out std_logic;

        -- Solicita la recepcion de un unico paquete.
        rx_start_o : out std_logic;

        -- Solicita el pulso de reset fisico del periferico.
        peripheral_reset_request_o : out std_logic;

        -- Respuesta: [#][CMD][ACK/NACK][DATO][CHECKSUM][$].
        -- Pulso que entrega una respuesta al serializador.
        response_start_o : out std_logic;
        -- Comando al que corresponde la respuesta.
        response_command_o : out std_logic_vector(8-1 downto 0);
        -- Resultado ACK o NACK de la solicitud.
        response_status_o : out std_logic_vector(8-1 downto 0);
        -- Dato asociado a la respuesta.
        response_data_o : out std_logic_vector(8-1 downto 0)
    );
end command_decoder;

architecture Behavioral of command_decoder is

    -- Se usa un estado por byte para que el receptor UART presente una
    -- interfaz sencilla: cada pulso uart_data_rd_i avanza exactamente un campo.
    -- ST_DECODE separa la recepcion de la ejecucion. El ACK confirma que la
    -- orden fue aceptada y lanzada; no espera la finalizacion de la secuencia.
    -- MEF de recepción de comandos. Primero encuadra los seis bytes de la
    -- solicitud; sólo después de recibir el delimitador final pasa a DECODE.
    -- Si el controlador esta ocupado, DECODE responde NACK para que el host
    -- reintente posteriormente. Diagrama:
    -- doc/diagrams/command_decoder_fsm.puml
    type t_state is (
        ST_WAIT_START,
        ST_WAIT_COMMAND,
        ST_WAIT_PARAMETER,
        ST_WAIT_VALUE,
        ST_WAIT_CHECKSUM,
        ST_WAIT_END,
        ST_DECODE,
        ST_RESPONSE
    );

    signal state_now : t_state;
    signal state_next : t_state;

    -- Registros Q y sus proximos valores D. Esta convencion deja visible que
    -- Q es el dato almacenado y D el valor combinacional del proximo ciclo.
    signal command_reg_q : std_logic_vector(8-1 downto 0);
    signal command_reg_d : std_logic_vector(8-1 downto 0);
    signal parameter_reg_q : std_logic_vector(8-1 downto 0);
    signal parameter_reg_d : std_logic_vector(8-1 downto 0);
    signal value_reg_q : std_logic_vector(8-1 downto 0);
    signal value_reg_d : std_logic_vector(8-1 downto 0);
    signal checksum_reg_q : std_logic_vector(8-1 downto 0);
    signal checksum_reg_d : std_logic_vector(8-1 downto 0);
    signal response_status_reg_q : std_logic_vector(8-1 downto 0);
    signal response_status_reg_d : std_logic_vector(8-1 downto 0);
    signal response_data_reg_q : std_logic_vector(8-1 downto 0);
    signal response_data_reg_d : std_logic_vector(8-1 downto 0);

    signal decoded_command_accepted : std_logic;
    signal controller_unavailable : std_logic;
    signal reset_command : std_logic;
    signal command_can_execute : std_logic;
    signal checksum_valid : std_logic;

begin

    -- Busy y reset activo representan la misma condicion desde el punto de
    -- vista del decoder: el SX1278 no puede comenzar otra operacion. Se agrupan
    -- en una unica señal para no repetir esa politica en la MEF.
    controller_unavailable<=controller_busy_i or peripheral_reset_active_i;

    -- RESET es la unica excepcion a busy: permite recuperar el periferico. La
    -- disponibilidad se decide aqui porque pertenece al comportamiento de la
    -- MEF y no a la validacion del contenido de la trama.
    reset_command<='1' when command_reg_q=CMD_CONTROL and parameter_reg_q=CTRL_RESET_PERIPH else '0';

    command_can_execute<=not controller_unavailable or reset_command;

    -- Se eligio XOR porque la trama posee tres bytes fijos y puede calcularse
    -- con poca logica. No reemplaza un CRC, pero detecta errores simples de la
    -- comunicacion UART y resulta suficiente para el alcance del diseño.
    checksum_valid<='1' when checksum_reg_q=(command_reg_q xor parameter_reg_q xor value_reg_q) else '0';

    -- El validador concentra las reglas semanticas de todos los comandos. El
    -- checksum y la disponibilidad se filtran directamente en ST_DECODE.
    command_acceptance_validator_inst : entity work.command_acceptance_validator
        port map (
            command_i => command_reg_q,
            parameter_i => parameter_reg_q,
            value_i => value_reg_q,
            command_accepted_o => decoded_command_accepted
        );

    -- Un unico proceso secuencial registra estado y datos. Esta decision evita
    -- repartir registros relacionados en varios procesos y deja toda la
    -- memoria del bloque concentrada en un solo lugar.
    register_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state_now<=ST_WAIT_START;
                command_reg_q<=(others=>'0');
                parameter_reg_q<=(others=>'0');
                value_reg_q<=(others=>'0');
                checksum_reg_q<=(others=>'0');
                response_status_reg_q<=UART_NACK;
                response_data_reg_q<=(others=>'0');
            else
                state_now<=state_next;
                command_reg_q<=command_reg_d;
                parameter_reg_q<=parameter_reg_d;
                value_reg_q<=value_reg_d;
                checksum_reg_q<=checksum_reg_d;
                response_status_reg_q<=response_status_reg_d;
                response_data_reg_q<=response_data_reg_d;
            end if;
        end if;
    end process;

    -- Logica combinacional del estado futuro. state_next conserva state_now
    -- por defecto, evitando latches y haciendo explicitas solo las transiciones.
    next_state_logic : process(state_now, uart_data_rd_i, uart_data_rx_i,
                               decoded_command_accepted,
                               checksum_valid,
                               command_can_execute)
    begin
        state_next<=state_now;

        case state_now is
            when ST_WAIT_START =>
                -- Todo byte ajeno a '#' se descarta. Esto permite recuperar el
                -- sincronismo sin timeout si el enlace comienza a mitad de trama.
                if uart_data_rd_i='1' and uart_data_rx_i=UART_FRAME_START then
                    state_next<=ST_WAIT_COMMAND;
                end if;

            when ST_WAIT_COMMAND =>
                if uart_data_rd_i='1' then
                    state_next<=ST_WAIT_PARAMETER;
                end if;

            when ST_WAIT_PARAMETER =>
                if uart_data_rd_i='1' then
                    state_next<=ST_WAIT_VALUE;
                end if;

            when ST_WAIT_VALUE =>
                if uart_data_rd_i='1' then
                    state_next<=ST_WAIT_CHECKSUM;
                end if;

            when ST_WAIT_CHECKSUM =>
                if uart_data_rd_i='1' then
                    state_next<=ST_WAIT_END;
                end if;

            when ST_WAIT_END =>
                -- Solo se decodifica una trama cerrada correctamente. Ante un
                -- delimitador incorrecto se responde NACK para que el host
                -- pueda detectar el error y reenviar la solicitud.
                if uart_data_rd_i='1' then
                    if uart_data_rx_i=UART_FRAME_END then
                        state_next<=ST_DECODE;
                    else
                        state_next<=ST_RESPONSE;
                    end if;
                end if;

            when ST_DECODE =>
                -- Tanto ACK como NACK se preparan en output_logic y se envian
                -- inmediatamente. El host reintentara si recibe NACK por busy.
                state_next<=ST_RESPONSE;

            when ST_RESPONSE =>
                state_next<=ST_WAIT_START;
        end case;
    end process;

    -- Logica combinacional de salidas y proximos valores D. Las asignaciones
    -- D<=Q conservan los registros y los ceros iniciales mantienen inactivos
    -- todos los strobes salvo en el estado que los genera.
    output_logic : process(state_now, command_reg_q, parameter_reg_q,
                           value_reg_q, checksum_reg_q,
                           response_status_reg_q, response_data_reg_q,
                           uart_data_rd_i, uart_data_rx_i,
                           checksum_valid, decoded_command_accepted,
                           command_can_execute)
    begin
        command_reg_d<=command_reg_q;
        parameter_reg_d<=parameter_reg_q;
        value_reg_d<=value_reg_q;
        checksum_reg_d<=checksum_reg_q;
        response_status_reg_d<=response_status_reg_q;
        response_data_reg_d<=response_data_reg_q;

        config_addr_o<=parameter_reg_q;
        config_data_o<=value_reg_q;
        tx_data_o<=value_reg_q;
        response_command_o<=command_reg_q;
        response_status_o<=response_status_reg_q;
        response_data_o<=response_data_reg_q;

        config_wr_ena_o<='0';
        config_start_o<='0';
        tx_data_valid_o<='0';
        tx_begin_o<='0';
        tx_start_o<='0';
        rx_start_o<='0';
        peripheral_reset_request_o<='0';
        response_start_o<='0';

        case state_now is
            when ST_WAIT_COMMAND =>
                -- Los campos se registran solo con data_rd. El estado ya indica
                -- que significado tiene el byte, por lo que no hace falta un contador.
                if uart_data_rd_i='1' then
                    command_reg_d<=uart_data_rx_i;
                end if;

            when ST_WAIT_PARAMETER =>
                if uart_data_rd_i='1' then
                    parameter_reg_d<=uart_data_rx_i;
                end if;

            when ST_WAIT_VALUE =>
                if uart_data_rd_i='1' then
                    value_reg_d<=uart_data_rx_i;
                end if;

            when ST_WAIT_CHECKSUM =>
                if uart_data_rd_i='1' then
                    checksum_reg_d<=uart_data_rx_i;
                end if;

            when ST_WAIT_END =>
                -- Si efectivamente llega un sexto byte pero no es '$', se
                -- prepara una respuesta negativa
                if uart_data_rd_i='1' and uart_data_rx_i/=UART_FRAME_END then
                    response_status_reg_d<=UART_NACK;
                    response_data_reg_d<=(others=>'0');
                end if;

            when ST_DECODE =>
                -- El orden conceptual es: integridad de trama, validez del
                -- comando y disponibilidad para ejecutarlo. Cualquier filtro
                -- fallido produce NACK sin activar salidas de control.
                if checksum_valid='1' and
                   decoded_command_accepted='1' and
                   command_can_execute='1' then
                    -- El ACK significa que la orden fue aceptada y que el pulso
                    -- de inicio se genero. No confirma el resultado del enlace SPI.
                    response_status_reg_d<=UART_ACK;
                    response_data_reg_d<=value_reg_q;

                    case command_reg_q is
                        when CMD_CONFIG_WRITE =>
                            config_wr_ena_o<='1';

                        when CMD_CONTROL =>
                            case parameter_reg_q is
                                when CTRL_APPLY_CONFIG =>
                                    config_start_o<='1';

                                when CTRL_RESET_PERIPH =>
                                    peripheral_reset_request_o<='1';

                                when CTRL_TX_BEGIN =>
                                    tx_begin_o<='1';

                                when CTRL_TX_START =>
                                    tx_start_o<='1';

                                when CTRL_RX_START =>
                                    rx_start_o<='1';

                                when others =>
                                    null;
                            end case;

                        when CMD_TX_WRITE =>
                            -- El dato se almacena en el buffer local. La MEF de TX
                            -- lo envia al SX1278 cuando recibe CTRL_TX_START.
                            tx_data_o<=value_reg_q;
                            tx_data_valid_o<='1';

                        when others =>
                            null;
                    end case;
                else
                    -- Incluye trama invalida y controlador ocupado.
                    response_status_reg_d<=UART_NACK;
                    response_data_reg_d<=(others=>'0');
                end if;

            when ST_RESPONSE =>
                -- response_start_o dura un ciclo; el serializador copia los
                -- campos registrados y se ocupa del timing de uart_tx.
                response_start_o<='1';

            when others =>
                null;
        end case;
    end process;

end Behavioral;
