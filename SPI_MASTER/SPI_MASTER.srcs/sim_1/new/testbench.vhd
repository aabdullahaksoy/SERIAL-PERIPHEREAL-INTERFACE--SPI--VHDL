

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

entity serial_peripheral_interface_TB is
GENERIC(
g_CLKFREQ               : INTEGER := 100_000_000;                
g_NUMBER_OF_BIT         : NATURAL := 8;
g_NUM_OF_BIT_OF_ADDR    : NATURAL := 2
);
end serial_peripheral_interface_TB;

architecture Behavioral of serial_peripheral_interface_TB is

component serial_peripheral_interface is
GENERIC(
g_CLKFREQ               : INTEGER := 100_000_000;                
g_NUMBER_OF_BIT         : NATURAL := 8;
g_NUM_OF_BIT_OF_ADDR    : NATURAL := 2
);
PORT(
----- USER LOGIC PORTS ---------
i_SYS_CLK       : IN STD_LOGIC;
i_ASYNC_RST_BAR : IN STD_LOGIC;
i_WRITE_BUS     : IN STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
o_READ_BUS      : OUT STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
i_ADDR          : IN STD_LOGIC_VECTOR(g_NUM_OF_BIT_OF_ADDR - 1  DOWNTO 0);
i_WRITE_EN_BAR  : IN STD_LOGIC;
i_READ_EN_BAR   : IN STD_LOGIC;
---- INTERFACE PORTS ------------
o_MOSI      : OUT STD_LOGIC;
io_SPI_CLK  : INOUT STD_LOGIC;
i_MISO      : IN STD_LOGIC := '0'
);
end component;
SIGNAL i_SYS_CLK         : STD_LOGIC := '0';                                           
SIGNAL i_ASYNC_RST_BAR   : STD_LOGIC := '1';                                           
SIGNAL i_WRITE_BUS       : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := X"00";      
SIGNAL o_READ_BUS        : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) ;     
SIGNAL i_ADDR            : STD_LOGIC_VECTOR(g_NUM_OF_BIT_OF_ADDR - 1  DOWNTO 0) := "00";
SIGNAL i_WRITE_EN_BAR    : STD_LOGIC := '1';                                           
SIGNAL i_READ_EN_BAR     : STD_LOGIC := '1'; 
SIGNAL o_MOSI            : STD_LOGIC ;                                
SIGNAL io_SPI_CLK        : STD_LOGIC ;                                                                                                         
SIGNAL i_MISO            : STD_LOGIC := '0';     
--SLAVE REGISTERS                                                                          
SIGNAL r_TX_SLAVE     : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT-1 DOWNTO 0) := X"AB"; 
SIGNAL R_SLAVE_RX     : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT-1 DOWNTO 0) := X"00";
SIGNAL r_SLAVE_OK     : STD_LOGIC := '0';

SIGNAL r_INCREMENT_MOSI    : INTEGER RANGE 0 TO 7 := 0;




TYPE STATES IS (S_IDLE,S_START,S_TRANFER,S_STOP);
SIGNAL STATE_SLAVE_TO_MISO : STATES := S_IDLE;
-----------------------------------------------                                                                                                                                       
CONSTANT PERIOD        : TIME := 10 NS ;

BEGIN 
DUT : serial_peripheral_interface
GENERIC MAP(
g_CLKFREQ               =>     g_CLKFREQ            ,
g_NUMBER_OF_BIT         =>     g_NUMBER_OF_BIT      ,
g_NUM_OF_BIT_OF_ADDR    =>     g_NUM_OF_BIT_OF_ADDR 
)

PORT MAP(
i_SYS_CLK                   =>     i_SYS_CLK        ,
i_ASYNC_RST_BAR             =>     i_ASYNC_RST_BAR  ,
i_WRITE_BUS                 =>     i_WRITE_BUS      ,
o_READ_BUS                  =>     o_READ_BUS       ,
i_ADDR                      =>     i_ADDR           ,
i_WRITE_EN_BAR              =>     i_WRITE_EN_BAR   ,
i_READ_EN_BAR               =>     i_READ_EN_BAR    ,
o_MOSI                      =>     o_MOSI           ,
io_SPI_CLK                  =>     io_SPI_CLK       ,
i_MISO                      =>     i_MISO       
);



 -- DATA ON MOSI IS WRITTEN ON RECEIVER REG. (RX_REG) ON SLAVE 
PROCESS(io_SPI_CLK)
VARIABLE v_BIT_COUNTER : INTEGER RANGE 0 TO 7;
VARIABLE v_TIMER       : INTEGER RANGE 0 TO 20 := 0;
BEGIN
IF RISING_EDGE(io_SPI_CLK) THEN
        IF (v_BIT_COUNTER = g_NUMBER_OF_BIT) THEN 
            r_SLAVE_OK              <= '1';
            v_BIT_COUNTER           := 0;
            r_INCREMENT_MOSI        <= 0;
        ELSE
            R_SLAVE_RX(r_INCREMENT_MOSI) <= o_MOSI;
            r_INCREMENT_MOSI             <= r_INCREMENT_MOSI + 1;
            v_BIT_COUNTER                := v_BIT_COUNTER + 1;
        END IF;
END IF;
END PROCESS;

 -- DATA ON SLAVE TRANSMITTER REG.(TX_REG) IS SAMPLED TO MISO
SLAVE_TO_MOSI : PROCESS(io_SPI_CLK) 
VARIABLE v_BIT_COUNTER : INTEGER RANGE 0 TO 8;
VARIABLE v_TIMER       : INTEGER RANGE 0 TO 20 := 0;
VARIABLE v_INCREMENT   : INTEGER RANGE 0 TO 8;
BEGIN 
    IF RISING_EDGE(io_SPI_CLK) THEN 
        IF (v_BIT_COUNTER = g_NUMBER_OF_BIT) THEN 
            v_BIT_COUNTER           := 0;
            v_INCREMENT             := 0;
            i_MISO                  <= '0';
        ELSE
            i_MISO                       <= r_TX_SLAVE(v_INCREMENT);
            v_INCREMENT                  := v_INCREMENT + 1;
            v_BIT_COUNTER                := v_BIT_COUNTER + 1;  
        END IF;
    END IF ;
END PROCESS SLAVE_TO_MOSI;




p_CLK_GEN : PROCESS BEGIN
i_SYS_CLK   <= '1';
WAIT FOR PERIOD/2;
i_SYS_CLK   <= '0';
WAIT FOR PERIOD/2;
END PROCESS p_CLK_GEN;


p_STIM : PROCESS BEGIN
i_ASYNC_RST_BAR     <= '0'; 
WAIT FOR PERIOD;
i_ASYNC_RST_BAR     <= '1';

i_ADDR              <= "00";
i_WRITE_BUS         <= x"01";

i_WRITE_EN_BAR      <= '0';
i_READ_EN_BAR       <= '1';

WAIT FOR PERIOD*2;
i_ADDR              <= "10";
i_WRITE_BUS         <= X"B3";

WAIT FOR PERIOD*40;

i_ADDR              <= "11";
i_WRITE_EN_BAR      <= '1';
i_READ_EN_BAR       <= '0';


WAIT;

END PROCESS p_STIM;
end Behavioral;
