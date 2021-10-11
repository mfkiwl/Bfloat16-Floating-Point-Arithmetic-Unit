library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bf16_mult is
    port(
        clk: in std_logic;
        reset: in std_logic;
        in1: in std_logic_vector(15 downto 0) ;
        in2: in std_logic_vector(15 downto 0) ;
        result: out std_logic_vector(15 downto 0)
    );
end bf16_mult;

architecture rtl of bf16_mult is
    -- b1 buffer/register
    signal b1_in1: std_logic_vector(15 downto 0) ;
    signal b1_in2: std_logic_vector(15 downto 0) ;
    -- b2 buffer/register
    signal b2_in1: std_logic_vector(15 downto 0) ;
    signal b2_in2: std_logic_vector(15 downto 0) ;
    -- b3 buffer/register
    signal b3_in1: std_logic_vector(15 downto 0) ;
    signal b3_in2: std_logic_vector(15 downto 0) ;
begin
    b_reg: process (clk, reset) is
        begin
            if (reset = '0') then
                -- b1 buffer/register
                b1_in1 <= (others => '0');
                b1_in2 <= (others => '0');
                -- b2 buffer/register
                b2_in1 <= (others => '0');
                b2_in2 <= (others => '0');
                -- b3 buffer/register
                b3_in1 <= (others => '0');
                b3_in2 <= (others => '0');
            elsif rising_edge(clk) then
                -- b1 buffer/register
                b1_in1 <= in1;
                b1_in2 <= in2;
                -- b2 buffer/register
                b2_in1 <= b1_in1;
                b2_in2 <= b1_in2;
                -- b3 buffer/register
                b3_in1 <= b2_in1;
                b3_in2 <= b2_in2;
            end if;
    end process b_reg;

    mult: process(b3_in1, b3_in2) is
        variable exp_1: integer range -252 to 255; -- exponent
        variable alu_in1: std_logic_vector(7 downto 0); -- operand

        variable exp_2: integer range -252 to 255; -- exponent
        variable alu_in2: std_logic_vector(7 downto 0); -- operand

        variable s_r: std_logic;  -- result sign
        variable exp_r: integer range -252 to 255; -- exponent
        variable alu_r: std_logic_vector(15 downto 0);

        begin
            exp_1 := to_integer(unsigned(b3_in1(14 downto 7)));
            exp_2 := to_integer(unsigned(b3_in2(14 downto 7)));

            -- Handle exceptions: NaN, zero and infinity
            -- Denormalized numbers are flushed to zero

            -- handle zeros and denorms
            if ((exp_1 = 0) or (exp_2 = 0)) then
                result <= (others => '0');
            
            -- handle NaN and infinity
            elsif ((exp_1 = 255) or (exp_2 = 255)) then
                if (((b3_in1(6 downto 0)) /= "0000000") and (exp_1 = 255)) then
                    result <= b3_in1;
                elsif (((b3_in2(6 downto 0)) /= "0000000") and (exp_2 = 255)) then
                    result <= b3_in2;
                else
                    if (exp_1 = 255) then
                        result <= b3_in1;
                    else
                        result <= b3_in2;
                    end if;
                end if;

            -- handle normal
            else
                -- Prepare operands
                alu_in1 := '1' & b3_in1(6 downto 0);
                alu_in2 := '1' & b3_in2(6 downto 0);
                
                exp_1 := exp_1 -127;
                exp_2 := exp_2 -127;

                exp_r := exp_1 + exp_2;
                
                -- adjust result sign
                s_r := b3_in1(15) xor b3_in2(15);
                -- detect overflow/underflow
                if ((exp_r > 127) and (s_r = '0')) then
                    result <= "0111111110000000"; -- +inf
                elsif ((exp_r > 127) and (s_r = '1')) then
                    result <= "1111111110000000"; -- -inf
                elsif (exp_r < (-126)) then
                    result <= "0000000000000000"; -- zero
                else
                    -- multiply the mantissas
                    alu_r := std_logic_vector(unsigned(alu_in1) * unsigned(alu_in2));
                    
                    if (alu_r(15) = '1') then
                        -- Adjust exponent
                        exp_r := exp_r + 1;
                    else
                        -- Perform correct allignment
                        -- We shift to the left to avoid loosing precision
                        alu_r := std_logic_vector(shift_left(unsigned(alu_r), 1));
                    end if;

                    -- Generate final result in bfloat 16 format
                    result(15) <= s_r;
                    result(14 downto 7) <= std_logic_vector(to_unsigned(exp_r + 127,8));
                    result(6 downto 0) <= alu_r(14 downto 8);
                end if;
            end if;
    end process mult;
end architecture;   

