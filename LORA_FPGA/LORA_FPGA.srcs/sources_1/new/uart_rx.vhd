----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.09.2024 15:49:55
-- Design Name: 
-- Module Name: uart_rx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Receptor UART parametrizable. Detecta el bit de inicio,
--              muestrea una trama de dataSize bits y genera dataRd durante
--              un ciclo cuando dataRx contiene un byte completo.
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

entity uart_rx is
    Generic (baudRate : integer := 9600;
             sysClk : integer := 100000000;
             dataSize : integer := 8);
    Port (
           -- Reloj principal utilizado para temporizar cada bit.
           clk : in std_logic;
           -- Reset sincrono del receptor.
           rst : in std_logic;
           -- Pulso que indica que dataRx contiene una palabra nueva.
           dataRd : out std_logic;
           -- Palabra paralela reconstruida desde la linea serie.
           dataRx : out std_logic_vector(dataSize-1 downto 0);
           -- Linea serie asincronica de entrada.
           rx : in std_logic);
end uart_rx;

architecture Behavioral of uart_rx is
    constant N_baudrate : integer := integer(ceil(log2(real (sysClk/baudRate))));
    constant N_datasize : integer := integer(ceil(log2(real (dataSize+1))));
    signal baudrate_counter : unsigned(N_baudrate-1 downto 0);
    constant SysClk_BaudRate : unsigned (N_baudrate-1 downto 0) := to_unsigned((SysClk/baudrate)-1, N_baudrate);
    signal data_read_Counter: unsigned(N_datasize-1 downto 0);
    signal tc_baudrate_signal: std_logic; 
    signal receiving_flag: std_logic;     
    signal reinicio_signal: std_logic; 
    signal reg_data_tx,uart_data_reg: std_logic_vector(dataSize+2-1 downto 0);
begin
    
    my_uart_port_shift_reg: process(clk)
    begin
        if (rising_edge(clk)) then
            if(rst='1') then
                uart_data_reg<=(others=>'1');
            else
                if(tc_baudrate_signal='1') then
                    uart_data_reg<=rx & uart_data_reg(dataSize+2-1 downto 1);
                end if;
            end if;
        end if;                        
    end process;
    
    my_data_counter: process(clk)
    begin
        if(rising_edge(clk)) then
            if (rst='1') then
                reinicio_signal<='1';           
                data_read_Counter<=to_unsigned(0,N_datasize); 
                receiving_flag<='0';
                dataRd<='0';
                dataRx<=(others=>'0');
            else
                if (rx = '0' and receiving_flag ='0') then
                    data_read_Counter<=to_unsigned(0,N_datasize);     
                    reinicio_signal<='1';           
                    receiving_flag<='1';
                end if;                
                
                if (receiving_flag ='1') then
                    if(tc_baudrate_signal='1') then          
                        data_read_Counter<= data_read_Counter+1;
                    end if;  
                end if;                

                if (data_read_Counter>= (dataSize+2)) then
                    data_read_Counter<=to_unsigned(0,N_datasize);                     
                    receiving_flag<='0';
                    dataRd<='1';
                    dataRx<=uart_data_reg(dataSize+2-2 downto 1);
                else
                    dataRd<='0';                
                    reinicio_signal<='0';
                end if;
            end if;
        end if;            
    end process;
    
    my_baud_rate_counter: process(clk)
    begin
        if(rising_edge(clk)) then
            if (rst='1' or reinicio_signal='1') then
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
