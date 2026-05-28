library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity tmds_oserdes_lane is
    Port (
        clk_5x     : in  STD_LOGIC;
        clk_pixel  : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        data_10b   : in  STD_LOGIC_VECTOR(9 downto 0);
        serial_out : out STD_LOGIC
    );
end tmds_oserdes_lane;

architecture rtl of tmds_oserdes_lane is
    signal shift1   : std_logic;
    signal shift2   : std_logic;
    signal data_reg : std_logic_vector(9 downto 0) := (others => '0');
begin

    process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            data_reg <= data_10b;
        end if;
    end process;

    OSERDES_slave : OSERDESE2
    generic map (
        DATA_RATE_OQ   => "DDR",
        DATA_RATE_TQ   => "BUF",
        DATA_WIDTH     => 10,
        SERDES_MODE    => "SLAVE",
        TRISTATE_WIDTH => 1
    )
    port map (
        OQ         => open,
        OFB        => open,
        TQ         => open,
        TFB        => open,

        CLK        => clk_5x,
        CLKDIV     => clk_pixel,
        D1         => '0',
        D2         => '0',
        D3         => data_reg(8),
        D4         => data_reg(9),
        D5         => '0',
        D6         => '0',
        D7         => '0',
        D8         => '0',

        OCE        => '1',
        TCE        => '0',
        RST        => rst,

        SHIFTIN1   => '0',
        SHIFTIN2   => '0',
        SHIFTOUT1  => shift1,
        SHIFTOUT2  => shift2,

        T1         => '0',
        T2         => '0',
        T3         => '0',
        T4         => '0',
        TBYTEIN    => '0',
        TBYTEOUT   => open
    );

    OSERDES_master : OSERDESE2
    generic map (
        DATA_RATE_OQ   => "DDR",
        DATA_RATE_TQ   => "BUF",
        DATA_WIDTH     => 10,
        SERDES_MODE    => "MASTER",
        TRISTATE_WIDTH => 1
    )
    port map (
        OQ         => serial_out,
        OFB        => open,
        TQ         => open,
        TFB        => open,

        CLK        => clk_5x,
        CLKDIV     => clk_pixel,
        D1         => data_reg(0),
        D2         => data_reg(1),
        D3         => data_reg(2),
        D4         => data_reg(3),
        D5         => data_reg(4),
        D6         => data_reg(5),
        D7         => data_reg(6),
        D8         => data_reg(7),

        OCE        => '1',
        TCE        => '0',
        RST        => rst,

        SHIFTIN1   => shift1,
        SHIFTIN2   => shift2,
        SHIFTOUT1  => open,
        SHIFTOUT2  => open,

        T1         => '0',
        T2         => '0',
        T3         => '0',
        T4         => '0',
        TBYTEIN    => '0',
        TBYTEOUT   => open
    );

end rtl;