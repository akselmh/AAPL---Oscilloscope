----------------------------------------------------------------------------------
-- Company: Domipheus Labs 
-- Engineer: Colin "domipheus" Riley
-- 
-- Create Date: 26.04.2018 23:29:09
-- Design Name: 
-- Module Name: top - Behavioral
-- Project Name: Arty S7 HDMI out to PMod A example.
-- Target Devices: Arty S7 XC7S50 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: VGA/TMDS/DVID code from Mike Field <hamster@snap.net.nz> 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity top is
    Port ( 
        CLK12_I : in STD_LOGIC;
        LED_O : out STD_LOGIC_VECTOR (3 downto 0);
        hdmi_out_p : out STD_LOGIC_VECTOR(3 downto 0);
        hdmi_out_n : out STD_LOGIC_VECTOR(3 downto 0);
        BB_09       : out std_logic;
        BB_10      :   in  std_logic;
        BB_11    :   out  std_logic;
        RX_I    : in std_logic;
        TX_O    : out std_logic;
        BB_08 : in std_logic;
        nBUTTON_I : in std_logic;
        BB_21 : out std_logic;
        BB_22 : in std_logic;
        BB_23 : out std_logic
        
    );
end top;

architecture Behavioral of top is
--    COMPONENT clocking
--    generic (
--        in_mul    : natural := 10;    
--        pix_div   : natural := 30;
--        pix5x_div : natural := 10
--    );
--    PORT ( 
--        I_unbuff_clk         : in  STD_LOGIC;
--        O_buff_clkpixel      : out  STD_LOGIC;
--        O_buff_clk5xpixel    : out  STD_LOGIC;
--        O_buff_clk5xpixelinv : out  STD_LOGIC
--    );
--    END COMPONENT;

    COMPONENT vga_gen
    generic (
            hRez       : natural := 1920;    
            hStartSync : natural := 1920+88;
            hEndSync   : natural := 1920+88+44;
            hMaxCount  : natural := 1920+88+44+148;
            hsyncActive : std_logic := '0';
            
            vRez       : natural := 1080;
            vStartSync : natural := 1080+4;
            vEndSync   : natural := 1080+4+5;
            vMaxCount  : natural := 1080+4+5+36;
            vsyncActive : std_logic := '1';
            prefetch_idx:natural := 8
    );
    PORT(    
        pixel_clock  : in std_logic; 
        pixel_h      : out STD_LOGIC_VECTOR(11 downto 0);
        pixel_v      : out STD_LOGIC_VECTOR(11 downto 0);
        pixel_h_pref : out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
        pixel_v_pref : out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
        blank_pref   : OUT std_logic;
        blank        : OUT std_logic;
        hsync        : OUT std_logic;
        vsync        : OUT std_logic
    );
    END COMPONENT;

    COMPONENT dvid
    PORT(
        clk_5x    : IN std_logic;
        clk_pixel : IN std_logic;
        rst       : IN std_logic;
        red_p     : IN std_logic_vector(7 downto 0);
        green_p   : IN std_logic_vector(7 downto 0);
        blue_p    : IN std_logic_vector(7 downto 0);
        blank     : IN std_logic;
        hsync     : IN std_logic;
        vsync     : IN std_logic;
        red_s     : OUT std_logic;
        green_s   : OUT std_logic;
        blue_s    : OUT std_logic;
        clock_s   : OUT std_logic
    );
    END COMPONENT;

    -- Counter for LEDs
	signal count: unsigned(31 downto 0) := X"00000000";
	
    -- Clock engine    
    --signal cEng_pixel_720 : std_logic;
    --signal cEng_5xpixel_720 : std_logic;    
    --signal cEng_5xpixel_inv_720 : std_logic;
    
    signal clk20                  : std_logic;
    signal clk40                  : std_logic;
    signal clk48                  : std_logic;
    signal cEng_pixel_1080        : std_logic;
    signal cEng_5xpixel_io_1080   : std_logic;
    signal clk_locked             : std_logic;
    signal serdes_rst             : std_logic;

    -- Vga timing
    signal pixel_h : STD_LOGIC_VECTOR(11 downto 0);
    signal pixel_v : STD_LOGIC_VECTOR(11 downto 0);
    signal blank   : std_logic;
    signal hsync   : std_logic;
    signal vsync   : std_logic;    
    
    -- Pixel colour data
    signal red_ram_p   : std_logic_vector(7 downto 0) := (others => '0');
    signal green_ram_p : std_logic_vector(7 downto 0) := (others => '0');
    signal blue_ram_p  : std_logic_vector(7 downto 0) := (others => '0');
    
    signal pixel_h_u : unsigned(11 downto 0);
    signal pixel_v_u : unsigned(11 downto 0);
    
    -- TMDS
    signal red_s   : std_logic;
    signal green_s : std_logic;
    signal blue_s  : std_logic;
    signal clock_s : std_logic;
    
    -- BRAM
    
    signal addra : std_logic_vector(14 downto 0);
    signal addrb : std_logic_vector(14 downto 0);
    signal dina  : std_logic_vector(7 downto 0);
    signal douta : std_logic_vector(7 downto 0);
    signal doutb : std_logic_vector(7 downto 0);
    signal wea   : std_logic_vector(0 downto 0);
    
    signal q_addra : std_logic_vector(7 downto 0);
    signal q_addrb : std_logic_vector(7 downto 0);
    signal q_dina  : std_logic_vector(31 downto 0);
    signal q_doutb : std_logic_vector(31 downto 0);
    signal q_dinb  : std_logic_vector(31 downto 0);
    signal q_douta : std_logic_vector(31 downto 0);
    signal q_wea   : std_logic_vector(0 downto 0);
    signal q_web   : std_logic_vector(0 downto 0);
    
    
    signal sample : std_logic_vector(7 downto 0);
    signal sample_in : std_logic_vector(7 downto 0);
    signal write_ptr : unsigned(14 downto 0) := (others => '0');
    signal sample_r : std_logic_vector(7 downto 0);
    signal sample_int_r : integer range 0 to 255;
    signal y_int_r      : integer;
    
    signal zoom_shift : integer range 0 to 4 := 0; -- 0=1:1, 3=8:1 scale
    signal read_addr_raw : unsigned(14 downto 0);
    signal active_display_area : boolean;
    signal downsample_count : unsigned(15 downto 0) := (others => '0');
    signal downsample_limit : unsigned(15 downto 0) := x"0000"; -- 0 = 1:1, 9 = 1:10, etc.
    signal write_ptr_snap : unsigned(14 downto 0) := (others => '0');
    signal active_display_q1 : boolean := false;
    signal vsync_prev : std_logic := '0';
    signal pixel_v_q1        : unsigned(11 downto 0) := (others => '0');
    
    --ADC
    signal intr_s : std_logic;
    signal adc_word_in : std_logic_vector(7 downto 0);
    signal adc_word_intr : std_logic;
    signal sys_reset : std_logic;                           
    
    signal adr       : std_logic_vector(7 downto 0);        
    signal data_w    : std_logic_vector(31 downto 0);       
    signal data_r    : std_logic_vector(31 downto 0);     
    signal wr,rd     : std_logic;                           
    
    
    
    -- Trigger Signals
    type trig_state_t is (ST_IDLE, ST_CAPTURING, ST_DONE);
    signal trig_state : trig_state_t := ST_IDLE;
    signal trig_threshold : unsigned(7 downto 0) := x"f0"; -- Mid-point trigger (128)
    signal prev_sample : unsigned(7 downto 0) := (others => '0');
    signal post_trig_counter : unsigned(14 downto 0) := (others => '0');
    signal trigger_fired : std_logic := '0';
    signal trig_armed : std_logic := '0';
    signal trig_ready : std_logic := '0';
    signal pot_intr : std_logic := '0';
    signal trig_data : std_logic_vector(7 downto 0);
    
    type fft_state_t is (ST_CAPTURE_TO_FFT, ST_WAIT_FOR_PC, ST_FFT_TO_SCREEN, ST_WAIT_FOR_FFT, ST_NOP, ST_DONE);
    signal fft_state : fft_state_t :=ST_CAPTURE_TO_FFT;
    signal fft_samples_sent_cnt : unsigned(14 downto 0):= (others => '0');
    signal fft_current_addr : unsigned(14 downto 0):= (others => '0');
    signal fft_mode : std_logic := '0';
    signal q_addr_cnt : unsigned(7 downto 0):= x"01";
    signal q_addr_cycle : unsigned(31 downto 0):= (others => '0');
    signal byte_count : integer := 0;
    signal temp_word    :   std_logic_vector(31 downto 0) := (others => '0');
    signal q_counter : std_logic_vector(31 downto 0) := (others => '0');
    
    signal btn_reg        : std_logic_vector(1 downto 0) := "11";
    signal btn_debounce   : unsigned(19 downto 0) := (others => '0'); -- ~26ms at 40MHz
    signal btn_state      : std_logic := '1';
    signal btn_state_prev : std_logic := '1';
    
   
    signal down_btn_reg          : std_logic_vector(1 downto 0) := "11";
    signal down_btn_debounce     : unsigned(19 downto 0) := (others => '0'); 
    signal down_btn_state        : std_logic := '1';
    signal down_btn_state_prev   : std_logic := '1';
    
    signal downsample_shift      : integer range 0 to 4 := 0;
    
    
    signal shifted_h_16 : unsigned(15 downto 0) := (others => '0');
