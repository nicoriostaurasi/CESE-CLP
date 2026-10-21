----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:59:14 10/31/2018 
-- Design Name: 
-- Module Name:    myUart - arch_myUart 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Wrapper UART full-duplex. Instancia un transmisor y un receptor
--              independientes que comparten reloj, reset y parametrizacion.
--
-- Dependencies: uart_tx, uart_rx
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library work;
use work.uart_tx;
use work.uart_rx;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity myUart is
    generic(baudRate:integer:=9600;
				sysClk  :integer:=50000000;
				dataSize:integer:=8);
	 Port (
           -- Reloj principal compartido por TX y RX.
           clk : in STD_LOGIC;
           -- Reset sincrono de ambos bloques UART.
           rst : in STD_LOGIC;
           -- Pulso que solicita transmitir dataTx.
           dataWr : in STD_LOGIC;
           -- Palabra paralela que se transmite por UART.
           dataTx : in STD_LOGIC_VECTOR(dataSize-1 downto 0);
           -- Pulso que indica el fin de la transmision.
           ready : out STD_LOGIC;
           -- Linea serie de salida.
           tx : out STD_LOGIC;
           -- Pulso que valida una nueva palabra recibida.
           dataRd : out STD_LOGIC;
           -- Palabra paralela recibida por UART.
           dataRx : out STD_LOGIC_VECTOR(dataSize-1 downto 0);
           -- Linea serie de entrada.
           rx : in STD_LOGIC);
end myUart;

architecture arch_myUart of myUart is
begin
	 my_tx: entity work.uart_tx
	 generic map(baudRate=>baudRate,
				sysClk=>sysClk,
				dataSize=>dataSize)
    Port map(clk=>clk,
           rst=>rst,
           dataWr=>dataWr,
           dataTx=>dataTx,
           ready=>ready,
           tx=>tx);
			  
	 my_rx: entity work.uart_rx
	 generic map(baudRate=>baudRate,
				sysClk=>sysClk,
				dataSize=>dataSize)
    Port map(clk=>clk,
           rst=>rst,
           dataRd=>dataRd,
           dataRx=>dataRx,
           rx=>rx);
end arch_myUart;
