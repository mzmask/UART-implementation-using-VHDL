library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity uart is
    generic (
        Parity      : string := "Even"; -- "Even", "Odd", "None"
        StopBits    : integer := 1;
        ClockFreq   : integer := 100_000_000;
        BaudRate    : integer := 19200
    );
    Port (
        Clk200          : in std_logic;                     -- 200MHz clock
        Clk             : in std_logic;                     -- 100MHz clock
        Rst             : in std_logic;                     -- 200MHz (active low reset)
        Error           : out std_logic;                    -- 200MHz
        
        ---- // TX ports
        Tx              : out std_logic;                    -- UART port
        InputData       : in std_logic_vector(7 downto 0);  -- 200MHz
        InputValid      : in std_logic;                     -- 200MHz
        
        ---- // RX ports
        OutputData      : out std_logic_vector(7 downto 0); -- 200MHz  
        OutputValid     : out std_logic;                    -- 200MHz
        Rx              : in std_logic                      -- UART port
    );
end uart;

architecture Behavioral of uart is

-- Note: with 19.2KHz I should wait for 5208 clock cycles of 10ns to reach 52083ns (19.2KHz) baudrate!
constant c_baudRate_counter         : integer range 0 to 8191 := 5207;

---- ////////// Reset (streching reset signal so 100MHz clock could read it!)
signal s_counter_Rst_strech         : integer range 0 to 4;
signal s_Rst_100                    : std_logic;

---- ////////// TX signals
-- 200MHz clock domain signals:
signal s_TX_FIFO_Full               : std_logic;
signal s_Rst_FIFO                   : std_logic;

COMPONENT CDC_FIFO
  PORT (
    rst         : IN STD_LOGIC;
    wr_clk      : IN STD_LOGIC;
    rd_clk      : IN STD_LOGIC;
    din         : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en       : IN STD_LOGIC;
    rd_en       : IN STD_LOGIC;
    dout        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full        : OUT STD_LOGIC;
    empty       : OUT STD_LOGIC;
    valid       : OUT STD_LOGIC
  );
END COMPONENT;

signal s_FIFO_readData              : std_logic_vector(7 downto 0);
signal s_FIFO_readData_valid        : std_logic;


-- 100 MHz clock domain signal:
signal s_TX_ready                   : std_logic;
signal s_Tx_inputData               : std_logic_vector(7 downto 0);
signal s_Tx_inputData_index         : integer range 0 to 7;
signal s_TX_stateMachine            : std_logic_vector(2 downto 0);
signal s_TX_even_parity             : std_logic;

signal s_TX_baudRate_counter        : integer range 0 to 8191;
signal s_TX_baudRate_counter_flag   : std_logic;

signal s_Tx                         : std_logic;


---- ////////// RX signals
-- 100 MHz clock domain signals:
signal s_RX_outputData              : std_logic_vector(7 downto 0);
signal s_Rx_outputData_index        : integer range 0 to 7;
signal s_RX_outputData_valid        : std_logic;
signal s_RX_stateMachine            : std_logic_vector(2 downto 0);
signal s_RX_even_parity_calculated  : std_logic;
signal s_RX_parity                  : std_logic;
signal s_RX_error                   : std_logic;

signal s_RX_baudrate_counter        : integer range 0 to 8191;
signal s_RX_baudrate_counter_flag   : std_logic;

-- 200MHz clock domain signals:
signal s_RX_outputData_reg          : std_logic_Vector(7 downto 0); -- one registering cause metastability
signal s_RX_outputData_valid_reg    : std_logic;                    -- one registering cause metastability
signal s_RX_error_reg               : std_logic;                    -- one registering cause metastability

signal s_RX_outputData_reg2         : std_logic_Vector(7 downto 0); -- second registering cause stable signal
signal s_RX_outputData_valid_reg2   : std_logic;                    -- second registering cause stable signal
signal s_RX_error_reg2              : std_logic;                    -- second registering cause stable signal

signal s_RX_outputData_valid_reg3   : std_logic;                    -- third registering for rising_edge detection
signal s_RX_error_reg3              : std_logic;                    -- third registering for rising_edge detection
 
