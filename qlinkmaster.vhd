-------------------------------------------------------------------
-- QLinkMaster  : An UART <-> SoC-bus  link
-- Version      : XC7   ... intended for simplest possible use with Xilinx 7-series FPGA's
-- Revision     : 2019-11-14
-- 
-- (C) 2019  Anders Stengaard Sørensen (Author), Denmark
-- 
-- This VHDL source fil may be used, distributed and changed in any way, by anyone on the following conditions:
-- 1) The Author provide no guarantee and is not in any way liable for any issues that arise from the use of this source
-- 2) Projects, products etc. that make use of this source must credit/attribute the original work and Author
--
-- QLink stand for Quick-Link and is meant as a tool for students and researchers, to quickly and easily create a
-- link between a UART enabled computer/microcontroller/processor (CPU) and an FPGA, for study and research projects
-- Using a simple text oriented protocol carried by a UART, the CPU can generate read- and write-cycles on a data-bus
-- inside the FPGA.
--
-- History:  Created on 2019-11-14
--   Background: QLink is inspired by "Unity-Link" by Anders Lange, which is more comprehensible but is harder for students to use. 
--                  https://ieeexplore.ieee.org/abstract/document/6696914
--               Unity-Link was inspired by "TOSNet" and "Micro TOSNet by Simon Falsig
--                  https://opencores.org/projects/tosnet
--                  https://opencores.org/projects/utosnet
--                  https://ieeexplore.ieee.org/abstract/document/4957485
--                  Falsig, Simon. "Interaction framework for loosely-coupled controllers." (Ph.D. Dissertation 2011).
--   The 2019 version: Was used by students in EMB3 for several years, using various commercial FPGA boards
--     It has also been used extensively in research projects, especially with digilent CMOD-A7 boards
--   In 2026 it was revised for use with the Sindri FPGA board, including:
--     - changing mmcm48 to use 768MHz PLL frequency to create 48MHz from Sindri's native 12MHz oscillator
--     - updating comments in the sources  
--
-- Comments: The QLinkMaster module is supplied with a clock signal of 12MHz and upwards
--           .. and with information about the clock period - as a GENERIC
--           The mmcm48 module will multiply the clock signal to arrive at 768MHZ PLL frequency
--           Which it will then divide by 16 to create a 48MHz system clock signal
--   NOTE:   That the mmcm can only multiply with factors in increments of 1/8's  0.125
--           so it may be necessary to state a clock period that is slightly wrong, in order to
--           please the mmcm restrictions.
--           The multiplication factor is in the mmcm48.vhd source as:  CLK_I_PERIOD*0.768
--           .. meaning that the CLK_I_PERIOD multiplied by 0.768 and by 8 MUST give an integer number
--              For example: 83.3333*0.768*8=512
--              So, you may be forced to state a slightly rounded period to accomodate your particular clock frequency
--              Use gnu-octave or matlab to calculate the nearest acceptable period (in ns): assuming your clock frequency in MHz is in varible: f
--              gnu-octave/matlab command: floor(8*768/f)/(8*0.768)
--              12MHz->83.333   20MHz->49.967   25MHz->39.876   32MHz->31.250   48MHz->20.833  50MHz->19.857 100MHz->9.9284
--            All this is a little silly - in future revisions, the QLinikMaster should be changed to accept only 48MHz
--              and it will be left as an exercize to the user to figure out how to provide it
--
-- Use:      QLinkMaster Version XC7 operate as a combined System Control module and System Communication module.
--           The user must use the clock and reset signals provided by QLinkMaster as system clock and system reset. QLinkMaster: 
--             . Generates a combined bitrate- and system-clock of 48MHz from a provided clock signal (external oscillator min 12.000MHz)
--             . Generates a system reset signal synchronized with the system clock. Reset is asserted while:
--                 The Xilinx Clock Managemant Module (MMCM) is locking on the the clock after power-up
--                 OR the reset input is asserted  
--           QLinkMaster operate at 3Mbps 8N1 with no handshake and no echoing.
--           When operating it accept the following commands issued through Tx:
--             #w:AADDDDDDDD   - Where AA is a 2-digit base 16 address, eg: 04 and DDDDDDDD is an 8-digit base 16 data word
--                               The FPGA create an internal write cycle but does not send anything in return on Rx
--             #r:AA.......... - Where AA is a 2-digit base 16 address and .......... are 10 arbitrary non "#" characters for padding
--                               The FPGA create an internal read-cycle and respond on Rx with: "!AA:DDDDDDDD
--                               Where AA is the read address and DDDDDDDD is an 8-digit base 16 representation of the data read
--             #R:AA.................... - With 20 arbitrary non "#" characters for padding
--                               The FPGA create an internal read-cycle and read the internal 32-bit clock cycle counter and
--                               respond with: !AA:DDDDDDDD;CCCCCCCC where CCCCCCCC is an 8-digit base 16 representation of the clock counter
--                               The padding in #r/#R commands ensure proper spacing between commands to allow the fpga to respond,
--                               The padding is not necessary if similar pauses between commands is ensured in another way.
--                               Characters not in the set: "#:rRwW0123456789abcdefABCDEF" are treated as spacing 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
---USE ieee.numeric_std.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

