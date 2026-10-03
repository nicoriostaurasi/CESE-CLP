----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.09.2024 15:49:55
-- Design Name: 
-- Module Name: uart_tx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Transmisor UART parametrizable. Un pulso dataWr carga los bits
--              de inicio, datos y parada; ready indica durante un ciclo que
--              la trama completa termino de transmitirse.
-- 
-- Dependencies: Ninguna
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_tx is
    Generic (baudRate : integer := 9600;
             sysClk : integer := 100000000;
             dataSize : integer := 8);
    Port (
           -- Reloj principal utilizado para temporizar cada bit.
           clk : in std_logic;
           -- Reset sincrono del transmisor.
           rst : in std_logic;
           -- Pulso que carga e inicia la transmision de dataTx.
           dataWr : in std_logic;
           -- Palabra paralela que debe serializarse.
           dataTx : in std_logic_vector(dataSize-1 downto 0);
           -- Pulso generado al terminar el bit de parada.
           ready : out std_logic;
           -- Linea serie de salida.
           tx : out std_logic);
end uart_tx;

architecture Behavioral of uart_tx is
    constant N_baudrate : integer := integer(ceil(log2(real (sysClk/baudRate))));
    constant N_datasize : integer := integer(ceil(log2(real (dataSize+1))));
    signal baudrate_counter : unsigned(N_baudrate-1 downto 0);
    constant SysClk_BaudRate : unsigned (N_baudrate-1 downto 0) := to_unsigned((SysClk/baudrate)-1, N_baudrate);
    signal ready_Counter: unsigned(N_datasize-1 downto 0);
    signal tc_baudrate_signal: std_logic; 
    signal sending_flag: std_logic;     
    signal reinicio_signal: std_logic; 
    signal uart_data_reg: std_logic_vector(dataSize+2-1 downto 0);
begin
    
    my_uart_port_shift_reg: process(clk)
    begin
        if (rising_edge(clk)) then
            if(rst='1') then
                tx<='1';
                uart_data_reg<=(others=>'1');
            else
                -- La carga tiene prioridad sobre el desplazamiento. Si ambos
                -- pulsos coinciden, desplazar el registro anterior perderia
                -- el byte nuevo y desalinearia toda la trama UART.
                if (dataWr = '1') then
                    uart_data_reg<='1'&dataTx&'0';
                elsif(tc_baudrate_signal='1') then
                    uart_data_reg<='1' & uart_data_reg(dataSize+2-1 downto 1);
                end if;

                tx<=uart_data_reg(0);
            end if;
        end if;                        
    end process;
    
    my_data_counter: process(clk)
    begin
        if(rising_edge(clk)) then
            if (rst='1') then
                reinicio_signal<='1';           
                ready_Counter<=to_unsigned(0,N_datasize); 
                ready<='0';
                sending_flag<='0';
            else
                ready<='0';
                if (dataWr = '1') then
                    ready_Counter<=to_unsigned(0,N_datasize);     
                    reinicio_signal<='1';           
                    sending_flag<='1';
                elsif (sending_flag ='1') then
                    if(tc_baudrate_signal='1') then          
                        ready_Counter<= ready_Counter+1;
                    end if;  
                end if;                

                if (ready_Counter>= (dataSize+2)) then
                    ready_Counter<=to_unsigned(0,N_datasize);                     
                    ready<='1';
                    sending_flag<='0';
                else
                    reinicio_signal<='0';
                end if;
            end if;
        end if;            
    end process;
    
    my_baud_rate_counter: process(clk)
    begin
        if(rising_edge(clk)) then
            if (rst='1' or reinicio_signal='1' or dataWr='1') then
                baudrate_counter<=to_unsigned(0,N_baudRate);
                tc_baudrate_signal<='0';                
            else
                baudrate_counter<=baudrate_counter+1;
                tc_baudrate_signal<='0';
                if(baudrate_counter = (SysClk_BaudRate-1)) then
                    tc_baudrate_signal<='1';
                    baudrate_counter<=to_unsigned(0,N_baudRate);
                end if;
            end if;        
        end if;        
    end process;

end Behavioral;
