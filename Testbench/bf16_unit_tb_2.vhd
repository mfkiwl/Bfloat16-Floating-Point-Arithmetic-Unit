library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bf16_unit_tb_2 is
end bf16_unit_tb_2;

architecture driver of bf16_unit_tb_2 is
    component bf16_unit
        port(
            clk: in std_logic;
            reset: in std_logic;
            in1: in std_logic_vector(15 downto 0) ;
            in2: in std_logic_vector(15 downto 0) ;
            in3: in std_logic_vector(15 downto 0) ;
            funct5: in std_logic_vector(4 downto 0) ;
            result: out std_logic_vector(15 downto 0)
        );
end component;

signal tb_clk: std_logic := '0' ;
signal tb_reset: std_logic:= '0' ;
signal tb_in1: std_logic_vector(15 downto 0) := (others =>'0') ;
signal tb_in2: std_logic_vector(15 downto 0) := (others =>'0') ;
signal tb_in3: std_logic_vector(15 downto 0) := (others =>'0') ;
signal tb_funct5: std_logic_vector(4 downto 0) := "00000";
signal tb_result: std_logic_vector(15 downto 0);

constant ClockFrequency: integer := 100e6; --100MHz
constant ClockPeriod: time := 1000ms / ClockFrequency;

begin
    UUT: bf16_unit port map (   clk => tb_clk,
				                reset => tb_reset,
				                in1 => tb_in1,
                        	    in2 => tb_in2,
                                in3 => tb_in3,
				                funct5 => tb_funct5,
                             	result => tb_result );

    p1: process
        begin
            tb_clk <= '1';
            wait for ClockPeriod/2;  --for 10 ns signal is '0'.
            tb_clk <= '0';
            wait for ClockPeriod/2;  --for next 10 ns signal is '1'.
    end process p1;
                                 
    tb_reset <= '1' after 20ns;

    p2: process is
        begin
            wait for 30ns ;
            for i in 1 to 6 loop
                tb_in1 <= "0000000000000000"; tb_in2 <= "0000000000000000"; tb_in3 <= "0000000000000000"; wait for ClockPeriod;
                tb_in1 <= "0100010001011000"; tb_in2 <= "1100010001111000"; tb_in3 <= "1100011100011000"; wait for ClockPeriod;
                tb_in1 <= "1100010001111000"; tb_in2 <= "0100010001011000"; tb_in3 <= "0100011011011111"; wait for ClockPeriod;
                tb_in1 <= "0001010001000010"; tb_in2 <= "0001011001001011"; tb_in3 <= "0001011001001011"; wait for ClockPeriod;
                tb_in1 <= "0100101001001011"; tb_in2 <= "0000001001101000"; tb_in3 <= "0000001001101000"; wait for ClockPeriod;
                tb_in1 <= "1000000011101000"; tb_in2 <= "0000001001101000"; tb_in3 <= "0000001001101000"; wait for ClockPeriod;
                tb_in1 <= "0111111110011000"; tb_in2 <= "1000100101001000"; tb_in3 <= "1000100101001000"; wait for ClockPeriod;
                tb_in1 <= "1100011001001101"; tb_in2 <= "1100011110011000"; tb_in3 <= "1100011110011000"; wait for ClockPeriod;
                tb_in1 <= "1000000001001101"; tb_in2 <= "1000000100001010"; tb_in3 <= "1000000100001010"; wait for ClockPeriod;
                tb_in1 <= "0000000000000000"; tb_in2 <= "0000000000011100"; tb_in3 <= "0000000000011100"; wait for ClockPeriod;
                tb_in1 <= "1111111110000000"; tb_in2 <= "0100000011110011"; tb_in3 <= "0100000011110011"; wait for ClockPeriod;
                tb_in1 <= "0100000011110011"; tb_in2 <= "0100000011110011"; tb_in3 <= "0100000011110011"; wait for ClockPeriod;
                tb_in1 <= "1100000011110011"; tb_in2 <= "0100000011110011"; tb_in3 <= "0100000011110011"; wait for ClockPeriod;
                tb_in1 <= "0100001100101100"; tb_in2 <= "1100010111101010"; tb_in3 <= "1100100111101010"; wait for ClockPeriod;
                tb_in1 <= "0100001100001100"; tb_in2 <= "1100001101101010"; tb_in3 <= "1100001101101010"; wait for ClockPeriod;
                tb_in1 <= "0100001101101100"; tb_in2 <= "1100001101101010"; tb_in3 <= "1100001101101010"; wait for ClockPeriod;
                tb_in1 <= "1011111010000000"; tb_in2 <= "0100000011000000"; tb_in3 <= "0100000011000000"; wait for ClockPeriod;
                tb_in1 <= "1100000011000000"; tb_in2 <= "1100000111001000"; tb_in3 <= "1100000111001000"; wait for ClockPeriod;
                tb_in1 <= "0010101010000111"; tb_in2 <= "0110101010100111"; tb_in3 <= "0110101010100111"; wait for ClockPeriod;
                tb_in1 <= "0010101010000111"; tb_in2 <= "0100010000100011"; tb_in3 <= "0100010000100011"; wait for ClockPeriod;
                tb_in1 <= "0100010110100000"; tb_in2 <= "0100000110100000"; tb_in3 <= "0100000110100000"; wait for ClockPeriod;
                
                tb_funct5 <= std_logic_vector(unsigned(tb_funct5)+1);
            end loop;
            wait;
    end process p2;

end architecture;
