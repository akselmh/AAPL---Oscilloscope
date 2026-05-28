-------------------------------------------------------------------
-- Encode_Serial  : Sending part of UART
-- Revision       : 2019-11-14
-- Submodule for  : QLinkMaster
-- 
-- (C) 2019  Anders Stengaard Sørensen (Author), Denmark
-- 
-- This VHDL source fil may be used, distributed and changed in any way, by anyone on the following conditions:
-- 1) The Author provide no guarantee and is not in any way liable for any issues that arise from the use of this source
-- For more information, see the QLinkMaster module source
--
-- Encode 8 parallel bits into 3mbps 8N1 serial stream
--
   
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- USE ieee.numeric_std.ALL; 

entity encode_serial is
    Port ( RESET_I    : in STD_LOGIC;
--           CLK_SYS_I  : in STD_LOGIC;
           CLK_UART_I : in STD_LOGIC;
           DATA_I     : in STD_LOGIC_VECTOR(7 downto 0);
           WR_I       : in STD_LOGIC;
           TX_O       : out STD_LOGIC;
           BUSY_O     : out STD_LOGIC );
end entity;

architecture rtl of encode_serial is

  signal bitcnt   : integer range 0 to 9;
  signal subcnt   : integer range 0 to 15;
  signal data     : std_logic_vector(7 downto 0);
  signal wr       : std_logic;
  signal tx_req   : std_logic;
  signal tx_done  : std_logic;
  signal clk_uart : std_logic;
--  signal clk_sys  : std_logic;
  signal reset    : std_logic;
  signal tx       : std_logic;
 
  
begin


reset<=RESET_I;
-- clk_sys<=CLK_SYS_I;
clk_uart<=CLK_UART_I;
TX_O<=tx;
wr<=WR_I;
BUSY_O<=tx_req;

process(clk_uart,reset)
 
begin
  if clk_uart'event and clk_uart='1' then
    if reset='1' then
      tx_req<='0';
      data<="00000000";
    else
      if wr='1' then
        tx_req<='1';
        data <= DATA_I;
      else 
        data<=data;
        if tx_done='1' then
          tx_req<='0';
        else
          tx_req<=tx_req;
        end if;
      end if;
    end if; -- RESET
  end if;
end process;

process(clk_uart,reset)

  variable nxt_bitcnt : integer range 0 to 9;
  variable nxt_subcnt : integer range 0 to 15;
  variable nxt_tx_done : std_logic;
  variable nxt_tx: std_logic;
  
begin
  if clk_uart'event and clk_uart='1' then
    if reset='1' or tx_req='0' then
      nxt_bitcnt:=0;
      nxt_subcnt:=0;
      nxt_tx:='1';
      nxt_tx_done:='0';
    else
      nxt_tx_done:=tx_done;
      if subcnt<15 then
        nxt_subcnt:=subcnt+1;
      else
        nxt_subcnt:=0;
        if bitcnt<9 then
          nxt_bitcnt:=bitcnt+1;
        else
          nxt_tx_done:='1';
          if tx_req='1' then
            nxt_bitcnt:=bitcnt;
            nxt_subcnt:=subcnt;
          else
            nxt_bitcnt:=0;
          end if;
        end if;
      end if;
      
      if bitcnt=0 then
        nxt_tx:='0'; -- start bit
      elsif bitcnt<9 then
        nxt_tx:=data(bitcnt-1);
      else 
        nxt_tx:='1'; -- stop bit
      end if; -- bitcnt=0
   end if; -- RESET
    
   bitcnt<=nxt_bitcnt;
   subcnt<=nxt_subcnt;
   tx_done<=nxt_tx_done;
   tx<=nxt_tx;
 
  end if; -- CLK
  
end process;

end rtl;
   