Library UNISIM;                    -- For Xilinx primitives
use UNISIM.vcomponents.all;        --   allow all "components"


entity QLinkMaster is
  Generic ( CLK_I_PERIOD : real range 2.0 to 64.0 := 83.333;  -- Default for Sindri 12MHz
            BLINK_SEQUENCE : std_logic_vector := "11100011100011100011100010101010" );  --  
  Port    ( RESET_I  : in STD_LOGIC;
            CLK48_I    : in STD_LOGIC;   -- For Sindri board this is 12MHz
            RX_I     : in STD_LOGIC;
            TX_O     : out STD_LOGIC;
--            CLK48_O  : out STD_LOGIC;
            ADDR_B_O : out STD_LOGIC_VECTOR(7 downto 0);
            DATA_B_O : out STD_LOGIC_VECTOR(31 downto 0);
            DATA_B_I : in  STD_LOGIC_VECTOR(31 downto 0);
            WR_O     : out STD_LOGIC;
            RD_O     : out STD_LOGIC;
            RESET_O  : out STD_LOGIC;
            LED_O    : out STD_LOGIC );                      -- Status LED (blinks)
end QLinkMaster;

----------------------------------
architecture rtl of QLinkMaster is

---- COMPONENTS ----

---- Define the MMCM component
--  component mmcm48 is
--    Generic  (CLK_I_PERIOD : real range 2.0 to 64.0);  
--    Port     (RESET_I    : in STD_LOGIC;
--              CLK_I      : in STD_LOGIC;
--              CLK48_O    : out STD_LOGIC;
--              PLL_LOCK_O : out STD_LOGIC );
--   end component;
--   signal mmcm_lock     : std_logic;     -- Will be mapped to PLL:LOCK_O
   signal clk48  : std_logic;     -- Will be mapped to CLK1_O and CLK0_O
--------------------------------------------------------
  
-- Define serial decoder component   
component decode_serial is
    Port ( RESET_I    : in STD_LOGIC;
           CLK_UART_I : in STD_LOGIC;
           RX_I       : in STD_LOGIC;
           DATA_O     : out STD_LOGIC_VECTOR(7 downto 0);
           STB_O      : out STD_LOGIC );
end component;
     signal dec_data   : std_logic_vector(7 downto 0); -- will be mapped to DATA_O
     signal dec_strb   : std_logic;

-- Define serial encoder component
component encode_serial is
    Port ( RESET_I    : in STD_LOGIC;
           CLK_UART_I : in STD_LOGIC;
           DATA_I     : in STD_LOGIC_VECTOR(7 downto 0);
           WR_I       : in STD_LOGIC;
           TX_O       : out STD_LOGIC;
           BUSY_O     : out STD_LOGIC );