begin
    
    -- increment the counter each 100MHz cycle
    process(CLK12_I)
    begin
        if rising_edge(CLK12_I) then
            count <= count + 1;
        end if;
    end process;
             

    LED_O(0) <= '1' when fft_state = ST_CAPTURE_TO_FFT else '0';     
    LED_O(1) <= '1' when fft_state = ST_WAIT_FOR_PC else '0'; 
    LED_O(2) <= '1' when fft_state = ST_FFT_TO_SCREEN else '0';  
    LED_O(3) <= '1' when fft_state = ST_WAIT_FOR_FFT else '0';   
--    LED_O(0) <= '1' when downsample_shift = 0 else '0';
--    LED_O(1) <= '1' when downsample_shift = 1 else '0';
--    LED_O(2) <= '1' when downsample_shift = 2 else '0';
--    LED_O(3) <= '1' when downsample_shift = 3 else '0';
 
    clk_stage1_inst : entity work.clock_stage1_12_to_20_40_48
    port map (
        I_clk12 => CLK12_I,
        O_clk20 => clk20,
        O_clk48 => clk48,
        O_clk40 => clk40
    );

    clk_stage2_inst : entity work.clock_stage2_20_to_148p5_742p5
    port map (
        I_clk20    => clk20,
        O_clkpixel => cEng_pixel_1080,
        O_clk5x_io => cEng_5xpixel_io_1080,
        O_locked   => clk_locked
    );
 

    Inst_vga_gen: vga_gen 
    generic map (
        hRez        => 1920,
        hStartSync  => 1920+88,
        hEndSync    => 1920+88+44,
        hMaxCount   => 1920+88+44+148,
        hsyncActive => '0',
        vRez        => 1080,
        vStartSync  => 1080+4,
        vEndSync    => 1080+4+5,
        vMaxCount   => 1080+4+5+36,
        vsyncActive => '1'
    )
    PORT MAP( 
        pixel_clock  => cEng_pixel_1080,    
        pixel_h      => pixel_h,
        pixel_v      => pixel_v,
        pixel_h_pref => open,
        pixel_v_pref => open,     
        blank_pref   => open,
        blank        => blank,
        hsync        => hsync,
        vsync        => vsync
    );
    
