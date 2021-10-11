library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bf16_add_sub is
    port(
        clk: in std_logic;
        reset: in std_logic;
        in1: in std_logic_vector(15 downto 0) ;
        in2: in std_logic_vector(15 downto 0) ;
        funct5: in std_logic_vector(4 downto 0) ;
        result: out std_logic_vector(15 downto 0)
    );
end bf16_add_sub;

architecture rtl of bf16_add_sub is
    -- b1 buffer/register
    signal b1_in1: std_logic_vector(15 downto 0) ;
    signal b1_in2: std_logic_vector(15 downto 0) ;
    signal b1_funct5: std_logic_vector(4 downto 0) ;
    -- p1 register
    signal p1_in_alu_in1: std_logic_vector(9 downto 0) ;
    signal p1_in_alu_in2: std_logic_vector(9 downto 0) ;
    signal p1_in_exc_res: std_logic_vector(15 downto 0) ;
    signal p1_in_exc_flag: std_logic ;
    signal p1_in_funct5: std_logic_vector(4 downto 0) ;
    signal p1_in_exp_r: integer range 0 to 255 ;

    signal p1_out_alu_in1: std_logic_vector(9 downto 0) ;
    signal p1_out_alu_in2: std_logic_vector(9 downto 0) ;
    signal p1_out_exc_res: std_logic_vector(15 downto 0) ;
    signal p1_out_exc_flag: std_logic ;
    signal p1_out_funct5: std_logic_vector(4 downto 0) ;
    signal p1_out_exp_r: integer range 0 to 255 ;

    -- p2 register
    signal p2_in_exp_r: integer range 0 to 255 ;
    signal p2_in_alu_r: std_logic_vector(9 downto 0) ;
    signal p2_in_exc_res: std_logic_vector(15 downto 0) ;
    signal p2_in_exc_flag: std_logic ;
    signal p2_in_s_r: std_logic ;

    signal p2_out_exp_r: integer range 0 to 255 ;
    signal p2_out_alu_r: std_logic_vector(9 downto 0) ;
    signal p2_out_exc_res: std_logic_vector(15 downto 0) ;
    signal p2_out_exc_flag: std_logic ;
    signal p2_out_s_r: std_logic ;
