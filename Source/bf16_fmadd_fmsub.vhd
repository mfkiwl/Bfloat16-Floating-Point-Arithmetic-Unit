library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bf16_fmadd_fmsub is
    port(
        clk: in std_logic;
        reset: in std_logic;
        in1: in std_logic_vector(15 downto 0) ;
        in2: in std_logic_vector(15 downto 0) ;
        in3: in std_logic_vector(15 downto 0) ;
        funct5: in std_logic_vector(4 downto 0) ;
        result: out std_logic_vector(15 downto 0)
    );
end bf16_fmadd_fmsub;

architecture rtl of bf16_fmadd_fmsub is
    -- p1 register
    signal p1_in_in3: std_logic_vector(15 downto 0) ;
    signal p1_in_funct5: std_logic_vector(4 downto 0) ;
    signal p1_in_result_mult: std_logic_vector(15 downto 0) ;

    signal p1_out_in3: std_logic_vector(15 downto 0) ;
    signal p1_out_funct5: std_logic_vector(4 downto 0) ;
    signal p1_out_result_mult: std_logic_vector(15 downto 0) ;

    -- p2 register
    signal p2_in_alu_m: std_logic_vector(9 downto 0) ;
    signal p2_in_alu_in3: std_logic_vector(9 downto 0) ;
    signal p2_in_exc_res: std_logic_vector(15 downto 0) ;
    signal p2_in_exc_flag: std_logic ;
    signal p2_in_funct5: std_logic_vector(4 downto 0) ;
    signal p2_in_exp_r: integer range 0 to 255 ;

    signal p2_out_alu_m: std_logic_vector(9 downto 0) ;
    signal p2_out_alu_in3: std_logic_vector(9 downto 0) ;
    signal p2_out_exc_res: std_logic_vector(15 downto 0) ;
    signal p2_out_exc_flag: std_logic ;
    signal p2_out_funct5: std_logic_vector(4 downto 0) ;
    signal p2_out_exp_r: integer range 0 to 255 ;

    -- p3 register
    signal p3_in_exp_r: integer range 0 to 255 ;
    signal p3_in_alu_r: std_logic_vector(9 downto 0) ;
    signal p3_in_exc_res: std_logic_vector(15 downto 0) ;
    signal p3_in_exc_flag: std_logic ;
    signal p3_in_s_r: std_logic ;

    signal p3_out_exp_r: integer range 0 to 255 ;
    signal p3_out_alu_r: std_logic_vector(9 downto 0) ;
    signal p3_out_exc_res: std_logic_vector(15 downto 0) ;
    signal p3_out_exc_flag: std_logic ;
    signal p3_out_s_r: std_logic ;
