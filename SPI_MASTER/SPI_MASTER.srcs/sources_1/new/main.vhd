

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
entity serial_peripheral_interface is
GENERIC(            
g_CLKFREQ               : INTEGER := 100_000_000;       -- SYSTEM FREQURNCY   
g_NUMBER_OF_BIT         : NATURAL := 8;                 -- NUMBER OF BITS OF USER LOGIC DATA SIDE OF MASTER
g_NUM_OF_BIT_OF_ADDR    : NATURAL := 2                  -- NUMBER OF BITS OF USER LOGIC ADDRESS SIDE OF MASTER
);
PORT(
----- USER LOGIC PORTS ---------
i_SYS_CLK           : IN STD_LOGIC;
i_ASYNC_RST_BAR     : IN STD_LOGIC; -- ACTIVE LOW
i_WRITE_BUS         : IN STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
o_READ_BUS          : OUT STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0);
i_ADDR              : IN STD_LOGIC_VECTOR(g_NUM_OF_BIT_OF_ADDR - 1  DOWNTO 0);
i_WRITE_EN_BAR      : IN STD_LOGIC; -- ACTIVE LOW   
i_READ_EN_BAR       : IN STD_LOGIC; -- ACTIVE LOW 
---- INTERFACE PORTS ------------
o_MOSI      : OUT STD_LOGIC ;
io_SPI_CLK  : INOUT STD_LOGIC; 
i_MISO      : IN STD_LOGIC := '0'

);
end serial_peripheral_interface;

architecture Behavioral of serial_peripheral_interface is

------REGISTERS INSIDE MASTER-------
--[RES RES RES RES CPHA CPOL SPR1 SPR0]-- (ONLY WRITING)
SIGNAL r_REG_1            : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := (OTHERS => '0');  

--[RES RES RES RES RES RES RES DONE]-- DONE : DONE IS SET WHEN USER LOGIC DATA IS WRITTEN ON r_TX_REG (ONLY WRITING)                                
SIGNAL r_REG_2            : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := (OTHERS => '0');
 
--[D7 D6 D5 D4 D3 D2 D1 D1 D0]-- (ONLY WRITING)
SIGNAL r_TX_REG           : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := (OTHERS => '0');
  
--[D7 D6 D5 D4 D3 D2 D1 D1 D0]--  READING
SIGNAL r_RX_REG           : STD_LOGIC_VECTOR(g_NUMBER_OF_BIT - 1 DOWNTO 0) := (OTHERS => '0');  


TYPE STATES IS (S_IDLE,S_START,S_TRANFER,S_STOP);
SIGNAL STATE_MOSI    : STATES := S_IDLE;

SIGNAL r_BIT_COUNTER_MOSI         : INTEGER RANGE 0 TO 8 := 0;
SIGNAL r_NUM_OF_DIVIDER           : INTEGER RANGE 0 TO 32 := 0;
SIGNAL r_TRANSMISSION_DONE        : STD_LOGIC:= '0'; -- RX_REG2
SIGNAL r_INCREMENT                : INTEGER RANGE 0 TO g_NUMBER_OF_BIT-1 := 0;
SIGNAL r_LATCHED_SPI_CLK          : STD_LOGIC := '0'; -- LATCH THE SPI_CLOCK WITH SYSTEM_CLOCK           
SIGNAL r_STOP_SPI_CLK             : STD_LOGIC := '0'; -- SET IF ALL DATA IS SEND       
begin

