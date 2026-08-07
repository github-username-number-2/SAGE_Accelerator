library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gelu_ispa_epss is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        x_in        : in  std_logic_vector(15 downto 0); 
        gelu_res : out std_logic_vector(15 downto 0)  
    );
end entity gelu_ispa_epss;

architecture rtl of gelu_ispa_epss is

    component BF16_MUL is
        port (
            a : in  std_logic_vector(15 downto 0);
            b : in  std_logic_vector(15 downto 0);
            p : out std_logic_vector(15 downto 0)
        );
    end component;

    -- ------------------------
    -- In this version, we use "bf16_adder.vhd" instead of "bf16_add.vhd" for smaller area
    -- ------------------------
    --component BF16_ADD is
    --    port (
    --        a : in  std_logic_vector(15 downto 0);
    --        b : in  std_logic_vector(15 downto 0);
    --        s : out std_logic_vector(15 downto 0)
    --    );
    --end component;
    component bf16_adder is
        port (
            a : in  std_logic_vector(15 downto 0);
            b : in  std_logic_vector(15 downto 0);
            res : out std_logic_vector(15 downto 0)
        );
    end component;

    signal x_sign         : std_logic;
    signal x_pos          : std_logic_vector(15 downto 0);
    signal half_x_pos     : std_logic_vector(15 downto 0);
    signal a_coef         : std_logic_vector(15 downto 0);
    signal b_prime_coef   : std_logic_vector(15 downto 0);
    
    signal mul1_out       : std_logic_vector(15 downto 0);
    signal add1_out       : std_logic_vector(15 downto 0);
    
    signal reg_add1       : std_logic_vector(15 downto 0);
    signal reg_half_x_pos : std_logic_vector(15 downto 0);
    signal reg_x_pos      : std_logic_vector(15 downto 0);
    signal reg_x_sign     : std_logic;

    signal mul2_out       : std_logic_vector(15 downto 0);
    signal neg_reg_x_pos  : std_logic_vector(15 downto 0);
    signal add2_out       : std_logic_vector(15 downto 0);
    
    signal next_gelu_res : std_logic_vector(15 downto 0);

begin

    -- ==========================================
    -- STAGE 1: Data Formatting & Interval Search
    -- ==========================================
    
    x_sign <= x_in(15);
    x_pos  <= '0' & x_in(14 downto 0);

    process(x_pos)
        variable exp_val : unsigned(7 downto 0);
    begin
        exp_val := unsigned(x_pos(14 downto 7));
        if exp_val = 0 then
            half_x_pos <= (others => '0'); 
        else
            half_x_pos <= x_pos(15) & std_logic_vector(exp_val - 1) & x_pos(6 downto 0);
        end if;
    end process;

    -- EPSS Interval LUT
-- ==========================================
    -- CORRECTED EPSS Interval LUT 
    -- b_prime_coef now correctly includes the +1.0
    -- ==========================================
    process(x_pos)
    begin
        if unsigned(x_pos) <= x"3F00" then      -- x <= 0.500
            a_coef       <= x"3F44"; -- a  = 0.7656
            b_prime_coef <= x"3F80"; -- b' = 1.0000
        elsif unsigned(x_pos) <= x"3F40" then   -- x <= 0.750
            a_coef       <= x"3F28"; -- a  = 0.6562
            b_prime_coef <= x"3F87"; -- b' = 1.0546
        elsif unsigned(x_pos) <= x"3F80" then   -- x <= 1.000
            a_coef       <= x"3F0B"; -- a  = 0.5429
            b_prime_coef <= x"3F92"; -- b' = 1.1406
        elsif unsigned(x_pos) <= x"3FA0" then   -- x <= 1.250
            a_coef       <= x"3ED9"; -- a  = 0.4257
            b_prime_coef <= x"3FA1"; -- b' = 1.2578
        elsif unsigned(x_pos) <= x"3FC0" then   -- x <= 1.500
            a_coef       <= x"3E9F"; -- a  = 0.3105
            b_prime_coef <= x"3FB3"; -- b' = 1.3984
        elsif unsigned(x_pos) <= x"4000" then   -- x <= 2.000
            a_coef       <= x"3E34"; -- a  = 0.1757
            b_prime_coef <= x"3FCD"; -- b' = 1.6015
        elsif unsigned(x_pos) <= x"4020" then   -- x <= 2.500
            a_coef       <= x"3D88"; -- a  = 0.0664
            b_prime_coef <= x"3FE9"; -- b' = 1.8203
        elsif unsigned(x_pos) <= x"4040" then   -- x <= 3.000
            a_coef       <= x"3CB4"; -- a  = 0.0219
            b_prime_coef <= x"3FF7"; -- b' = 1.9296
        else                                    -- Saturation (x > 3.0)
            a_coef       <= x"0000"; -- a  = 0.0000
            b_prime_coef <= x"4000"; -- b' = 2.0000
        end if;
    end process;

    U_MUL1: BF16_MUL port map (a => a_coef,   b => x_pos,        p => mul1_out);
    --U_ADD1: BF16_ADD port map (a => mul1_out, b => b_prime_coef, s => add1_out);
    U_ADD1: bf16_adder port map (a => mul1_out, b => b_prime_coef, res => add1_out);

    process(clk, rst)
    begin
        if rst = '1' then
            reg_add1       <= (others => '0');
            reg_half_x_pos <= (others => '0');
            reg_x_pos      <= (others => '0');
            reg_x_sign     <= '0';
        elsif rising_edge(clk) then
            reg_add1       <= add1_out;
            reg_half_x_pos <= half_x_pos;
            reg_x_pos      <= x_pos;
            reg_x_sign     <= x_sign;
        end if;
    end process;


    U_MUL2: BF16_MUL port map (a => reg_half_x_pos, b => reg_add1, p => mul2_out);

    neg_reg_x_pos <= '1' & reg_x_pos(14 downto 0);

    --U_ADD2: BF16_ADD port map (a => mul2_out, b => neg_reg_x_pos, s => add2_out);
    U_ADD2: bf16_adder port map (a => mul2_out, b => neg_reg_x_pos, res => add2_out);

    next_gelu_res <= mul2_out when reg_x_sign = '0' else add2_out;

    process(clk, rst)
    begin
        if rst = '1' then
            gelu_res <= (others => '0');
        elsif rising_edge(clk) then
            gelu_res <= next_gelu_res;
        end if;
    end process;

end architecture rtl;