begin
    p_reg: process (clk, reset) is
        begin
            if (reset = '0') then
                -- p1 register
                p1_out_in3 <= (others => '0');
                p1_out_funct5 <= (others => '0');
                p1_out_result_mult <= (others => '0');
                -- p2 register
                p2_out_alu_m <= (others => '0');
                p2_out_alu_in3 <= (others => '0');
                p2_out_exc_res <= (others => '0');
                p2_out_exc_flag <= '1';
                p2_out_funct5 <= (others => '0');
                p2_out_exp_r <= 0;
                -- p3 register
                p3_out_exp_r <= 0;
                p3_out_alu_r <= (others => '0');
                p3_out_exc_res <= (others => '0');
                p3_out_exc_flag <= '1';
                p3_out_s_r <= '0';
            elsif rising_edge(clk) then
                -- p1 register
                p1_out_in3 <= p1_in_in3;
                p1_out_funct5 <= p1_in_funct5 ;
                p1_out_result_mult <= p1_in_result_mult;
                -- p2 register
                p2_out_alu_m <= p2_in_alu_m;
                p2_out_alu_in3 <= p2_in_alu_in3;
                p2_out_exc_res <= p2_in_exc_res;
                p2_out_exc_flag <= p2_in_exc_flag;
                p2_out_funct5 <= p2_in_funct5;
                p2_out_exp_r <= p2_in_exp_r;
                -- p3 register
                p3_out_exp_r <= p3_in_exp_r;
                p3_out_alu_r <= p3_in_alu_r;
                p3_out_exc_res <= p3_in_exc_res;
                p3_out_exc_flag <= p3_in_exc_flag;
                p3_out_s_r <= p3_in_s_r;
            end if;
    end process p_reg;

    stage_1: process(in1, in2, in3, funct5) is
        variable exp_1: integer range -252 to 255 ;
        variable exp_2: integer range -252 to 255 ; 
        variable alu_in1: std_logic_vector(7 downto 0) ;
        variable alu_in2: std_logic_vector(7 downto 0) ;
        variable s_rm: std_logic ;  -- multiplication result sign
        variable exp_rm: integer range -252 to 255 ; 
        variable alu_rm: std_logic_vector(15 downto 0) ;
        variable result_mult: std_logic_vector(15 downto 0) ;
        begin
            exp_1 := to_integer(unsigned(in1(14 downto 7)));
            exp_2 := to_integer(unsigned(in2(14 downto 7)));

            -- Handle exceptions: NaN, zero and infinity
            -- Denormalized numbers are flushed to zero

            -- handle zeros and denorms
            if ((exp_1 = 0) or (exp_2 = 0)) then
                result_mult := (others => '0');
            
            -- handle NaN and infinity
            elsif ((exp_1 = 255) or (exp_2 = 255)) then
                if (((in1(6 downto 0)) /= "0000000") and (exp_1 = 255)) then
                    result_mult := in1;
                elsif (((in2(6 downto 0)) /= "0000000") and (exp_2 = 255)) then
                    result_mult := in2;
                else
                    if (exp_1 = 255) then
                        result_mult := in1;
                    else
                        result_mult := in2;
                    end if;
                end if;
            
            -- handle normal
            else
                -- Prepare operands
                alu_in1 := '1' & in1(6 downto 0);
                alu_in2 := '1' & in2(6 downto 0);

                exp_1 := exp_1 -127;
                exp_2 := exp_2 -127;

                exp_rm := exp_1 + exp_2;
                
                -- adjust multiplication result sign
                s_rm := in1(15) xor in2(15);
                -- detect overflow/underflow
                if ((exp_rm > 127) and (s_rm = '0')) then
                    result_mult := "0111111110000000"; -- +inf
                elsif ((exp_rm > 127) and (s_rm = '1')) then
                    result_mult := "1111111110000000"; -- -inf
                elsif (exp_rm < (-126)) then
                    result_mult := "0000000000000000"; -- zero
                else
                    -- multiply the mantissas
                    alu_rm := std_logic_vector(unsigned(alu_in1) * unsigned(alu_in2));
                    
                    if (alu_rm(15) = '1') then
                        -- Adjust exponent
                        exp_rm := exp_rm + 1;
                    else
                        -- Perform correct allignment
                        alu_rm := std_logic_vector(shift_left(unsigned(alu_rm), 1));
                    end if;

                    -- Generate final result in bfloat 16 format
                    result_mult(15) := s_rm;
                    result_mult(14 downto 7) := std_logic_vector(to_unsigned(exp_rm + 127,8));
                    result_mult(6 downto 0) := alu_rm(14 downto 8);
                end if;
            end if;

            p1_in_in3 <= in3;
            p1_in_funct5 <= funct5;
            p1_in_result_mult <= result_mult;
    end process stage_1;

    stage_2: process(p1_out_in3, p1_out_funct5, p1_out_result_mult) is
        variable exp_m: integer range 0 to 255 ; -- exponent
        variable exp_3: integer range 0 to 255 ;
        variable alu_m: std_logic_vector(9 downto 0) ;
        variable alu_in3: std_logic_vector(9 downto 0) ;
        -- 10 bits used as operand: 
        -- 1 sign bit, 1 guard bit, 1 implied one, 7 from significand
        variable exp_r: integer range 0 to 255; -- exponent
        variable exc_res: std_logic_vector(15 downto 0); -- result of exception
        variable exc_flag: std_logic ; -- exception flag

        begin
            -- We do not need to work with actual exponent. We use bias notation.
            exp_m := to_integer(unsigned(p1_out_result_mult(14 downto 7)));
            exp_3 := to_integer(unsigned(p1_out_in3(14 downto 7)));

            -- Prepare operands
            alu_m := "001" & p1_out_result_mult(6 downto 0);
            alu_in3 := "001" & p1_out_in3(6 downto 0);

            -- Handle exceptions: NaN, zero and infinity
            -- Denormalized numbers are flushed to zero
            exc_flag := '1';
            -- handle zeros and denorms
            if ((exp_m = 0) and (exp_3 /= 0)) then
                if (p1_out_funct5 = "00101") then
                    exc_res := not(p1_out_in3(15)) & p1_out_in3(14 downto 0);
                else
                    exc_res := p1_out_in3;
                end if;
            elsif ((exp_3 = 0) and (exp_m /= 0)) then
                if (p1_out_funct5 = "00101") then
                    exc_res := not(p1_out_result_mult(15)) & p1_out_result_mult(14 downto 0);
                else
                    exc_res := p1_out_result_mult;
                end if;
            elsif ((exp_3 = 0) and (exp_m = 0)) then
                exc_res := (others => '0');
            
            -- handle cancellation (result = 0)
            elsif ((p1_out_result_mult(14 downto 0) = p1_out_in3(14 downto 0)) and (p1_out_result_mult(15) /= p1_out_in3(15)) and (p1_out_funct5 = "00100")) then
                exc_res := (others => '0');
            elsif ((p1_out_result_mult(14 downto 0) = p1_out_in3(14 downto 0)) and (p1_out_result_mult(15) = p1_out_in3(15)) and (p1_out_funct5 = "00101")) then
                exc_res := (others => '0');
        
            -- handle NaN and infinity
            elsif ((exp_m = 255) or (exp_3 = 255)) then
                if (((p1_out_result_mult(6 downto 0)) /= "0000000") and (exp_m = 255)) then
                    exc_res := p1_out_result_mult;
                elsif (((p1_out_in3(6 downto 0)) /= "0000000") and (exp_3 = 255)) then
                    exc_res := p1_out_in3;
                else
                    if (exp_m = 255) then
                        exc_res := p1_out_result_mult;
                    else
                        exc_res := p1_out_in3;
                    end if;
                end if;
            else
                exc_flag := '0'; -- no exception
            end if;

            if (exp_m >= exp_3) then
                -- Mantissa allignment
                alu_in3 := std_logic_vector(shift_right(unsigned(alu_in3),(exp_m-exp_3)));
                exp_r := exp_m;
            else
                alu_m := std_logic_vector(shift_right(unsigned(alu_m),(exp_3-exp_m)));
                exp_r := exp_3;
            end if;
            
            -- Express both operands in two's complement 
            if p1_out_result_mult(15) = '1' then
                alu_m := std_logic_vector(-signed(alu_m));
            else
                alu_m := std_logic_vector(signed(alu_m));
            end if;

            if p1_out_in3(15) = '1' then
                alu_in3 := std_logic_vector(-signed(alu_in3));
            else
                alu_in3 := std_logic_vector(signed(alu_in3));
            end if;

            -- assign the final value of each variable to these signals
            -- they need to be preserved since we are using pipeling
            p2_in_alu_m <= alu_m;
            p2_in_alu_in3 <= alu_in3;
            p2_in_exc_res <= exc_res;
            p2_in_exc_flag <= exc_flag;
            p2_in_funct5 <= p1_out_funct5;
            p2_in_exp_r <= exp_r;
    end process stage_2;

    stage_3: process(p2_out_alu_m, p2_out_alu_in3, p2_out_exc_res, p2_out_exc_flag, p2_out_funct5, p2_out_exp_r) is
        variable alu_r: std_logic_vector(9 downto 0) ;
        variable s_r: std_logic;  -- result sign
        begin
            case p2_out_funct5 is 
                when "00100" => -- add
                    alu_r := std_logic_vector(signed(p2_out_alu_m) + signed(p2_out_alu_in3));
                when "00101" => -- sub
                    alu_r := std_logic_vector(signed(p2_out_alu_m) - signed(p2_out_alu_in3));
                when others =>
                    alu_r := (others => '0');
            end case;

            -- Set result sign bit and express result as a magnitude
            s_r := '0';
            if ((signed(alu_r)) < 0) then
                s_r := '1';
                alu_r := std_logic_vector(-signed(alu_r));
            end if;

            p3_in_exp_r <= p2_out_exp_r;
            p3_in_exc_res <= p2_out_exc_res;
            p3_in_exc_flag <= p2_out_exc_flag;
            p3_in_alu_r <= alu_r;
            p3_in_s_r <= s_r;
    end process stage_3;

    stage_4: process (p3_out_exp_r, p3_out_alu_r, p3_out_exc_res, p3_out_exc_flag, p3_out_s_r) is
        variable count: integer range -7 to 1;
        variable p3_alu_r: std_logic_vector(9 downto 0) ;
        variable p3_exp_r: integer range -7 to 255 ;
        begin
            -- Normalize mantissa and adjust exponent
            count := 1;
            p3_alu_r := p3_out_alu_r;
            p3_exp_r := p3_out_exp_r;
            while ((p3_alu_r(8) /= '1') and (count > -7)) loop
                p3_alu_r := std_logic_vector(shift_left(unsigned(p3_alu_r), 1));
                count := count - 1;
            end loop;
            
            -- Shift right once to get correct allignment
            -- In case of overflow, we will skip the while loop and only shift right once
            p3_alu_r := std_logic_vector(shift_right(unsigned(p3_alu_r), 1));
            -- Adjust exponent
            p3_exp_r := p3_exp_r + count;
            
            -- Generate final result in bfloat 16 format
            if (p3_out_exc_flag = '1') then
                result <= p3_out_exc_res;
            elsif ((p3_exp_r = 255) and (p3_out_s_r = '0')) then
                result <= "0111111110000000"; -- overflow, result = +inf
            elsif ((p3_exp_r = 255) and (p3_out_s_r = '1')) then
                result <= "1111111110000000"; -- overflow, result = -inf
            elsif (p3_exp_r < (-126)) then
                result <= "0000000000000000"; -- underflow, result = zero
            else
                result(15) <= p3_out_s_r;
                result(14 downto 7) <= std_logic_vector(to_unsigned(p3_exp_r,8));
                result(6 downto 0) <= p3_alu_r(6 downto 0);
            end if;
    end process stage_4;
end architecture;

