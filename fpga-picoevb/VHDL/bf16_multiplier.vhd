--force vivado to use dsp slices
-- switch to truncation rounding

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BF16_MUL is
    port (
        a : in  std_logic_vector(15 downto 0);
        b : in  std_logic_vector(15 downto 0);
        p : out std_logic_vector(15 downto 0)
    );
end entity BF16_MUL;

architecture rtl of BF16_MUL is

    -- Operand unpacking signals
    signal sign_a, sign_b   : std_logic;
    signal exp_a, exp_b     : unsigned(7 downto 0);
    signal mant_a, mant_b   : unsigned(7 downto 0);
    signal is_zero_a        : std_logic;
    signal is_zero_b        : std_logic;

    -- Multiplication intermediate signals
    signal sign_mult        : std_logic;
    signal exp_sum          : unsigned(8 downto 0); 
    signal mant_mult        : unsigned(15 downto 0); 

    -- ========================================================================
    -- STRATEGY 1: Force Vivado to map this multiplier to a DSP48 slice
    -- ========================================================================
    attribute use_dsp : string;
    attribute use_dsp of mant_mult : signal is "yes";

    -- ========================================================================
    -- STRATEGY 2: Signals for highly optimized Truncation (Replaces RNE)
    -- ========================================================================
    signal truncated_mant   : unsigned(6 downto 0);
    signal exp_res_raw      : unsigned(7 downto 0);
    signal p_internal       : std_logic_vector(15 downto 0);

begin

    -- 1. Unpack Operands
    sign_a <= a(15);
    sign_b <= b(15);
    exp_a  <= unsigned(a(14 downto 7));
    exp_b  <= unsigned(b(14 downto 7));
    
    mant_a <= '1' & unsigned(a(6 downto 0));
    mant_b <= '1' & unsigned(b(6 downto 0));

    is_zero_a <= '1' when exp_a = "00000000" else '0';
    is_zero_b <= '1' when exp_b = "00000000" else '0';

    -- 2. Multiplication Logic (Will now be mapped to DSP via attribute)
    sign_mult <= sign_a xor sign_b;
    exp_sum   <= resize(exp_a, 9) + resize(exp_b, 9) - 127;   
    mant_mult <= mant_a * mant_b;

    -- ========================================================================
    -- STRATEGY 2: Normalization & Truncation Process
    -- ========================================================================
    
    -- Extract the top 7 bits directly, ignoring the rest (Truncation)
    truncated_mant <= mant_mult(14 downto 8) when mant_mult(15) = '1' else 
                      mant_mult(13 downto 7);
                     
    -- Adjust exponent based on multiplication MSB
    exp_res_raw    <= resize(exp_sum + 1, 8) when mant_mult(15) = '1' else 
                      resize(exp_sum, 8);

    -- Assemble Final Internal Result
    p_internal <= sign_mult & std_logic_vector(exp_res_raw) & std_logic_vector(truncated_mant);

    -- 3. Handle Zero Cases
    p <= (others => '0') when (is_zero_a = '1' or is_zero_b = '1') else 
         p_internal;

end architecture rtl;