end component;
signal enc_data : std_logic_vector(7 downto 0);
signal enc_wr   : std_logic;
signal enc_busy : std_logic;
  
---- Types and signals for linkmaster state machine --
type rx_state_t is (hashtag,cmd,                                     -- First states
                    read_colon,read_addr0,read_addr1,                -- READ ":" and READ decode address states
                    read_bus0,read_bus1,                              -- READ, create read cycle on bus
                    write_colon,write_addr0,write_addr1,             -- WRITE ":" and WRITE decode address states
                    write_data0,write_data1,write_data2,write_data3, -- WRITE, decode data digits 7 ... 4
                    write_data4,write_data5,write_data6,write_data7, -- WRITE, decode data digits 3 ... 0
                    write_commit);                                   -- WRITE, create write cycle on bus
signal rx_state : rx_state_t;

function hex2ascii (x : in std_logic_vector(3 downto 0)) return std_logic_vector is
  variable y : std_logic_vector(7 downto 0);
begin
  case (x) is
    when X"0" => y:=X"30"; -- "0"
    when X"1" => y:=X"31"; -- "1"
    when X"2" => y:=X"32"; -- "2"
    when X"3" => y:=X"33"; -- "3"
    when X"4" => y:=X"34"; -- "4"
    when X"5" => y:=X"35"; -- "5"
    when X"6" => y:=X"36"; -- "6"
    when X"7" => y:=X"37"; -- "7"
    when X"8" => y:=X"38"; -- "8"
    when X"9" => y:=X"39"; -- "9"
    when X"A" => y:=X"41"; -- "A"
    when X"B" => y:=X"42"; -- "B"
    when X"C" => y:=X"43"; -- "C"
    when X"D" => y:=X"44"; -- "D"
    when X"E" => y:=X"45"; -- "E"
    when X"F" => y:=X"46"; -- "F"
    when others => y:=X"3F"; -- "?"
  end case;
  return y;
end function;