-- DATA FROM COMING USER LOGIC GOES TO MASTER RX_REG
-- ADDRESS SELECTION
USER_LOGIC : PROCESS(i_SYS_CLK,i_ASYNC_RST_BAR)
VARIABLE v_TIMER : INTEGER RANGE 0 TO 10:= 0;
BEGIN
    IF (i_ASYNC_RST_BAR = '0') THEN 
        r_REG_1    <= (OTHERS => '0');
        r_REG_2    <= (OTHERS => '0');
        r_TX_REG   <= (OTHERS => '0');
        o_READ_BUS <= (OTHERS => '0');
    ELSIF (RISING_EDGE(i_SYS_CLK))THEN
        IF(i_ADDR = "00") THEN --READ OPERATION  
            IF(v_TIMER = 1)THEN 
                IF(i_WRITE_EN_BAR = '0') THEN  -- WRITING OPERATION
                    r_REG_1     <= i_WRITE_BUS;
                    v_TIMER := 0;
                END IF;
            ELSE
                v_TIMER := v_TIMER + 1; 
            END IF;
        ELSIF(i_ADDR = "10")THEN
            IF(v_TIMER = 1)THEN 
                IF(i_WRITE_EN_BAR = '0') THEN  -- WRITING OPERATION  
                    r_TX_REG    <= i_WRITE_BUS; 
                    r_REG_2     <= x"01";
                    v_TIMER     := 0;
                END IF;
            ELSE
                    v_TIMER := v_TIMER + 1;
            END IF;
        ELSIF(i_ADDR = "11") THEN  
            IF (i_READ_EN_BAR = '0') THEN  -- READING OPERATION
                    o_READ_BUS <= r_RX_REG; 
                END IF ;
                                    
            END IF;
        END IF;

    
END PROCESS USER_LOGIC;

-- SPI_CLOCK DIVIDER SELECTION
NUM_OF_DIVIDER : PROCESS (i_SYS_CLK,i_ASYNC_RST_BAR)BEGIN 
    IF i_ASYNC_RST_BAR = '0' THEN 
        r_NUM_OF_DIVIDER <= 0;
    ELSIF (i_ADDR = "00") THEN 
        ELSIF(r_REG_2 = x"01") THEN 
            IF RISING_EDGE(i_SYS_CLK) THEN 
               CASE r_REG_1 IS 
                    WHEN x"00"      => 
                        r_NUM_OF_DIVIDER    <=  2;
                    WHEN x"01"       => 
                        r_NUM_OF_DIVIDER    <=  4;
                    WHEN x"02"       => 
                        r_NUM_OF_DIVIDER    <=  16;
                    WHEN x"03"       => 
                        r_NUM_OF_DIVIDER    <=  32;
                    WHEN OTHERS => r_NUM_OF_DIVIDER <= 0;
               END CASE;
            END IF;
        ELSE
        r_NUM_OF_DIVIDER <= 0;
    END IF ;

END PROCESS NUM_OF_DIVIDER;

-- SPI_CLOCK GENERATION
SPI_CLK_GEN : PROCESS(i_SYS_CLK,i_ASYNC_RST_BAR) 
VARIABLE v_COUNTER          : INTEGER RANGE 0 TO 32 := 0;
VARIABLE v_COUNTER_SPI_CLK  : INTEGER RANGE 0 TO 32 := 0;
VARIABLE v_TEMP_SPI_CLK     : STD_LOGIC := '1';
VARIABLE v_HOLDER           : INTEGER RANGE 0 TO 1 := 1;

BEGIN
IF i_ASYNC_RST_BAR = '0' THEN 
v_TEMP_SPI_CLK  := '0';
ELSIF r_STOP_SPI_CLK = '1' THEN 
    IF(v_COUNTER_SPI_CLK = (r_NUM_OF_DIVIDER/2)-1) THEN
        io_SPI_CLK          <= '0';
        v_COUNTER_SPI_CLK   := 0;
        r_TRANSMISSION_DONE <= '1';
    ELSE
        v_COUNTER_SPI_CLK   := v_COUNTER_SPI_CLK + 1;
    END IF;
ELSE
    IF (r_REG_2 =X"01" AND r_NUM_OF_DIVIDER /= 0) THEN  
        IF(RISING_EDGE(i_SYS_CLK)) THEN
            IF(v_COUNTER = (r_NUM_OF_DIVIDER/2)-1) THEN 
                IF v_HOLDER = 1 THEN  
                    v_HOLDER          := 0;
                    r_LATCHED_SPI_CLK       <= '1';
                ELSE
                    v_HOLDER          := v_HOLDER + 1;
                END IF;
                v_TEMP_SPI_CLK    := NOT(v_TEMP_SPI_CLK);
                v_COUNTER         := 0;         
            ELSE
                r_LATCHED_SPI_CLK       <= '0'; 
                v_COUNTER               := v_COUNTER + 1;
            END IF;
            io_SPI_CLK   <= v_TEMP_SPI_CLK;
        END IF ;
        io_SPI_CLK   <= v_TEMP_SPI_CLK;
        
        ELSE
        io_SPI_CLK   <= '0';
    END IF;
    
