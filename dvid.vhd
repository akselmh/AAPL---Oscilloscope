library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity dvid is
    Port (
        clk_5x    : in  STD_LOGIC;
        clk_pixel : in  STD_LOGIC;
        rst       : in  STD_LOGIC;
        red_p     : in  STD_LOGIC_VECTOR (7 downto 0);
        green_p   : in  STD_LOGIC_VECTOR (7 downto 0);
        blue_p    : in  STD_LOGIC_VECTOR (7 downto 0);
        blank     : in  STD_LOGIC;
        hsync     : in  STD_LOGIC;
        vsync     : in  STD_LOGIC;
        red_s     : out STD_LOGIC;
        green_s   : out STD_LOGIC;
        blue_s    : out STD_LOGIC;
        clock_s   : out STD_LOGIC
    );
end dvid;

architecture Behavioral of dvid is
    COMPONENT TDMS_encoder
    PORT(
        clk     : IN  std_logic;
        data    : IN  std_logic_vector(7 downto 0);
        c       : IN  std_logic_vector(1 downto 0);
        blank   : IN  std_logic;
        encoded : OUT std_logic_vector(9 downto 0)
    );
    END COMPONENT;

    signal encoded_red   : std_logic_vector(9 downto 0);
    signal encoded_green : std_logic_vector(9 downto 0);
    signal encoded_blue  : std_logic_vector(9 downto 0);

    signal latched_red   : std_logic_vector(9 downto 0) := (others => '0');
    signal latched_green : std_logic_vector(9 downto 0) := (others => '0');
    signal latched_blue  : std_logic_vector(9 downto 0) := (others => '0');

    signal tmds_clock    : std_logic_vector(9 downto 0) := (others => '0');

    constant c_red       : std_logic_vector(1 downto 0) := (others => '0');
    constant c_green     : std_logic_vector(1 downto 0) := (others => '0');
    signal   c_blue      : std_logic_vector(1 downto 0);

begin
    c_blue <= vsync & hsync;

    TDMS_encoder_red: TDMS_encoder
    port map (
        clk     => clk_pixel,
        data    => red_p,
        c       => c_red,
        blank   => blank,
        encoded => encoded_red
    );

    TDMS_encoder_green: TDMS_encoder
    port map (
        clk     => clk_pixel,
        data    => green_p,
        c       => c_green,
        blank   => blank,
        encoded => encoded_green
    );

    TDMS_encoder_blue: TDMS_encoder
    port map (
        clk     => clk_pixel,
        data    => blue_p,
        c       => c_blue,
        blank   => blank,
        encoded => encoded_blue
    );

    process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            latched_red   <= encoded_red;
            latched_green <= encoded_green;
            latched_blue  <= encoded_blue;
            tmds_clock    <= "1111100000";
        end if;
    end process;

    red_lane : entity work.tmds_oserdes_lane
    port map (
        clk_5x     => clk_5x,
        clk_pixel  => clk_pixel,
        rst        => rst,
        data_10b   => latched_red,
        serial_out => red_s
    );

    green_lane : entity work.tmds_oserdes_lane
    port map (
        clk_5x     => clk_5x,
        clk_pixel  => clk_pixel,
        rst        => rst,
        data_10b   => latched_green,
        serial_out => green_s
    );

    blue_lane : entity work.tmds_oserdes_lane
    port map (
        clk_5x     => clk_5x,
        clk_pixel  => clk_pixel,
        rst        => rst,
        data_10b   => latched_blue,
        serial_out => blue_s
    );

    clock_lane : entity work.tmds_oserdes_lane
    port map (
        clk_5x     => clk_5x,
        clk_pixel  => clk_pixel,
        rst        => rst,
        data_10b   => tmds_clock,
        serial_out => clock_s
    );

end Behavioral;