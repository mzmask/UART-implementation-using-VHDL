library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tb is
--  Port ( );
end uart_tb;

architecture Behavioral of uart_tb is

component uart is
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
end component;

signal Clk                  : std_logic;
signal Clk200               : std_logic;
signal Rst                  : std_logic;             -- active low reset
signal Error                : std_logic;

---- // TX ports
signal Tx                   : std_logic;
signal InputData            : std_logic_vector(7 downto 0);
signal InputValid           : std_logic;
    
---- // RX ports
signal OutputData           : std_logic_vector(7 downto 0);
signal OutputValid          : std_logic;
signal Rx                   : std_logic; 

-- // clock periods
constant CLK_PERIOD_100     : time := 10 ns;
constant CLK_PERIOD_200     : time := 5 ns;

-- // baudrate
signal Clk_baudrate         : std_logic;
constant BAUD_RATE          : time := 52080 ns;

-- // Rx sample
signal Rx_data              : std_logic_vector(7 downto 0) := "10101010";
signal Rx_data_even_parity  : std_logic := '0';

begin

    uut: uart
        port map (
            Clk200      => Clk200,
            Clk         => Clk,
            Rst         => Rst,
            Error       => Error,
    
            -- TX ports
            Tx          => Tx,
            InputData   => InputData,
            InputValid  => InputValid,
    
            -- RX ports
            OutputData  => OutputData,
            OutputValid => OutputValid,
            Rx          => Rx
        );
        
    ---- Clock generation
    clk_100_process: process
    begin
        Clk <= '0';
        wait for CLK_PERIOD_100/2;
        Clk <= '1';
        wait for CLK_PERIOD_100/2;
    end process;
    
    clk_200_process: process
    begin
        Clk200 <= '0';
        wait for CLK_PERIOD_200/2;
        Clk200 <= '1';
        wait for CLK_PERIOD_200/2;
    end process;
    
    clk_19200_process: process
    begin
        Clk_baudrate <= '0';
        wait for BAUD_RATE/2;
        Clk_baudrate <= '1';
        wait for BAUD_RATE/2;
    end process;
    
    tx_simulation: process
    begin
        InputValid              <= '0';
        wait for 5 ns;
        
        ---- Initialization
        Rst                     <= '1';
        InputValid              <= '0';
        wait for 150 ns;
        
        ---- TX simulation
        wait for 10 * CLK_PERIOD_200;
        InputData               <= "01010101";
        InputValid              <= '1';
        wait for CLK_PERIOD_200;
        InputValid              <= '0';
        
        ---- End simulation
        wait for 10 ms;
        assert false report "End of simulation" severity failure;
        
    end process tx_simulation;
    
    rx_simulation: process
    begin
        Rx                      <= '1';
        wait for 20 ns;
        
        ---- RX simulation
        Rx                      <= '0'; -- start bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data(0); -- first data bit 
        wait for BAUD_RATE;
        Rx                      <= Rx_data(1); -- second data bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data(2); -- third data bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data(3); -- forth data bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data(4); -- fifth data bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data(5); -- sixth data bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data(6); -- seventh data bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data(7); -- eighth data bit
        wait for BAUD_RATE;
        Rx                      <= Rx_data_even_parity; -- parity bit
        wait for BAUD_RATE;
        Rx                      <= '1'; -- stop bit
        wait for BAUD_RATE;
        
        ---- End simulation
        wait for 10 ms;
        assert false report "End of simulation" severity failure;
        
    end process rx_simulation;


end Behavioral;