END IF;
END PROCESS SPI_CLK_GEN;


-- DATA INSIDE IN MASTER TX_REG IS SAMPLED ON MOSI
SPI_MASTER_TO_SLAVE : PROCESS(i_SYS_CLK,i_ASYNC_RST_BAR)
BEGIN
IF i_ASYNC_RST_BAR = '0' THEN
    o_MOSI      <= '0';
    
ELSIF(RISING_EDGE(i_SYS_CLK)) THEN   
      CASE STATE_MOSI IS 
          WHEN S_IDLE         =>
            IF r_REG_2 = x"01" AND r_STOP_SPI_CLK = '0' THEN 
                STATE_MOSI      <= S_START;
            ELSE
               STATE_MOSI       <= S_IDLE;
            END IF;
          WHEN S_START        =>
                    o_MOSI              <= r_TX_REG(r_INCREMENT);
                IF (r_LATCHED_SPI_CLK = '1') THEN 
                    STATE_MOSI          <= S_TRANFER;
                    r_INCREMENT         <= r_INCREMENT + 1;
                    r_BIT_COUNTER_MOSI  <= r_BIT_COUNTER_MOSI + 1;
                ELSE
                    o_MOSI              <= r_TX_REG(r_INCREMENT);
                END IF ;
                
          WHEN S_TRANFER      => 
                    o_MOSI                  <= r_TX_REG(r_INCREMENT);
                    IF(r_BIT_COUNTER_MOSI = g_NUMBER_OF_BIT-1)THEN
                      IF (r_LATCHED_SPI_CLK = '1') THEN 
                        r_BIT_COUNTER_MOSI    <= 0;
                        r_INCREMENT           <= 0;
                        o_MOSI                <= '0';
                        STATE_MOSI            <= S_STOP; 
                      ELSE
                        STATE_MOSI            <= S_TRANFER;
                      END IF;
                    ELSE
                        IF(r_LATCHED_SPI_CLK = '1') THEN 
                            r_INCREMENT           <= r_INCREMENT + 1;
                            r_BIT_COUNTER_MOSI    <= r_BIT_COUNTER_MOSI + 1;
                        ELSE
                            o_MOSI                <= r_TX_REG(r_INCREMENT);
                        END IF;
                    END IF ;
          WHEN S_STOP         => 
                    r_STOP_SPI_CLK      <= '1';
                    STATE_MOSI          <= S_IDLE;
                    o_MOSI              <= '0';
          END CASE;
          
  END IF ;
END PROCESS SPI_MASTER_TO_SLAVE;

-- MISO OPERATION : DATA ON MISO IS WRITTEN IN RX_REG
MISO_TO_RX_REG :PROCESS (io_SPI_CLK,i_ASYNC_RST_BAR)
VARIABLE v_BIT_COUNTER : INTEGER RANGE 0 TO 8;
VARIABLE v_INCREMENT   : INTEGER RANGE 0 TO 8;
BEGIN
IF i_ASYNC_RST_BAR = '0' THEN 
    R_RX_REG       <= X"00";
ELSIF FALLING_EDGE(io_SPI_CLK) THEN  
        
        IF (v_BIT_COUNTER = g_NUMBER_OF_BIT) THEN 
            v_BIT_COUNTER           := 0;
            v_INCREMENT             := 0;
        ELSE 
            R_RX_REG(v_INCREMENT)        <= i_MISO;
            v_INCREMENT                  := v_INCREMENT + 1;
            v_BIT_COUNTER                := v_BIT_COUNTER + 1;
            END IF;
      END IF;  
END PROCESS MISO_TO_RX_REG;




end Behavioral;
