--------------------------------------------------------------------------------
-- TESTBENCH para entity myUartTx
-- 
-- Tiempos de simulacion:
-- +-----------------------------------------+
-- | fclk = 50 MHz                           |
-- | Tclk = 20 ns                            |
-- | baud rate = 1,25 MHz                    |
-- | tiempo bit = 800 ns = 40*Tclk           |
-- | Tiempo total de simulacion = 34,6 us    |
-- +-----------------------------------------+
-------------------------------------------------------------------------------- 
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY uartTx_tb IS
END uartTx_tb;
 
ARCHITECTURE behavior OF uartTx_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
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
   signal rst : std_logic := '1';
   signal dataWr : std_logic := '0';
   signal dataTx: std_logic_vector(7 downto 0) := (others => '0');

 	--Outputs
   signal tx : std_logic;
   signal ready : std_logic;

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
    -- User print
   type t_user_print is (holdeo_rst, Primera_trama_AA, Segunda_trama_00, Tercera_trama_FF, Cuarta_trama_55, Fin);
   signal signal_salida: t_user_print;

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: uart_tx
   GENERIC MAP ( baudRate => 1250000,  -- tiempo bit = 40*Tclk
			     sysClk => 50000000,   -- Tclk = 20ns
                 dataSize => 8 )
   PORT MAP ( clk => clk,
              rst => rst,
              dataWr => dataWr,
              dataTx=> dataTx,
              tx => tx,
              ready => ready );

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
        -- holdeo el rst
        signal_salida<= holdeo_rst;
        wait until falling_edge(rst);		

        -- transmito 0xAA 0 1010 1010 1
        wait for clk_period*5;
        signal_salida<= Primera_trama_AA;
        dataWr<='1';
        dataTx<=x"aa";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(ready);

        -- transmito 0x00 0 0000 0000 1
        wait for clk_period*5;
        signal_salida<= Segunda_trama_00;
        dataWr<='1';
        dataTx<=x"00";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(ready);

        -- transmito 0xFF 0 1111 1111 1
        wait for clk_period*5;
        signal_salida<= Tercera_trama_FF;
        dataWr<='1';
        dataTx<=x"FF";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(ready);

        -- transmito 0x55 0 0101 0101 1
        wait for clk_period*5;
        signal_salida<= Cuarta_trama_55;
        dataWr<='1';
        dataTx<=x"55";
        wait for clk_period*5;
        dataWr<='0';
        dataTx<=x"00";                
        wait until falling_edge(ready);
        signal_salida<= Fin;

        wait;
   end process;

END;