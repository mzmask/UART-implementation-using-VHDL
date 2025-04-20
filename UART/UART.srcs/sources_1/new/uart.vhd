library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart is
    generic (
        Parity      : string := "Even";
        StopBits    : integer := 1;
        ClockFreq   : integer := 100_000_000;   -- 100MHz -> 10ns
        BaudRate    : integer                   -- 19.2KHz -> 58083.3ns
    );
    Port (
        Clk         : in std_logic;
        Rst         : in std_logic;
        InputData   : in std_logic_vector(7 downto 0);
        InputValid  : in std_logic;
        OutputData  : out std_logic_vector(7 downto 0);
        OutputValid : out std_logic;
        Error       : out std_logic;
        Rx          : in std_logic;
        Tx          : out std_logic
    );
end uart;

architecture Behavioral of uart is

begin



end Behavioral;
