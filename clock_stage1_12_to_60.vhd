----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/16/2026 06:57:37 PM
-- Design Name: 
-- Module Name: clock_stage1_12_to_60 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity clock_stage1_12_to_20_40_48 is
    Port (
        I_clk12  : in  STD_LOGIC;
        O_clk40  : out STD_LOGIC;
        O_clk48  : out STD_LOGIC;
        O_clk20  : out std_logic
    );
end clock_stage1_12_to_20_40_48;

architecture rtl of clock_stage1_12_to_20_40_48 is
    signal clk12_buf   : std_logic;
    signal clk20_unbuf : std_logic;
    signal clk40_unbuf : std_logic;
    signal clk48_unbuf : std_logic;
    signal clkfb       : std_logic;
    signal locked      : std_logic;
begin

    -- Put the 12 MHz board clock onto the global clock network
    BUFG_in : BUFG
    port map (
        I => I_clk12,
        O => clk12_buf
    );

    -- MMCM stage 1:
    -- 12 MHz * 62.5 / 12.5 = 60 MHz
    -- 12 * 63 / 28 = 27 MHz
    MMCM_stage1 : MMCME2_BASE
    generic map (
        BANDWIDTH        => "OPTIMIZED",
        CLKIN1_PERIOD    => 83.333,
        DIVCLK_DIVIDE    => 1,
        CLKFBOUT_MULT_F  => 60.0,
        CLKOUT0_DIVIDE_F => 15.0,
        CLKOUT0_PHASE    => 0.0,
        CLKOUT1_PHASE      => 0.0,
        CLKOUT0_DUTY_CYCLE => 0.5,
        CLKOUT1_DUTY_CYCLE => 0.5,
        CLKOUT1_DIVIDE   => 18,
        CLKOUT2_DIVIDE   => 36,
        CLKOUT3_DIVIDE   => 1,
        CLKOUT4_DIVIDE   => 1,
        CLKOUT5_DIVIDE   => 1,
        CLKOUT6_DIVIDE   => 1,
        REF_JITTER1      => 0.010,
        STARTUP_WAIT     => FALSE
    )
    port map (
        CLKIN1   => clk12_buf,
        CLKFBIN  => clkfb,
        CLKFBOUT => clkfb,

        CLKOUT0  => clk48_unbuf,
        CLKOUT1  => clk40_unbuf,
        CLKOUT2  => clk20_unbuf,
        CLKOUT3  => open,
        CLKOUT4  => open,
        CLKOUT5  => open,
        CLKOUT6  => open,

        LOCKED   => locked,
        PWRDWN   => '0',
        RST      => '0'
    );
    
    BUFG_20 : BUFG
    port map (
        I => clk20_unbuf,
        O => O_clk20
    );
    BUFG_40 : BUFG
    port map (
        I => clk40_unbuf,
        O => O_clk40
    );
    BUFG_48 : BUFG
    port map (
        I => clk48_unbuf,
        O => O_clk48
    );

end rtl;