--QLINK
    qlink : entity work.QLinkMaster
    port map ( 
            RESET_I => '0',
            rx_i => RX_I,
            tx_o => TX_O,
            CLK48_I  => clk48,
            RESET_O   => sys_reset,
            ADDR_B_O    => q_addra,
            DATA_B_O  => q_dina,
            DATA_B_I  => q_douta,
            WR_O      => wr,
            RD_O      => rd -- not used
            
            
           );
    
--ADC
    adc : entity work.adc_stateMachine 
    port map (  
            CS       => BB_09,
            CLK_IN   => clk40,
            SDO      => BB_10,
            SCLK     => BB_11,
            intr     => intr_s,
            data_out => sample_in
    );
    pot : entity work.adc_stateMachine 
    port map (  
            CS       => BB_21,
            CLK_IN   => clk12_I,
            SDO      => BB_22,
            SCLK     => BB_23,
            intr     => pot_intr,
            data_out => trig_data
    );
    
--    adc_word : entity work.adc_to_word 
--      port map (    
--                intr_adc   => adc_word_intr,
--                adc_data    => adc_word_in,
--                CLK_48     => clk40,
--                adc_word    => q_dinb,
--                intr_word   => q_web,
--                enb_sample  => wr,
--                addr_cnt    => q_addrb
--       );

-- BRAM
   
    u_bram : entity work.blk_mem_gen_0
    port map (
        clka  => clk40,
        ena   => '1',
        wea   => wea,
        addra => addra,
        dina  => dina,
        douta => douta,
    
        clkb  => cEng_pixel_1080,
        enb   => '1',
        web => "0",
        addrb => addrb,
        dinb => "00000000",
        doutb => doutb
    );
