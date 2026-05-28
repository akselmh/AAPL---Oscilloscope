-------------------------------------------------------------------
-- Decode_Serial  : Receiving part of UART
-- Revision      : 2019-11-14
-- Submodule for : QLinkMaster
-- 
-- (C) 2019  Anders Stengaard Sørensen (Author), Denmark
-- 
-- This VHDL source fil may be used, distributed and changed in any way, by anyone on the following conditions:
-- 1) The Author provide no guarantee and is not in any way liable for any issues that arise from the use of this source
-- For more information, see the QLinkMaster module source
--
-- Decode 3Mbps N81 UART serial datastream into 8-bit data 
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity decode_serial is
    Port ( RESET_I    : in STD_LOGIC;   -- Reset input
           CLK_UART_I : in STD_LOGIC;   -- 96MHz clock for 3Mbps  (bitrate=f/32)
           RX_I       : in STD_LOGIC;   -- Serial data input
           DATA_O     : out STD_LOGIC_VECTOR(7 downto 0);  -- 8 bit data output
           STB_O      : out STD_LOGIC );                   -- Strobe .. high for 1 clock cycle
  end decode_serial;  
  
  architecture rtl of decode_serial is
  
  signal sys_reset        : std_logic := '1';
  signal clk_uart         : std_logic;
  signal rx               : std_logic;
  signal bitcnt : integer range 0 to 9;
  signal subcnt : integer range 0 to 15;
  signal data   : std_logic_vector(7 downto 0);
  signal strobe : std_logic;
  signal strobe2 : std_logic;
--  signal run    : std_logic := '0';
  
  
  begin
  
  sys_reset <= RESET_I;
  clk_uart <= CLK_UART_I;
  rx <= RX_I;
  DATA_O <= data;
  STB_O <= strobe;
  
  process(clk_uart)
    variable nxt_strobe : std_logic;
    variable nxt_strobe2 : std_logic;
  begin
    if clk_uart'event and clk_uart='1' then
      nxt_strobe:='0';
      nxt_strobe2 := '0';
      if bitcnt = 9 then
          nxt_strobe2 := '1';
          nxt_strobe:='1';
          if strobe2 = '1' then
            nxt_strobe:='0';      
          end if;
        end if;
      strobe<=nxt_strobe;
      strobe2<=nxt_strobe2;
    end if; -- clk_sys
  end process;
  
  process(clk_uart,sys_reset)
    variable nxt_bitcnt : integer range 0 to 9 := bitcnt;
    variable nxt_subcnt : integer range 0 to 15 := subcnt;
    variable nxt_data   : std_logic_vector(7 downto 0) := data;

  begin
    if clk_uart'event and clk_uart='1' then 
      if sys_reset='1' then
        nxt_bitcnt:=0;              -- reset bit counter
        nxt_subcnt:=0;              -- reset sub-bit counter
        nxt_data := "00000000";
      else  --- IF NOT RESET
        if (subcnt=0) and (bitcnt=0) and (rx='1') then
          nxt_subcnt := 0;
        else 
          if subcnt=15 then
            nxt_subcnt:=0;
            if bitcnt=9 then
              nxt_bitcnt:=0;
            else
              nxt_bitcnt:=bitcnt+1;
            end if; --bitcnt=9
          else
            nxt_subcnt:=subcnt+1;
            if (subcnt=8) and (bitcnt>0) and (bitcnt<9) then
              nxt_data(bitcnt-1):=rx;
            end if; -- subcnt=8
            if (subcnt>7) and (bitcnt=9) and (rx='0')then   -- terminate mid stop-bit
              nxt_subcnt:=0;
              nxt_bitcnt:=0;
            end if;
          end if; -- subcnt = 15
        end if; -- (subcnt=0) and (bitcnt=0) and (rx='0')
      end if; -- RESET      
        data   <= nxt_data;
        bitcnt <= nxt_bitcnt;
        subcnt <= nxt_subcnt; 
    end if; -- clk_uart'event
  end process;
  
  end rtl;
  
  