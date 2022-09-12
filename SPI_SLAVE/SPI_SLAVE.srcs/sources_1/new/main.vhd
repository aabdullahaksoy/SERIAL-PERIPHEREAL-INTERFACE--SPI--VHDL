


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;



entity main is
GENERIC(           
g_CLKFREQ               : INTEGER := 50_000_000;   -- SLAVE CLOCK FREQUENCY  
g_NUMBER_OF_BIT         : NATURAL := 8;            -- NUMBER OF DATA SIDE OF SLAVE USER LOGIC 
g_NUM_OF_BIT_OF_ADDR    : NATURAL := 2             -- NUMBER OF ADDRESS BITS SIDE OF SLAVE USER LOGIC 
);
PORT(
----- USER LOGIC PORTS ---------
i_SLAVE_CLK         : IN STD_LOGIC;  -- SLAVE SYSTEM CLOCK
i_ASYNC_RST_BAR     : IN STD_LOGIC; -- ACTIVE LOW
i_WRITE_BUS         : IN STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
o_READ_BUS          : OUT STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
i_ADDR              : IN STD_LOGIC_VECTOR(g_NUM_OF_BIT_OF_ADDR - 1  DOWNTO 0);
i_WRITE_EN_BAR      : IN STD_LOGIC; -- ACTIVE LOW   
i_READ_EN_BAR       : IN STD_LOGIC; -- ACTIVE LOW 
---- INTERFACE PORTS ------------
i_SPI_CLK           : IN STD_LOGIC ;
i_MOSI              : IN STD_LOGIC_VECTOR(g_NUMBER_OF_BIT-1 DOWNTO 0) ;
o_MISO              : OUT STD_LOGIC

);
end main;

architecture Behavioral of main is
------REGISTERS INSIDE SLAVE-------
--[RES RES RES RES RES RES RES DONE]-- DONE : DONE IS SET WHEN USER LOGIC DATA IS WRITTEN ON TX_REG (ONLY WRITING)
SIGNAL r_STATUS_REG         : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := (OTHERS => '0');  

--[D7 D6 D5 D4 D3 D2 D1 D1 D0]-- (ONLY WRITING)
SIGNAL r_TX_REG           : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := (OTHERS => '0');
  
--[D7 D6 D5 D4 D3 D2 D1 D1 D0]--  READING
SIGNAL r_RX_REG           : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := (OTHERS => '0');  

TYPE STATES IS (S_IDLE,S_START,S_TRANFER,S_STOP);
SIGNAL STATE_MISO                 : STATES := S_IDLE;

SIGNAL r_BIT_COUNTER_MISO         : INTEGER RANGE 0 TO 8 := 0;
SIGNAL r_INCREMENT                : INTEGER RANGE 0 TO g_NUMBER_OF_BIT-1 := 0;
SIGNAL r_LATCHED_SPI_CLK          : STD_LOGIC := '0'; -- LATCH THE SPI_CLOCK WITH SYSTEM_CLOCK           
SIGNAL r_STOP_SPI_CLK             : STD_LOGIC := '0';     

begin
-- DATA FROM WRITE BUS IS WRITTEN TO SLAVE TRANSMIT REG(TX_REG)
-- ADDRESS SELECTION
USER_LOGIC : PROCESS(i_SLAVE_CLK,i_ASYNC_RST_BAR)
VARIABLE v_TIMER : INTEGER RANGE 0 TO 10:= 0;
BEGIN
    IF (i_ASYNC_RST_BAR = '0') THEN 
        r_STATUS_REG    <= (OTHERS => '0');
        r_TX_REG        <= (OTHERS => '0');
        o_READ_BUS      <= (OTHERS => '0');
    ELSIF (RISING_EDGE(i_SLAVE_CLK))THEN
        IF(i_ADDR = "01")THEN
            IF(v_TIMER = 1)THEN 
                IF(i_WRITE_EN_BAR = '0') THEN  -- WRITING OPERATION  SORUN BURDA
                    r_TX_REG         <= i_WRITE_BUS; 
                    r_STATUS_REG     <= x"01";
                    v_TIMER          := 0;
                END IF;
            ELSE
                    v_TIMER := v_TIMER + 1;
            END IF;
        ELSIF(i_ADDR = "10") THEN  
            IF (i_READ_EN_BAR = '0') THEN  -- READING OPERATION
                    o_READ_BUS <= r_RX_REG; 
                END IF ;
                                    
            END IF;
        END IF;
    