function ascii2hex (x : in std_logic_vector(7 downto 0)) return std_logic_vector is
  variable y : std_logic_vector(3 downto 0);
  variable yy : std_logic_vector (4 downto 0);
  variable err : std_logic;      
   begin
      err:='0';
      if    x=X"30" then y:= X"0";
      elsif x=X"31" then y:= X"1";
      elsif x=X"32" then y:= X"2";
      elsif x=X"33" then y:= X"3";
      elsif x=X"34" then y:= X"4";
      elsif x=X"35" then y:= X"5";
      elsif x=X"36" then y:= X"6";
      elsif x=X"37" then y:= X"7";
      elsif x=X"38" then y:= X"8";
      elsif x=X"39" then y:= X"9";                        
      elsif x=X"41" or x=X"61" then y:= X"A";
      elsif x=X"42" or x=X"62" then y:= X"B";
      elsif x=X"43" or x=X"63" then y:= X"C";
      elsif x=X"44" or x=X"64" then y:= X"D";
      elsif x=X"45" or x=X"65" then y:= X"E";
      elsif x=X"46" or x=X"66" then y:= X"F";
      else  err:='1';
      end if;
      yy := err & y;
      return yy;
   end ascii2hex;
   
   
   -- Internal system signals
     signal sys_reset     : std_logic := '1';
     signal x_reset       : std_logic;
     signal buf_reset     : std_logic := '0'; -- registered reset
     signal clk_cnt       : std_logic_vector(31 downto 0);
     signal timestamp     : std_logic_vector(31 downto 0);
     signal timestamp_enable : std_logic;
     
     signal adr    : std_logic_vector(7 downto 0);
     signal data32 : std_logic_vector(31 downto 0);      
     signal wr     : std_logic;
     signal rd     : std_logic;
     
     signal char_cnt   : integer range 0 to 31;
     signal sendstring : std_logic;
     
     signal led_idx : integer range 0 to 36 :=0;
     signal led_sequence : std_logic_vector(0 to BLINK_SEQUENCE'LENGTH-1) := BLINK_SEQUENCE;
     
begin

x_reset <= RESET_I;
clk48 <= CLK48_I;
--CLK48_O <= clk48;
RESET_O <= sys_reset;

ADDR_B_O <= adr;
DATA_B_O <= data32;

WR_O <= wr;
RD_O <= rd;

-------------------------------------
---- Clock manager & system reset 
--MMCM48_INST: mmcm48
--  generic map (CLK_I_PERIOD => CLK_I_PERIOD)  -- Instantiate the module with information that CLK_I has period of ... (2-64ns)
--  port map (
--    RESET_I => '0',
--    CLK_I => CLK_I,
--    CLK48_O => clk48, 
--    PLL_LOCK_O => mmcm_lock
--  );
  process(clk48,x_reset)  -- recommended system reset design: 
  begin            -- https://forums.xilinx.com/t5/Adaptable-Advantage-Blog/Demystifying-Resets-Synchronous-Asynchronous-other-Design/ba-p/882252
    if x_reset='1' then
      sys_reset <='1';
      buf_reset <='1';
    elsif clk48'event and clk48='1' then
      sys_reset <= buf_reset;
      buf_reset <= x_reset;
    end if ;
  end process;
----------------------------

U1:decode_serial port map(     -- Instantiate RX decoder
     RESET_I    => sys_reset,  -- System reset
     CLK_UART_I => clk48,      -- Serial clock ... 16 x bitrate
     RX_I       => RX_I,       -- Serial data
     DATA_O     => dec_data,   -- Paralel data
     STB_O      => dec_strb    -- Strobe
     );

U2:encode_serial port map(      -- Instantiate TX encoder
           RESET_I=>sys_reset,  -- System reset
           CLK_UART_I=> clk48,  -- Serial clock ... 16 x bitrate
           DATA_I => enc_data,  -- Parallel data
           WR_I   => enc_wr,    -- Write strobe
           TX_O   => TX_O,      -- Serial data
           BUSY_O => enc_busy); -- Busy signal

-- State machine to control status LED

process(clk48,sys_reset)
begin
  if clk48'event and clk48='1' then
    
    if sys_reset='1' then
      led_idx<=0;
      LED_O<='0';
    else
      LED_O<=led_sequence(led_idx);
      if clk_cnt(22 downto 0) = "00000000000000000000000" then
        if led_idx<(BLINK_SEQUENCE'LENGTH-1) then led_idx<=led_idx+1;
        else led_idx<=0;  end if;
      else led_idx<=led_idx;
      end if; -- COUNTER
    end if; -- RESET
  end if; -- CLK
end process;

---- State machine to detect and decode #W:aadddddddd sequences and produce RW/WR cycles
process(clk48,sys_reset)
  variable nxt_rx_state : rx_state_t := hashtag;
  variable nxt_adr : std_logic_vector(7 downto 0);
  variable nxt_data32 : std_logic_vector(31 downto 0);
  variable nxt_timestamp: std_logic_vector(31 downto 0);
  variable nxt_timestamp_enable : std_logic;
  variable nxt_wr : std_logic;
  variable nxt_rd : std_logic; 
  --variable nxt_enc_data : std_logic_vector(7 downto 0);
  --variable nxt_enc_wr : std_logic;
  variable nxt_sendstring : std_logic;
begin
  if clk48'event and clk48='1' then
    if sys_reset='1' then
      clk_cnt<=X"00000000";
      nxt_rx_state:=hashtag;
      nxt_adr:=X"00";
      nxt_data32:=X"00000000";
      nxt_timestamp:=X"00000000";
      nxt_timestamp_enable:='0';
      nxt_rd:='0';
      nxt_wr:='0';
    --  nxt_enc_data:=X"00";
    --  nxt_enc_wr:='0';
      nxt_sendstring:='0';
    else
      clk_cnt<=clk_cnt+X"00000001";
      nxt_adr:=adr;
      nxt_data32:=data32;
      nxt_timestamp:=timestamp;
      nxt_timestamp_enable:=timestamp_enable;
      nxt_rx_state:=rx_state;
      nxt_wr:='0';
      nxt_rd:='0';
--      nxt_enc_wr:='0';
      nxt_sendstring:=sendstring and (not enc_busy);
      
      if dec_strb='1' then nxt_rx_state:=hashtag; end if;  -- default ... go to start state
         
      case (rx_state) is   -- (hashtag,cmd,read_colon,write_colon,write_addr0,write_addr1);
        when hashtag =>
          if dec_strb='1' and dec_data = X"23" then nxt_rx_state:=cmd; end if;
        when cmd =>
          if dec_strb='1' then
            case(dec_data) is
              when X"57" => nxt_rx_state:= write_colon;  -- "W"
              when X"77" => nxt_rx_state:= write_colon;  -- "w"
              when X"52" => 
                nxt_timestamp_enable:='1';
                nxt_rx_state:= read_colon;  -- "R"
                --nxt_enc_data:=X"41";
                --nxt_enc_wr:='1';
              when X"72" =>
                nxt_timestamp_enable:='0';
                nxt_rx_state:= read_colon;   -- "r"
                --nxt_enc_data:=X"61";
                --nxt_enc_wr:='1';
              when others =>
            end case;
          end if;
        when write_colon =>
          if dec_strb='1' and dec_data = X"3A" then nxt_rx_state:=write_addr0; end if;
          
        when write_addr0 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /='1' then            
            nxt_adr(7 downto 4):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_addr1;
          end if;
          
        when write_addr1 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_adr(3 downto 0):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data0;
          end if;
          
        when write_data0 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(31 downto 28):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data1;
          end if;

        when write_data1 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(27 downto 24):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data2;
          end if;
          
        when write_data2 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(23 downto 20):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data3;
          end if;          
        when write_data3 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(19 downto 16):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data4;
          end if;
              
        when write_data4 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(15 downto 12):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data5;
          end if;
                
        when write_data5 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(11 downto 8):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data6;
          end if;
                  
        when write_data6 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(7 downto 4):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_data7;
          end if;
                    
        when write_data7 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_data32(3 downto 0):=ascii2hex(dec_data)(3 downto 0);
            nxt_rx_state:=write_commit;
          end if;
                      
        when write_commit =>
          nxt_wr:='1';
          nxt_rx_state:=hashtag;
          
      --- States for read cycles    
        when read_colon =>
          if dec_strb='1' and dec_data = X"3A" then nxt_rx_state:=read_addr0; end if;
            
        when read_addr0 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /='1' then            
            nxt_adr(7 downto 4):=ascii2hex(dec_data)(3 downto 0);
      --      nxt_enc_data:=dec_data;
      --      nxt_enc_wr:='1';
            nxt_rx_state:=read_addr1;
          end if;
                  
        when read_addr1 =>
          if dec_strb='1' and ascii2hex(dec_data)(4) /= '1' then
            nxt_adr(3 downto 0):=ascii2hex(dec_data)(3 downto 0);
     --       nxt_enc_data:=dec_data;
     --       nxt_enc_wr:='1';
     --       nxt_rd:='1';
            nxt_rx_state:=read_bus0;
          end if;
        when read_bus0 =>
          nxt_rd:='1';
          nxt_rx_state:=read_bus1;
        when read_bus1 => 
          nxt_data32:=DATA_B_I;
          nxt_timestamp:=clk_cnt;
          nxt_rx_state:=hashtag;
          nxt_sendstring:='1';
        when others =>
         nxt_rx_state:=hashtag;
      end case;
    end if;
  rx_state<=nxt_rx_state;
  adr<=nxt_adr;
  data32<=nxt_data32;
  timestamp<=nxt_timestamp;
  timestamp_enable<=nxt_timestamp_enable;
  wr<=nxt_wr;
  rd<=nxt_rd;
  -- enc_data<=nxt_enc_data;
  -- enc_wr<=nxt_enc_wr;
  sendstring<=nxt_sendstring;
  end if;
end process;
 
---- Feed the serial encoder a string sequences
process(clk48,sys_reset)
  variable nxt_enc_data : std_logic_vector(7 downto 0);
  variable nxt_char_cnt : integer range 0 to 31;
  variable nxt_enc_wr   : std_logic;
begin 
  if clk48'event and clk48='1' then
    nxt_enc_wr:='0';
    if sys_reset='1' then       -- if RESET
      nxt_char_cnt:=0;          --  Point at first character
       
    elsif enc_busy='1' then     -- If not RESET but encoder is busy
      nxt_char_cnt:=char_cnt;   --   Point to first character 
      
    elsif enc_wr='0' and        -- If not BUSY and transmission has not already been requested
          (sendstring='1' or    -- .. and receiving state machine request a string to be sent.
          char_cnt>0) then      -- .. or we are in the midst of a transmission
      nxt_enc_wr:='1';        
      nxt_char_cnt:=char_cnt+1; --   Advance to next character
      
      case (char_cnt) is        --   Discriminate between character number
      when 0 =>                 
        nxt_enc_data:=X"21";    -- 21="!" 
      when 1 =>
        nxt_enc_data:=hex2ascii(adr(7 downto 4));    
      when 2 =>
        nxt_enc_data:=hex2ascii(adr(3 downto 0));
      when 3 =>
          nxt_enc_data:=X"3A";
      when 4 =>
        nxt_enc_data:=hex2ascii(data32(31 downto 28));
      when 5 =>
        nxt_enc_data:=hex2ascii(data32(27 downto 24));
      when 6 =>
        nxt_enc_data:=hex2ascii(data32(23 downto 20));
      when 7 =>
        nxt_enc_data:=hex2ascii(data32(19 downto 16));
      when 8 =>
        nxt_enc_data:=hex2ascii(data32(15 downto 12));
      when 9 =>
        nxt_enc_data:=hex2ascii(data32(11 downto 8));
      when 10 =>
        nxt_enc_data:=hex2ascii(data32(7 downto 4));
      when 11 =>
        nxt_enc_data:=hex2ascii(data32(3 downto 0));
        if timestamp_enable='0' then
          nxt_char_cnt:=21;
        end if;
     
      when 12 =>
               nxt_enc_data:=X"3B"; -- ";"    
       
      when 13 =>
        nxt_enc_data:=hex2ascii(timestamp(31 downto 28));
      when 14 =>
        nxt_enc_data:=hex2ascii(timestamp(27 downto 24));
      when 15 =>
        nxt_enc_data:=hex2ascii(timestamp(23 downto 20));
      when 16 =>
        nxt_enc_data:=hex2ascii(timestamp(19 downto 16));
      when 17 =>
        nxt_enc_data:=hex2ascii(timestamp(15 downto 12));
      when 18 =>
        nxt_enc_data:=hex2ascii(timestamp(11 downto 8));
      when 19 =>
        nxt_enc_data:=hex2ascii(timestamp(7 downto 4));
      when 20 =>
        nxt_enc_data:=hex2ascii(timestamp(3 downto 0));
        
      when 21 =>
        nxt_enc_data:=X"0D";   -- <CR>
        nxt_char_cnt:=0;
      when others =>
        nxt_char_cnt:=0;
      end case;

    else  
--    enc_wr<='0';   
    end if; -- RESET
    enc_wr<=nxt_enc_wr;
    enc_data<=nxt_enc_data;
    char_cnt<=nxt_char_cnt;
  end if; -- CLK
end process;

end rtl;
