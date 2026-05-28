library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity clock_stage2_20_to_148p5_742p5 is
    Port (
        I_clk20         : in  STD_LOGIC;
        O_clkpixel      : out STD_LOGIC;
        O_clk5x_io      : out STD_LOGIC;
        O_locked        : out STD_LOGIC
    );
end clock_stage2_20_to_148p5_742p5;

architecture rtl of clock_stage2_20_to_148p5_742p5 is
    signal clk20_buf      : std_logic;
    signal clkpixel_unbuf : std_logic;
    signal clk5x_unbuf    : std_logic;
    signal clkfb          : std_logic;
    signal locked         : std_logic;
begin

    BUFG_in : BUFG
    port map (
        I => I_clk20,
        O => clk20_buf
    );

    MMCM_stage2 : MMCME2_BASE
    generic map (
        BANDWIDTH          => "OPTIMIZED",
        CLKIN1_PERIOD      => 50.0,
        DIVCLK_DIVIDE      => 1,
        CLKFBOUT_MULT_F    => 37.125,

        -- 27 * 27.5 / 5 = 148.5 MHz
        CLKOUT0_DIVIDE_F   => 5.0,
        CLKOUT0_PHASE      => 0.0,
        CLKOUT0_DUTY_CYCLE => 0.5,

        -- 27 * 27.5 / 1 = 742.5 MHz
        CLKOUT1_DIVIDE     => 1,
        CLKOUT1_PHASE      => 0.0,
        CLKOUT1_DUTY_CYCLE => 0.5,

        CLKOUT2_DIVIDE     => 1,
        CLKOUT3_DIVIDE     => 1,
        CLKOUT4_DIVIDE     => 1,
        CLKOUT5_DIVIDE     => 1,
        CLKOUT6_DIVIDE     => 1,

        REF_JITTER1        => 0.010,
        STARTUP_WAIT       => FALSE
    )
    port map (
        CLKIN1   => clk20_buf,
        CLKFBIN  => clkfb,
        CLKFBOUT => clkfb,

        CLKOUT0  => clkpixel_unbuf,
        CLKOUT1  => clk5x_unbuf,
        CLKOUT2  => open,
        CLKOUT3  => open,
        CLKOUT4  => open,
        CLKOUT5  => open,
        CLKOUT6  => open,

        LOCKED   => locked,
        PWRDWN   => '0',
        RST      => '0'
    );

    BUFG_pix : BUFG
    port map (
        I => clkpixel_unbuf,
        O => O_clkpixel
    );

    BUFIO_5x : BUFIO
    port map (
        I => clk5x_unbuf,
        O => O_clk5x_io
    );

    O_locked <= locked;

end rtl;