begin
    p_reg: process (clk, reset) is
        begin
            if (reset = '0') then
                -- b1 buffer/register
                b1_in1 <= (others => '0');
                b1_in2 <= (others => '0');
                b1_funct5 <= (others => '0');
                -- p1 register
                p1_out_alu_in1 <= (others => '0');
                p1_out_alu_in2 <= (others => '0');
                p1_out_exc_res <= (others => '0');
                p1_out_exc_flag <= '1';
                p1_out_funct5 <= (others => '0');
                p1_out_exp_r <= 0;
                -- p2 register
                p2_out_exp_r <= 0;
                p2_out_alu_r <= (others => '0');
                p2_out_exc_res <= (others => '0');
                p2_out_exc_flag <= '1';
                p2_out_s_r <= '0';
            elsif rising_edge(clk) then
                -- b1 buffer/register
                b1_in1 <= in1;
                b1_in2 <= in2;
                b1_funct5 <= funct5;
                -- p1 register
                p1_out_alu_in1 <= p1_in_alu_in1;
                p1_out_alu_in2 <= p1_in_alu_in2;
                p1_out_exc_res <= p1_in_exc_res;
                p1_out_exc_flag <= p1_in_exc_flag;
                p1_out_funct5 <= p1_in_funct5;
                p1_out_exp_r <= p1_in_exp_r;
                -- p2 register
                p2_out_exp_r <= p2_in_exp_r;
                p2_out_alu_r <= p2_in_alu_r;
                p2_out_exc_res <= p2_in_exc_res;
                p2_out_exc_flag <= p2_in_exc_flag;
                p2_out_s_r <= p2_in_s_r;
            end if;
    end process p_reg;

    stage_1: process(b1_in1, b1_in2, b1_funct5) is
        variable exp_1: integer range 0 to 255 ; -- exponent
        variable exp_2: integer range 0 to 255 ;
        variable alu_in1: std_logic_vector(9 downto 0) ;
        variable alu_in2: std_logic_vector(9 downto 0) ;
        -- 10 bits used as operand: 
        -- 1 sign bit, 1 guard bit, 1 implied one, 7 from significand
        variable exp_r: integer range 0 to 255; -- exponent
        variable exc_res: std_logic_vector(15 downto 0); -- result of exception
        variable exc_flag: std_logic ; -- exception flag

        begin
            -- We do not need to work with actual exponent. We use bias notation.
            exp_1 := to_integer(unsigned(b1_in1(14 downto 7)));
            exp_2 := to_integer(unsigned(b1_in2(14 downto 7)));

            -- Prepare operands
            alu_in1 := "001" & b1_in1(6 downto 0);
            alu_in2 := "001" & b1_in2(6 downto 0);

            -- Handle exceptions: NaN, zero and infinity
            -- Denormalized numbers are flushed to zero
            exc_flag := '1';
            -- handle zeros and denorms
            if ((exp_1 = 0) and (exp_2 /= 0)) then
                if (b1_funct5 = "00001") then
                    exc_res := not(b1_in2(15)) & b1_in2(14 downto 0);
                else
                    exc_res := b1_in2;
                end if;
            elsif ((exp_2 = 0) and (exp_1 /= 0)) then
                if (b1_funct5 = "00001") then
                    exc_res := not(b1_in1(15)) & b1_in1(14 downto 0);
                else
                    exc_res := b1_in1;
                end if;
            elsif ((exp_2 = 0) and (exp_1 = 0)) then
                exc_res := (others => '0');
            
            -- handle cancellation (result = 0)
            elsif ((b1_in1(14 downto 0) = b1_in2(14 downto 0)) and (b1_in1(15) /= b1_in2(15)) and (b1_funct5 = "00000")) then
                exc_res := (others => '0');
            elsif ((b1_in1(14 downto 0) = b1_in2(14 downto 0)) and (b1_in1(15) = b1_in2(15)) and (b1_funct5 = "00001")) then
                exc_res := (others => '0');
        
            -- handle NaN and infinity
            elsif ((exp_1 = 255) or (exp_2 = 255)) then
                if (((b1_in1(6 downto 0)) /= "0000000") and (exp_1 = 255)) then
                    exc_res := b1_in1;
                elsif (((b1_in2(6 downto 0)) /= "0000000") and (exp_2 = 255)) then
                    exc_res := b1_in2;
                else
                    if (exp_1 = 255) then
                        exc_res := b1_in1;
                    else
                        exc_res := b1_in2;
                    end if;
                end if;
            else
                exc_flag := '0'; -- no exception
            end if;

            if (exp_1 >= exp_2) then
                -- Mantissa allignment
                alu_in2 := std_logic_vector(shift_right(unsigned(alu_in2),(exp_1-exp_2)));
                exp_r := exp_1;
            else
                alu_in1 := std_logic_vector(shift_right(unsigned(alu_in1),(exp_2-exp_1)));
                exp_r := exp_2;
            end if;
            
            -- Express both operands in two's complement 
            if b1_in1(15) = '1' then
                alu_in1 := std_logic_vector(-signed(alu_in1));
            else
                alu_in1 := std_logic_vector(signed(alu_in1));
            end if;

            if b1_in2(15) = '1' then
                alu_in2 := std_logic_vector(-signed(alu_in2));
            else
                alu_in2 := std_logic_vector(signed(alu_in2));
            end if;

            -- assign the final value of each variable to these signals
            -- they need to be preserved since we are using pipeling
            p1_in_alu_in1 <= alu_in1;
            p1_in_alu_in2 <= alu_in2;
            p1_in_exc_res <= exc_res;
            p1_in_exc_flag <= exc_flag;
            p1_in_funct5 <= b1_funct5;
            p1_in_exp_r <= exp_r;
    end process stage_1;

    stage_2: process(p1_out_alu_in1, p1_out_alu_in2, p1_out_exc_res, p1_out_exc_flag, p1_out_funct5, p1_out_exp_r) is
        variable alu_r: std_logic_vector(9 downto 0) ;
        variable s_r: std_logic;  -- result sign
        begin
            case p1_out_funct5 is 
                when "00000" => -- add
                    alu_r := std_logic_vector(signed(p1_out_alu_in1) + signed(p1_out_alu_in2));
                when "00001" => -- sub
                    alu_r := std_logic_vector(signed(p1_out_alu_in1) - signed(p1_out_alu_in2));
                when others =>
                    alu_r := (others => '0');
            end case;

            -- Set result sign bit and express result as a magnitude
            s_r := '0';
            if ((signed(alu_r)) < 0) then
                s_r := '1';
                alu_r := std_logic_vector(-signed(alu_r));
            end if;

            p2_in_exp_r <= p1_out_exp_r;
            p2_in_exc_res <= p1_out_exc_res;
            p2_in_exc_flag <= p1_out_exc_flag;
            p2_in_alu_r <= alu_r;
            p2_in_s_r <= s_r;
    end process stage_2;

    stage_3: process(p2_out_exp_r, p2_out_alu_r, p2_out_exc_res, p2_out_exc_flag, p2_out_s_r) is
        variable count: integer range -7 to 1;
        variable p2_alu_r: std_logic_vector(9 downto 0) ;
        variable p2_exp_r: integer range -7 to 255 ;
        begin
            -- Normalize mantissa and adjust exponent
            count := 1;
            p2_alu_r := p2_out_alu_r;
            p2_exp_r := p2_out_exp_r;
            while ((p2_alu_r(8) /= '1') and (count > -7)) loop
                p2_alu_r := std_logic_vector(shift_left(unsigned(p2_alu_r), 1));
                count := count - 1;
            end loop;
            
            -- Shift right once to get correct allignment
            -- In case of overflow, we will skip the while loop and only shift right once
            p2_alu_r := std_logic_vector(shift_right(unsigned(p2_alu_r), 1));
            -- Adjust exponent
            p2_exp_r := p2_exp_r + count;
            
            -- Generate final result in bfloat 16 format
            if (p2_out_exc_flag = '1') then
                result <= p2_out_exc_res;
            elsif ((p2_exp_r = 255) and (p2_out_s_r = '0')) then
                result <= "0111111110000000"; -- overflow, result = +inf
            elsif ((p2_exp_r = 255) and (p2_out_s_r = '1')) then
                result <= "1111111110000000"; -- overflow, result = -inf
            elsif (p2_exp_r < (-126)) then
                result <= "0000000000000000"; -- underflow, result = zero
            else
                result(15) <= p2_out_s_r;
                result(14 downto 7) <= std_logic_vector(to_unsigned(p2_exp_r,8));
                result(6 downto 0) <= p2_alu_r(6 downto 0);
            end if;
    end process stage_3;
end architecture;