--    q_wea <= wr & wr & wr & wr;
    q_wea(0) <= wr;
    qlink_bram : entity work.blk_mem_gen_1
    port map (
        clka  => clk48,
        wea   => q_wea,
        addra => q_addra,
        dina  => q_dina,
        douta => q_douta,
        ena => '1',
        enb => '1',
    
        clkb  => clk40,
        web => q_web,
        addrb => q_addrb,
        dinb => q_dinb,
        doutb => q_doutb --not used
    );
    
    
--    process(clk40)
--    begin
--        if rising_edge(clk40) then
--            if intr_s = '1' then
--                -- Only write to BRAM when the counter hits the limit
--                if downsample_count >= downsample_limit then
--                    downsample_count <= (others => '0'); -- Reset counter
                    
--                    wea <= "1";
--                    addra <= std_logic_vector(write_ptr);
--                    dina <= sample_in;
--                    adc_word_in <= sample_in;
--                    adc_word_intr <= '1';
                    
                    
                    
--                    -- Increment BRAM pointer
--                    if write_ptr = 20479 then
--                        write_ptr <= (others => '0');
--                    else
--                        write_ptr <= write_ptr + 1;
--                    end if;
--                else
--                    -- Skip this sample, just increment the downsample counter
--                    downsample_count <= downsample_count + 1;
--                    wea <= "0";
--                    adc_word_intr <= '0';
--                end if;
--            else
--                wea <= "0";
--            end if;
--        end if;
--    end process;
    
    -- Debounce active-low nBUTTON_I and toggle fft_mode
    process(clk40)
    begin
        if rising_edge(clk40) then
           
            btn_reg <= btn_reg(0) & nBUTTON_I;
            
            
            if btn_reg(1) /= btn_state then
                btn_debounce <= btn_debounce + 1;
                
                if btn_debounce = X"FFFFF" then
                    btn_state <= btn_reg(1);
                    btn_debounce <= (others => '0');
                end if;
            else
                btn_debounce <= (others => '0');
            end if;
            
         
            btn_state_prev <= btn_state;
            if btn_state = '1' and btn_state_prev = '0' then
                fft_mode <= not fft_mode;
