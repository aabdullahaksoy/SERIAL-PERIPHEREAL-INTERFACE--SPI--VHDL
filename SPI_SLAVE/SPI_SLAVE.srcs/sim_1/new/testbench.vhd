
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;

entity testbench is
GENERIC(           
g_CLKFREQ               : INTEGER := 50_000_000;     
g_NUMBER_OF_BIT         : NATURAL := 8; -- USER LOGIC DATA 
g_NUM_OF_BIT_OF_ADDR    : NATURAL := 2  -- USER LOGIC ADDRESS
);
end testbench;

architecture Behavioral of testbench is
component main is
GENERIC(           
g_CLKFREQ               : INTEGER := 50_000_000;     
g_NUMBER_OF_BIT         : NATURAL := 8; -- USER LOGIC DATA 
g_NUM_OF_BIT_OF_ADDR    : NATURAL := 2  -- USER LOGIC ADDRESS
);
PORT(
----- USER LOGIC PORTS ---------
i_SLAVE_CLK           : IN STD_LOGIC;  -- SLAVE SYSTEM CLOCK
i_ASYNC_RST_BAR     : IN STD_LOGIC; -- ACTIVE LOW
i_WRITE_BUS         : IN STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
o_READ_BUS          : OUT STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
i_ADDR              : IN STD_LOGIC_VECTOR(g_NUM_OF_BIT_OF_ADDR - 1  DOWNTO 0);
i_WRITE_EN_BAR      : IN STD_LOGIC; -- ACTIVE LOW   
i_READ_EN_BAR       : IN STD_LOGIC; -- ACTIVE LOW 
---- INTERFACE PORTS ------------
i_SPI_CLK           : IN STD_LOGIC;
i_MOSI              : IN STD_LOGIC_VECTOR(g_NUMBER_OF_BIT-1 DOWNTO 0) ; 
o_MISO              : OUT STD_LOGIC 

);
end component;
SIGNAL i_SLAVE_CLK           : STD_LOGIC := '0';
SIGNAL i_SPI_CLK             : STD_LOGIC := '0';
SIGNAL i_ASYNC_RST_BAR       : STD_LOGIC := '1';
SIGNAL i_WRITE_BUS           : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := X"00";      
SIGNAL o_READ_BUS            : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) ;     
SIGNAL i_ADDR                : STD_LOGIC_VECTOR(g_NUM_OF_BIT_OF_ADDR - 1  DOWNTO 0) := "00";
SIGNAL i_WRITE_EN_BAR        : STD_LOGIC := '1';
SIGNAL i_READ_EN_BAR         : STD_LOGIC := '1';
SIGNAL i_MOSI                : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT-1 DOWNTO 0) := x"FF" ;
SIGNAL o_MISO                : STD_LOGIC ;
CONSTANT PERIOD_SYS          : TIME := 20 NS ; -- SYSTEM CLOCK

SIGNAL r_COUNTER_SPI_CLK     : INTEGER RANGE 0 TO 8;


begin
DUT : main
GENERIC MAP(
g_CLKFREQ               =>     g_CLKFREQ            ,
g_NUMBER_OF_BIT         =>     g_NUMBER_OF_BIT      ,
g_NUM_OF_BIT_OF_ADDR    =>     g_NUM_OF_BIT_OF_ADDR 
)

PORT MAP(
i_SLAVE_CLK                 =>     i_SLAVE_CLK        ,
i_SPI_CLK                   =>     i_SPI_CLK        ,
i_ASYNC_RST_BAR             =>     i_ASYNC_RST_BAR  ,
i_WRITE_BUS                 =>     i_WRITE_BUS      ,
o_READ_BUS                  =>     o_READ_BUS       ,
i_ADDR                      =>     i_ADDR           ,
i_WRITE_EN_BAR              =>     i_WRITE_EN_BAR   ,
i_READ_EN_BAR               =>     i_READ_EN_BAR    ,
i_MOSI                      =>     i_MOSI           ,
o_MISO                      =>     o_MISO       
);



p_SLAVE_CLK_GEN : PROCESS BEGIN
i_SLAVE_CLK   <= '1';
WAIT FOR PERIOD_SYS/2;
i_SLAVE_CLK   <= '0';
WAIT FOR PERIOD_SYS/2;
END PROCESS p_SLAVE_CLK_GEN;

p_SPI_CLK_GEN : PROCESS(i_SLAVE_CLK)
VARIABLE TIMER : INTEGER RANGE 0 TO 20 := 0;
VARIABLE r_TEMP_SPI_CLK                : STD_LOGIC := '0';

BEGIN
    IF RISING_EDGE(i_SLAVE_CLK) THEN 
        IF r_COUNTER_SPI_CLK = 16 THEN
            i_SPI_CLK   <= '0';
        ELSE
            IF TIMER = 2 THEN 
                r_TEMP_SPI_CLK      := NOT(r_TEMP_SPI_CLK);
                i_SPI_CLK           <= r_TEMP_SPI_CLK;
                r_COUNTER_SPI_CLK   <= r_COUNTER_SPI_CLK + 1;
                TIMER           := 0;                             
            ELSE
                TIMER           := TIMER + 1;
            END IF;
        END IF ;
    END IF;
        
    
END PROCESS;


p_STIM : PROCESS BEGIN 
i_ASYNC_RST_BAR <= '0';
WAIT FOR PERIOD_SYS;
i_ASYNC_RST_BAR <= '1';

i_ADDR          <= "01";
WAIT FOR PERIOD_SYS;

i_WRITE_EN_BAR  <= '0';
i_READ_EN_BAR   <= '1';
i_WRITE_BUS     <= x"AB";

WAIT FOR PERIOD_SYS*20;
i_ADDR          <= "10";
i_READ_EN_BAR   <= '0';
WAIT ;
END PROCESS p_STIM;
end Behavioral;
