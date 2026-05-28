----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/14/2026 09:03:37 AM
-- Design Name: 
-- Module Name: adc_stateMachine - Behavioral
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
USE ieee.std_logic_arith.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity adc_stateMachine is
    Port (  CS       :   out std_logic := '1';
            CLK_IN   :   in std_logic;
            SDO      :   in  std_logic;
            SCLK     :   out  std_logic;
            intr     :   out std_logic;
            data_out:    out std_logic_vector(7 downto 0) := (others => '0');
            test_pin :   out std_logic
    );
end adc_stateMachine;

architecture Behavioral of adc_stateMachine is

TYPE STATE_TYPE IS (
    S_CS_LOW,
    S_SHIFT,
    S_CS_HIGH
);

    signal sclk_temp : std_logic := '0';
    
    signal read_now : std_logic;
    signal temp_out : std_logic_vector(16-1 downto 0) := (others => '0');
    signal current_state    :  STATE_TYPE := S_CS_LOW ;
    signal bit_counter  : integer := 0;
    signal tw1_count    : integer := 0;
    -- SIGNAL next_state : STATE_TYPE ;


begin
    SCLK <= CLK_IN;
    process(CLK_IN)
    begin
        --SCLK <= CLK_IN;
        
     
        if rising_edge(CLK_IN) then
        case current_state is
            
            when S_CS_LOW =>
                CS <= '0';
                bit_counter <= 0;
                current_state <= S_SHIFT;
                intr <= '0';
                data_out <= (others => '0');
                tw1_count <= 0;
                test_pin <= '0';    
            
             when S_SHIFT =>
--                sclk_temp <= not sclk_temp;
                -- først 2 byte der er 0 --> NOP
                -- de næste 8 er data
                -- tæl til 6 stks 0 igen --> NOP
--                if sclk_temp = '0' then
                if bit_counter = 15 then
                    test_pin <= '0';
                    intr <= '1';
                    data_out <= temp_out(16-3 downto 6);
                    current_state <= S_CS_HIGH;
                else
                    temp_out <=  temp_out(16-2 downto 0) & SDO;
                    bit_counter <= bit_counter + 1;                
                end if;

                
            when S_CS_HIGH =>
                test_pin <= '1';
            
                CS <= '1';
                intr <= '0';
                sclk_temp <= '0';
                data_out <= temp_out(16-3 downto 6);
                current_state <= S_CS_LOW;
                    
            end case;
        
        end if;
        
    
    end process;



end Behavioral;

