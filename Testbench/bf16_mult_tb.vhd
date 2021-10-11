library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bf16_mult_tb is
end bf16_mult_tb;

architecture driver of bf16_mult_tb is
    component bf16_mult
        port(
        clk: in std_logic;
        reset: in std_logic;
        in1: in std_logic_vector(15 downto 0) ;
        in2: in std_logic_vector(15 downto 0) ;
        result: out std_logic_vector(15 downto 0)
    );
end component;

signal tb_clk: std_logic := '0' ;
signal tb_reset: std_logic:= '0' ;
signal tb_in1: std_logic_vector(15 downto 0) := (others =>'0') ;
signal tb_in2: std_logic_vector(15 downto 0) := (others =>'0') ;
signal tb_result: std_logic_vector(15 downto 0);

constant ClockFrequency: integer := 100e6; --100MHz
constant ClockPeriod: time := 1000ms / ClockFrequency;

begin
    UUT: bf16_mult port map (   clk => tb_clk,
				                reset => tb_reset,
				                in1 => tb_in1,
                        	    in2 => tb_in2,
                             	result => tb_result );

p1: process
begin
    tb_clk <= '1';
    wait for ClockPeriod/2;  --for 10 ns signal is '0'.
    tb_clk <= '0';
    wait for ClockPeriod/2;  --for next 10 ns signal is '1'.
end process p1;
                                 
    tb_reset <= '1' after 20ns;
    
    tb_in1 <= "0100010001011000" after 30ns,   --   1.1011000*(2^9)
	          "1100010001111000" after 40ns,   --  -1.1111000*(2^9)
	          "0001010001000010" after 50ns,   --   1.1000010*(2^-87)
	          "0100101001001011" after 60ns,   --   1.1001011*(2^21)
	          "1000000011101000" after 70ns,   --  -1.1101000*(2^-126)
	          "0111111110011000" after 80ns,   --   NaN
	          "1100011001001101" after 90ns,   --  -1.1001101*(2^13)
	          "1000000001001101" after 100ns,   --  -0
	          "0000000000000000" after 110ns,  --   0
	          "1111111110000000" after 120ns,  --  -inf
              "0100000011110011" after 130ns,  --   1.1110011*(2^2)
              "1100000011110011" after 140ns,  --  -1.1110011*(2^2)
              "0100001100101100" after 150ns,  --   1.0101100*(2^7)
              "0100001100001100" after 160ns,  --   1.0001100*(2^7)
              "0100001101101100" after 170ns,  --   1.1101100*(2^7)
              "1011111010000000" after 180ns,  --  -0.25
              "1100000011000000" after 190ns,  --  -6
              "0010101010000111" after 200ns,  --  +1.0000111*2^(-42)
              "0010101010000111" after 210ns,  --  +1.0000111*2^(-42)
              "0100010110100000" after 220ns;  --  +1.0100000*2^(12) (5632)
	      
    tb_in2 <= "1100010001111000" after 30ns,   --  -1.1111000*(2^9)
	          "0100010001011000" after 40ns,   --   1.1011000*(2^9)
              "0001011001001011" after 50ns,   --   1.1001011*(2^-83)
              "0000001001101000" after 60ns,   --   1.1101000*(2^-123)
              "0000001001101000" after 70ns,   --   1.1101000*(2^-123)
              "1000100101001000" after 80ns,   --   1.1001000*(2^-109)
	          "1100011110011000" after 90ns,   --  -1.0011000*(2^16)
	          "1000000100001010" after 100ns,   --  -1.0001010*(2^-125)
	          "0000000000011100" after 110ns,  --   0
	          "0100000011110011" after 120ns,  --   1.1110011*(2^2)
              "0100000011110011" after 130ns,  --   1.1110011*(2^2)
              "0100000011110011" after 140ns,  --   1.1110011*(2^2)
              "1100010111101010" after 150ns,  --  -1.1101010*(2^12)
              "1100001101101010" after 160ns,  --  -1.1101010*(2^7)
              "1100001101101010" after 170ns,  --  -1.1101010*(2^7)
              "0100000011000000" after 180ns,  --   6
              "1100000111001000" after 190ns,  --   -25
              "0110101010100111" after 200ns,  --  +1.0100111*2^(86)
              "0100010000100011" after 210ns,  --  +1.0100011*2^(9)
              "0100000110100000" after 220ns;  --  +1.0100000*2^(4) (20)

end architecture;
