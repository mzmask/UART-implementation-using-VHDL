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
        Clk         : in std_logic;             -- 100MHz clock
        Rst         : in std_logic;             -- active low reset
        Error       : out std_logic;
        
        ---- // TX ports
        Tx          : out std_logic;
        InputData   : in std_logic_vector(7 downto 0);
        InputValid  : in std_logic;
        TX_ready    : out std_logic;
        
        ---- // RX ports
        OutputData  : out std_logic_vector(7 downto 0);
        OutputValid : out std_logic;
        Rx          : in std_logic        
    );
end uart;

architecture Behavioral of uart is

-- Note: with 19.2KHz I should wait for 5208 clock cycles of 10ns to reach 52083ns (19.2KHz) baudrate!
constant c_baudRate_counter         : integer range 0 to 8191 := 5207;

---- ////////// TX signals
signal s_TX_ready                   : std_logic;
signal s_Tx_inputData               : std_logic_vector(7 downto 0);
signal s_Tx_inputData_index         : integer range 0 to 7;
signal s_TX_stateMachine            : std_logic_vector(2 downto 0);
signal s_TX_even_parity             : std_logic;

signal s_TX_baudRate_counter        : integer range 0 to 8191;
signal s_TX_baudRate_counter_flag   : std_logic;

signal s_Tx                         : std_logic;

---- ////////// RX signals
signal s_RX_outputData              : std_logic_vector(7 downto 0);
signal s_Rx_outputData_index        : integer range 0 to 7;
signal s_RX_outputData_valid        : std_logic;
signal s_RX_stateMachine            : std_logic_vector(2 downto 0);
signal s_RX_even_parity_calculated  : std_logic;
signal s_RX_parity                  : std_logic;
signal s_RX_error                   : std_logic;

signal s_RX_baudrate_counter        : integer range 0 to 8191;
signal s_RX_baudrate_counter_flag   : std_logic;



begin
    ---- ////////// RX process
    process(Clk)
    begin
        if rising_edge(Clk) then
            ---- ///// state machine
            if (Rst = '0') then
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
            
            ---- ///// buadrate counter
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
    
    Error               <= s_RX_error;
    OutputData          <= s_RX_outputData;
    OutputValid         <= s_RX_outputData_valid;
    
    
    ---- ////////// TX process
    process(Clk)
    begin
        if rising_edge(Clk) then
            ---- ///// state machine
            if (Rst = '0') then
                s_TX_stateMachine               <= "000"; -- reset state
            elsif (InputValid = '1') then
                s_TX_stateMachine               <= "001";
                s_Tx_inputData                  <= InputData;
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
            if (s_TX_stateMachine = "000" and InputValid = '0') then -- all data have been sent AND no data is available yet!
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
    
    TX_ready            <= s_TX_ready;
    Tx                  <= s_Tx;

    

end Behavioral;
