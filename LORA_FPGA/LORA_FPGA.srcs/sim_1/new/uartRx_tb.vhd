--------------------------------------------------------------------------------
-- TESTBENCH para entity myUartRx
-- 
-- Tiempos de simulacion:
-- +-----------------------------------------+
-- | fclk = 50 MHz                           |
-- | Tclk = 20 ns                            |
-- | baud rate = 1,25 MHz                    |
-- | tiempo bit = 800 ns = 40*Tclk           |
-- | Tiempo total de simulacion = 24,9 us    |
-- +-----------------------------------------+
-------------------------------------------------------------------------------- 
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
  
ENTITY myUartRx_tb IS
END myUartRx_tb;
 
ARCHITECTURE behavior OF myUartRx_tb IS 

	-- Component Declaration for the Unit Under Test (UUT)
    COMPONENT uart_rx
    GENERIC ( baudRate : integer;
              sysClk : integer;
              dataSize : integer );
    PORT ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           dataRd : out  STD_LOGIC;
           dataRx : out  STD_LOGIC_VECTOR (7 downto 0);
           rx : in  STD_LOGIC );
    END COMPONENT;
    
    COMPONENT uart_tx
    GENERIC( baudRate : integer;
             sysClk : integer;
             dataSize : integer );
    PORT( clk : IN  std_logic;
          rst : IN  std_logic;
          dataWr : IN  std_logic;
          dataTx : IN  std_logic_vector(dataSize - 1 downto 0);
          tx : OUT  std_logic;
          ready : OUT  std_logic );
    END COMPONENT;    

   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal rx : std_logic := '0';

 	--Outputs
   signal dataRx : std_logic_vector(7 downto 0);
   signal dataRd : std_logic;

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
   -- UART TX Signals
   signal dataWr : std_logic;
   signal dataTx : std_logic_vector(8-1 downto 0); 

    -- User print
   type t_user_print is (holdeo_rst, Primera_trama_AA, Segunda_trama_00, Tercera_trama_FF, Cuarta_trama_55, Fin);
   signal signal_salida: t_user_print;

BEGIN

   -- Instantiate the Source Test (ST)
   st: uart_tx
   GENERIC MAP ( baudRate => 1250000,  -- tiempo bit = 40*Tclk
			     sysClk => 50000000,   -- Tclk = 20ns
                 dataSize => 8 )
   PORT MAP ( clk => clk,
              rst => rst,
              dataWr => dataWr,
              dataTx=> dataTx,
              tx => rx,
              ready => open );
 
	-- Instantiate the Unit Under Test (UUT)
   uut: uart_rx
   GENERIC MAP ( baudRate => 1250000,  -- tiempo bit = 40*Tclk
                 sysClk => 50000000,   -- Tclk = 20ns
                 dataSize => 8 )
   PORT MAP ( clk => clk,
              rst => rst,
              rx => rx,
              dataRx => dataRx,
              dataRd => dataRd );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '1';
		wait for clk_period/2;
		clk <= '0';
		wait for clk_period/2;
   end process;
   
   -- Reset Process
   rst_process: process
   begin
        rst<='1';
        wait for clk_period*5;
        rst<='0';
        wait;
   end process;
   
   -- Stimulus process
   stim_proc: process
   begin		
        dataWr<='0';
        dataTx<=(others=>'0');
        -- holdeo el rst
        signal_salida<= holdeo_rst;
        wait until falling_edge(rst);		
    
        -- transmito 0xAA 0 1010 1010 1
        wait for clk_period*5;
        signal_salida<= Primera_trama_AA;
        dataWr<='1';
        dataTx<=x"AA";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(dataRd);

        -- transmito 0x00 0 0000 0000 1
        wait for clk_period*5;
        signal_salida<= Segunda_trama_00;
        dataWr<='1';
        dataTx<=x"00";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(dataRd);

        -- transmito 0xFF 0 1111 1111 1
        wait for clk_period*5;
        signal_salida<= Tercera_trama_FF;
        dataWr<='1';
        dataTx<=x"FF";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(dataRd);

        -- transmito 0x55 0 0101 0101 1
        wait for clk_period*5;
        signal_salida<= Cuarta_trama_55;
        dataWr<='1';
        dataTx<=x"55";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(dataRd);
        signal_salida<= Fin;    
    
   wait;
   end process;
end;