begin
    --------------------------------------------------------------
    -------------- ////////// RX process \\\\\\\\\\ --------------
    --------------------------------------------------------------
    ---- //// 100MHz clock domain:
    process(Clk)
    begin
        if rising_edge(Clk) then
            -- // state machine
            if (s_Rst_100 = '0') then
                s_RX_stateMachine               <= "111";
            elsif (s_RX_stateMachine = "000") then -- idle state
                if (Rx = '0') then
                    s_RX_stateMachine               <= "001";
                end if;
            elsif (s_RX_stateMachine = "001") then -- validation state (start bit)
                if (s_RX_baudrate_counter_flag = '1') then
                    if (Rx = '0') then
                        s_RX_stateMachine               <= "010";
                    else
                        s_RX_stateMachine               <= "111";
                        s_RX_error                      <= '1';
                    end if;
                end if;
            elsif (s_RX_stateMachine = "010") then -- read 8bits data state
                if (s_RX_baudrate_counter_flag = '1') then
                    s_RX_outputData(s_Rx_outputData_index)   <= Rx;
                    s_RX_even_parity_calculated             <= s_RX_even_parity_calculated xor Rx;
                    if (s_Rx_outputData_index = 7) then
                        s_Rx_outputData_index           <= 0;
                        if (Parity = "None") then
                            s_RX_stateMachine               <= "100";
                        else
                            s_RX_stateMachine               <= "011";
                        end if;
                    else
                        s_Rx_outputData_index           <= s_Rx_outputData_index + 1;
                    end if;
                end if;
            elsif (s_RX_stateMachine = "011") then -- read parity state
                if (s_RX_baudrate_counter_flag = '1') then
                    s_RX_parity                     <= Rx;
                    s_RX_stateMachine               <= "100";
                end if;
            elsif (s_RX_stateMachine = "100") then -- read stop bit state
                if (s_RX_baudrate_counter_flag = '1') then
                    if (Rx = '1') then
                        s_RX_stateMachine               <= "101";
                        s_RX_error                      <= '0';
                    else
                        s_RX_stateMachine               <= "111";
                        s_RX_error                      <= '1';
                    end if;
                end if;
            elsif (s_RX_stateMachine = "101") then
                if ((s_RX_parity = s_RX_even_parity_calculated and Parity = "Even") or (s_RX_parity = not(s_RX_even_parity_calculated) and Parity = "Odd") or Parity = "None") then
                    s_RX_outputData_valid           <= '1';
                    s_RX_error                      <= '0';
                else
                    s_RX_outputData_valid           <= '0';
                    s_RX_error                      <= '1';
                end if;
                s_RX_stateMachine               <= "111"; -- reset state
            else -- reset state
                s_RX_stateMachine               <= "000";
                s_Rx_outputData_index           <= 0;
                s_RX_even_parity_calculated     <= '0';
                s_RX_outputData_valid           <= '0';
                s_RX_error                      <= '0';
            end if;
            
            -- // buadrate counter
            if (s_RX_stateMachine /= "000") then
                if (s_RX_baudRate_counter = c_baudRate_counter) then
                    s_RX_baudRate_counter           <= 0;
                else
                    s_RX_baudRate_counter           <= s_RX_baudRate_counter + 1;
                end if;
            else
                s_RX_baudRate_counter           <= 0;
            end if;
            
            if (s_RX_baudRate_counter = c_baudRate_counter / 2) then
                s_RX_baudrate_counter_flag      <= '1';
            else
               s_RX_baudrate_counter_flag       <= '0';
            end if; 
        end if;
    end process;
    
    ---- //// 200MHz clock domain:
    process(Clk200)
    begin
        if rising_edge(Clk200) then
            s_RX_outputData_reg             <= s_RX_outputData;
            s_RX_outputData_valid_reg       <= s_RX_outputData_valid;
            s_RX_error_reg                  <= s_RX_error;
            
            s_RX_outputData_reg2            <= s_RX_outputData_reg;
            s_RX_outputData_valid_reg2      <= s_RX_outputData_valid_reg;
            s_RX_error_reg2                 <= s_RX_error_reg;
            
            s_RX_outputData_valid_reg3      <= s_RX_outputData_valid_reg2;
            s_RX_error_reg3                 <= s_RX_error_reg2;
            
            if (s_RX_outputData_valid_reg2 = '1' and s_RX_outputData_valid_reg3 = '0') then -- rising_edge detection
                OutputValid                     <= '1';
                OutputData                      <= s_RX_outputData_reg2;
            else
                OutputValid                     <= '0';
                OutputData                      <= (others => '0'); -- don't care!
            end if;
            

        end if;
    end process;
    
    
    --------------------------------------------------------------
    ------------- ////////// Rst process \\\\\\\\\\ --------------
    --------------------------------------------------------------
    process(Clk200)
    begin
        if rising_edge(Clk200) then
            if (Rst = '0') then
                s_counter_Rst_strech                <= 3;
            else
                if (s_counter_Rst_strech > 0) then
                    s_counter_Rst_strech                <= s_counter_Rst_strech - 1;
                else
                    s_counter_Rst_strech                <= 0;
                end if;
            end if;
            
            if (s_counter_Rst_strech > 0) then
                s_Rst_100                           <= '0';
            else
                s_Rst_100                           <= '1';
            end if;
        end if;
    end process;      
    
    --------------------------------------------------------------
    ------------ ////////// Error process \\\\\\\\\\ -------------
    --------------------------------------------------------------
    process(Clk200)
    begin
        if rising_edge(Clk200) then
            if ((s_RX_error_reg2 = '1' and s_RX_error_reg3 = '0') or (s_TX_FIFO_Full = '1' and InputValid = '1')) then -- RX error or TX error
                Error                           <= '1';
            else
                Error                           <= '0';
            end if;
        end if;
    end process;   
    
    
    --------------------------------------------------------------
    -------------- ////////// TX process \\\\\\\\\\ --------------
    --------------------------------------------------------------
    s_Rst_FIFO          <= not(Rst);
    
    CDC_FIFO_Instant : CDC_FIFO
    PORT MAP (
        rst             => s_Rst_FIFO,
        wr_clk          => Clk200,
        rd_clk          => Clk,
        din             => InputData,
        wr_en           => InputValid,
        rd_en           => s_TX_ready,
        dout            => s_FIFO_readData,
        full            => s_TX_FIFO_Full,
        empty           => open,
        valid           => s_FIFO_readData_valid
    );
  
    process(Clk)
    begin
        if rising_edge(Clk) then
            ---- ///// state machine
            if (s_Rst_100 = '0') then
                s_TX_stateMachine               <= "000"; -- reset state
            elsif (s_FIFO_readData_valid = '1') then
                s_TX_stateMachine               <= "001";
                s_Tx_inputData                  <= s_FIFO_readData;
                s_TX_even_parity                <= '0';
            elsif (s_TX_stateMachine = "001") then -- send start bit state
                s_Tx                            <= '0';
                if (s_TX_baudRate_counter_flag = '1') then
                    s_TX_stateMachine               <= "010";
                end if;
            elsif (s_TX_stateMachine = "010") then -- send 8bits data state
                s_Tx                            <= s_Tx_inputData(s_Tx_inputData_index);
                if (s_TX_baudRate_counter_flag = '1') then
                    s_TX_even_parity                <= s_TX_even_parity xor s_Tx_inputData(s_Tx_inputData_index);
                    if (s_Tx_inputData_index = 7) then
                        s_Tx_inputData_index            <= 0;
                        if (Parity = "None") then
                            s_TX_stateMachine               <= "100";
                        else
                            s_TX_stateMachine               <= "011";
                        end if;
                    else
                        s_Tx_inputData_index            <= s_Tx_inputData_index + 1;
                    end if;
                end if;
            elsif (s_TX_stateMachine = "011") then -- send parity state
                if (Parity = "Even") then
                    s_Tx                            <= s_TX_even_parity;
                else -- (Parity = "Odd") then
                    s_Tx                            <= not(s_TX_even_parity);
                end if;
                
                if (s_TX_baudRate_counter_flag = '1') then
                    s_TX_stateMachine               <= "100";
                end if;
            elsif (s_TX_stateMachine = "100") then -- send stop bit state
                s_Tx                            <= '1';
                if (s_TX_baudRate_counter_flag = '1') then
                    s_TX_stateMachine               <= "000";
                end if;
            else
                s_Tx                            <= '1';
                s_TX_stateMachine               <= "000";
                s_Tx_inputData_index            <= 0;
                s_TX_even_parity                <= '0';
            end if;
            
            ---- //// Tx ready
            if (s_TX_stateMachine = "000" and s_FIFO_readData_valid = '0') then -- all data have been sent AND no data is available yet!
                s_TX_ready                          <= '1';
            else
                s_TX_ready                          <= '0';
            end if;
            
            
            ---- ///// baudrate counter
            if (s_TX_stateMachine /= "000") then
                if (s_TX_baudRate_counter = c_baudRate_counter) then
                    s_TX_baudRate_counter           <= 0;
                else
                    s_TX_baudRate_counter           <= s_TX_baudRate_counter + 1;
                end if;
            else
                s_TX_baudRate_counter           <= 0;
            end if;
            
            if (s_TX_baudRate_counter = c_baudRate_counter) then
                s_TX_baudRate_counter_flag      <= '1';
            else
               s_TX_baudRate_counter_flag       <= '0';
            end if; 
            
            
        end if;
    end process;
    
    Tx                  <= s_Tx;

end Behavioral;