--                fft_state <= ST_CAPTURE_TO_FFT;
--                q_addr_cycle <= (others=> '0');
--                q_addrb <= x"00";
            end if;
        end if;
    end process;
    
    process(clk40)
    begin
        if rising_edge(clk40) then
            
            down_btn_reg <= down_btn_reg(0) & BB_08;
            
           
            if down_btn_reg(1) /= down_btn_state then
                down_btn_debounce <= down_btn_debounce + 1;
                if down_btn_debounce = X"FFFFF" then
                    down_btn_state <= down_btn_reg(1);
                    down_btn_debounce <= (others => '0');
                end if;
            else
                down_btn_debounce <= (others => '0');
            end if;
            
            
            down_btn_state_prev <= down_btn_state;
            if down_btn_state = '1' and down_btn_state_prev = '0' then
                if fft_mode = '0' then
                    
                    if downsample_shift = 4 then
                        downsample_shift <= 0;
                    else
                        downsample_shift <= downsample_shift + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    
    process(clk12_I)
    begin
        if rising_edge(clk12_I) then
            if pot_intr = '1' then
                trig_threshold <= unsigned(trig_data);
            end if;
        end if;
    end process;
    process(clk40)
    begin
        if rising_edge(clk40) then
            vsync_prev <= vsync;
            if fft_mode = '0' then
                fft_state <= ST_CAPTURE_TO_FFT;
                if intr_s = '1' then
                    case trig_state is
                        when ST_IDLE =>
                            
                            if unsigned(sample_in) < (trig_threshold - 3) then
                                trig_ready <= '1';
                            end if;
                        
                           
                            if (trig_ready = '1') and (unsigned(sample_in) >= trig_threshold) and (prev_sample < trig_threshold) then
                                trig_state <= ST_CAPTURING;
                                trig_ready <= '0'; 
                                post_trig_counter <= (others => '0');
                                write_ptr_snap <= write_ptr; 
                            end if;
                            
                            
                            wea <= "1";
                            addra <= std_logic_vector(write_ptr);
                            dina <= sample_in;
                            write_ptr <= write_ptr + 1;
    
                        when ST_CAPTURING =>
                           
                            wea <= "1";
                            addra <= std_logic_vector(write_ptr);
                            dina <= sample_in;
                            
                            if post_trig_counter = 32767 then
                                trig_state <= ST_DONE;
                                wea <= "0";
                            else
                                post_trig_counter <= post_trig_counter + 1;
                                write_ptr <= write_ptr + 1;
                            end if;
    
                        when ST_DONE =>
                            wea <= "0";
                            
                            
                            if vsync = '1' and vsync_prev = '0' then 
                                
                                 trig_state <= ST_IDLE; 
                            end if;
                    end case;
                    prev_sample <= unsigned(sample_in);
                    adc_word_in <= sample_in;
                    adc_word_intr <= '1';
                else
                    wea <= "0";
                    adc_word_intr <= '0';
                end if;
            else 
                case fft_state is
                    when ST_CAPTURE_TO_FFT =>
                        addra <= std_logic_vector(write_ptr_snap + fft_current_addr);
                        wea <= "0";
                        fft_current_addr <= fft_current_addr + 1;
                        
                        if fft_current_addr = 32767 then
                            fft_state <= ST_WAIT_FOR_FFT;
                            fft_samples_sent_cnt <= (others => '0');
                            q_addr_cycle <= q_addr_cycle + 1;
                            q_addrb <= x"00";
                            q_dinb <= std_logic_vector(q_addr_cycle + 1);
                            q_web <= "1";
                        else
                            temp_word <= temp_word(23 downto 0) & douta;
                            
                            if byte_count = 3 then
                                q_dinb <= temp_word(23 downto 0) & douta;
                                
                                q_addrb <= std_logic_vector(q_addr_cnt);
                                if q_addr_cnt = 255 then
                                    fft_state <= ST_WAIT_FOR_PC;
                                    q_addr_cycle <= q_addr_cycle + 1;
                                    q_addrb <= x"00";
                                    q_dinb <= std_logic_vector(q_addr_cycle+1);
                                    q_web <= "1";
                                else
                                    q_addr_cnt <= q_addr_cnt + 1;
                                    q_web <= "1";
                                end if;
                            
                                byte_count <= 0;
                            else
                                byte_count <= byte_count + 1;
                                q_web <= "0";
                            end if;
                        end if;
                        
                    when ST_WAIT_FOR_PC =>
                        q_addrb <= x"00";
                        q_web <= "0"; 
                        q_counter <= q_doutb; 
                    
                        
                        if unsigned(q_counter) = (q_addr_cycle + 1) then
                            fft_state <= ST_CAPTURE_TO_FFT;
                            q_addr_cnt <= x"01";
                            q_addr_cycle <= q_addr_cycle + 1; 
                        end if;
                    when ST_WAIT_FOR_FFT =>
                        q_counter <= q_doutb;
                        q_addrb <= x"00"; 
                        q_web <= "0";
                        if unsigned(q_counter) = (q_addr_cycle + 1) then
                            fft_state <= ST_FFT_TO_SCREEN;
                            
                           
                            q_addrb <= x"01"; 
                            byte_count <= 0;
                            q_addr_cycle <= q_addr_cycle + 1;
--                            fft_samples_sent_cnt <= (others => '0'); 
--                            fft_samples_sent_cnt <= "000001111111011";
                        end if;

                    when ST_FFT_TO_SCREEN =>
                        if fft_samples_sent_cnt < 1920 then
                            wea <= "1";
                            addra <= std_logic_vector(
                                write_ptr_snap + 
                                fft_samples_sent_cnt
                             );                            
                            
                            case byte_count is
                                when 0 => dina <= q_doutb(31 downto 24);
                                when 1 => dina <= q_doutb(23 downto 16);
                                when 2 => dina <= q_doutb(15 downto 8);
                                when 3 => dina <= q_doutb(7 downto 0);
                                when others => dina <= x"00";
                            end case;
                            fft_samples_sent_cnt <= fft_samples_sent_cnt + 1;
                            if byte_count = 3 then
                                byte_count <= 0;
                                
                                if fft_samples_sent_cnt = 1019 then 
                                    
                                    wea <= "0";
                                    q_addr_cycle <= q_addr_cycle + 1; 
                                    q_addrb <= x"00"; 
                                    q_dinb <= std_logic_vector(q_addr_cycle + 1);
                                    q_web <= "1";
                                    fft_state <= ST_NOP; 
                                else
                                   
                                    q_addrb <= std_logic_vector(unsigned(q_addrb) + 1);
                                    q_web <= "0";
                                end if;
                            else
                                q_web <= "0";
                                byte_count <= byte_count + 1;
                            end if;
                        else
                            
                            wea <= "0";
                            fft_state <= ST_DONE; 
                            q_addrb <= x"00"; 
                            q_dinb <= (others => '0');
                            q_web <= "1";
                            fft_samples_sent_cnt <= (others => '0');
                            q_addr_cycle <= (others=> '0');
                            fft_current_addr <=(others=> '0');
                            
                        end if;
                    when ST_NOP =>
                        fft_state <= ST_WAIT_FOR_FFT; 
                        q_web <= "1";
                    when ST_DONE =>