END PROCESS USER_LOGIC;


SPI_CLK_LATCHING : PROCESS (i_SPI_CLK,i_SLAVE_CLK)
VARIABLE COUNTER : INTEGER RANGE 0 TO 2 := 0;
BEGIN 
    IF i_SLAVE_CLK = '1' THEN 
       IF FALLING_EDGE(i_SPI_CLK) THEN 
            r_LATCHED_SPI_CLK <= '1';
       END IF;
    ELSE
        r_LATCHED_SPI_CLK   <= '0';
    END IF;
END PROCESS SPI_CLK_LATCHING;


-- DATA ON SLAVE TX_REG IS SAMPLED TO MISO
SPI_SLAVE_TO_MISO : PROCESS(i_SLAVE_CLK,i_ASYNC_RST_BAR)
BEGIN
IF i_ASYNC_RST_BAR = '0' THEN
    o_MISO      <= '0';
ELSIF(FALLING_EDGE(i_SLAVE_CLK)) THEN  
      CASE STATE_MISO IS 
          WHEN S_IDLE         =>
            IF r_STATUS_REG = x"01" AND r_STOP_SPI_CLK = '0' THEN 
                STATE_MISO      <= S_START;
            ELSE
                STATE_MISO       <= S_IDLE;
            END IF;
          WHEN S_START        =>
                    o_MISO                  <= r_TX_REG(r_INCREMENT);
                    IF r_LATCHED_SPI_CLK = '1' THEN 
                        STATE_MISO          <= S_TRANFER;
                        r_INCREMENT         <= r_INCREMENT + 1;
                        r_BIT_COUNTER_MISO  <= r_BIT_COUNTER_MISO + 1;
                    ELSE
                        o_MISO              <= r_TX_REG(r_INCREMENT);
                    END IF;
          WHEN S_TRANFER      => 
                    o_MISO                  <= r_TX_REG(r_INCREMENT);
                    IF(r_BIT_COUNTER_MISO = g_NUMBER_OF_BIT-1)THEN
                      IF (r_LATCHED_SPI_CLK = '1') THEN 
                        r_BIT_COUNTER_MISO    <= 0;
                        r_INCREMENT           <= 0;
                        o_MISO                <= '0';
                        STATE_MISO            <= S_STOP; 
                      ELSE
                        STATE_MISO            <= S_TRANFER;
                      END IF;
                    ELSE
                        IF(r_LATCHED_SPI_CLK = '1') THEN 
                            r_INCREMENT           <= r_INCREMENT + 1;
                            r_BIT_COUNTER_MISO    <= r_BIT_COUNTER_MISO + 1;
                        ELSE
                            o_MISO                <= r_TX_REG(r_INCREMENT);
                        END IF;
                    END IF ;
          WHEN S_STOP         => 
                    r_STOP_SPI_CLK      <= '1';
                    STATE_MISO          <= S_IDLE;
                    o_MISO              <= '0';
          END CASE;
          
  END IF ;
END PROCESS SPI_SLAVE_TO_MISO;

MOSI_TO_SLAVE_RX : PROCESS(i_SPI_CLK) -- DATA FROM MOSI IS WRITTEN TO SLAVE RECEIVER REG 
VARIABLE v_BIT_COUNTER : INTEGER RANGE 0 TO 8;
VARIABLE v_INCREMENT   : INTEGER RANGE 0 TO 8;
BEGIN
IF i_ASYNC_RST_BAR = '0' THEN 
    r_RX_REG       <= X"00";
ELSIF RISING_EDGE(i_SPI_CLK) THEN  
        IF (v_BIT_COUNTER = g_NUMBER_OF_BIT) THEN 
            v_BIT_COUNTER           := 0;
            v_INCREMENT             := 0;
        ELSE 
            r_RX_REG(v_INCREMENT)    <= i_MOSI(v_INCREMENT);
            v_INCREMENT              := v_INCREMENT + 1;
            v_BIT_COUNTER            := v_BIT_COUNTER + 1;
            END IF;
      END IF;  

END PROCESS MOSI_TO_SLAVE_RX; 

end Behavioral;