--                        fft_state <= ST_CAPTURE_TO_FFT; 
                        q_addrb <= x"00"; 
                        q_dinb <= (others => '0');
                        q_web <= "1";
                        fft_samples_sent_cnt <= (others => '0');
                        q_addr_cycle <= (others=> '0');
                        fft_current_addr <=(others=> '0');
                end case;
                
            end if;
            
        end if;
    end process;
    
 
    

    pixel_h_u <= unsigned(pixel_h);
    pixel_v_u <= unsigned(pixel_v);



    process(cEng_pixel_1080)
        variable live_addr_ext : unsigned(15 downto 0);
    begin
        if rising_edge(cEng_pixel_1080) then
            
          
            if fft_mode = '1' then
                shifted_h_16 <= resize(unsigned(pixel_h), 16);
            else
                shifted_h_16 <= shift_left(resize(unsigned(pixel_h), 16), downsample_shift);
            end if;

            
            live_addr_ext := resize(write_ptr_snap, 16) + shifted_h_16;

          
            if (unsigned(pixel_h) < 1920) and (unsigned(pixel_v) < 1080) then
                if fft_mode = '0' and shifted_h_16 >= 32768 then
                    active_display_area <= false;
                    addrb <= (others => '0');
                else
                    active_display_area <= true;
                    addrb <= std_logic_vector(live_addr_ext(14 downto 0));
                end if;
            else
                active_display_area <= false;
                addrb <= (others => '0');
            end if;

            
            active_display_q1 <= active_display_area;
            pixel_v_q1        <= unsigned(pixel_v);

           
            sample_int_r      <= to_integer(unsigned(doutb));
            y_int_r           <= 924 - (sample_int_r * 3);

        end if;
    end process;

    process(cEng_pixel_1080)
        variable v_pos : integer;
        variable diff  : integer;
    begin
        if rising_edge(cEng_pixel_1080) then
            
            v_pos := to_integer(pixel_v_q1);
            diff  := v_pos - y_int_r;
    
            -- Default Background
            red_ram_p   <= x"00";
            green_ram_p <= x"00";
            blue_ram_p  <= x"20"; 
    
            if active_display_q1 then
                -- Waveform
                if abs(diff) < 2 then
                    green_ram_p <= x"FF";
                    blue_ram_p  <= x"00";
                end if;
    
                -- Graticule
                if v_pos = 924 then
                    red_ram_p   <= x"40";
                    green_ram_p <= x"40";
                    blue_ram_p  <= x"40";
                end if;
                if v_pos = 924-(TO_INTEGER(trig_threshold)*3) then
                    red_ram_p   <= x"a0";
                    green_ram_p <= x"a0";
                    blue_ram_p  <= x"00";
                end if;
            end if;
        end if;
    end process;

   
    serdes_rst <= not clk_locked;
    -- TMDS signal generation

    dvid_1: dvid PORT MAP(
        clk_5x     => cEng_5xpixel_io_1080,
        clk_pixel  => cEng_pixel_1080,
        rst        => serdes_rst,
        red_p      => red_ram_p,
        green_p    => green_ram_p,
        blue_p     => blue_ram_p,
        blank      => blank,
        hsync      => hsync,
        vsync      => vsync,
        red_s      => red_s,
        green_s    => green_s,
        blue_s     => blue_s,
        clock_s    => clock_s
    );
    
    -- Differential output buffers
    OBUFDS_blue  : OBUFDS port map ( O  => hdmi_out_p(0), OB => hdmi_out_n(0), I  => blue_s );
    OBUFDS_green   : OBUFDS port map ( O  => hdmi_out_p(1), OB => hdmi_out_n(1), I  => green_s );
    OBUFDS_red : OBUFDS port map ( O  => hdmi_out_p(2), OB => hdmi_out_n(2), I  => red_s );
    OBUFDS_clock : OBUFDS port map ( O  => hdmi_out_p(3), OB => hdmi_out_n(3), I  => clock_s );

end Behavioral;
