LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY bf16_adder IS
    PORT (
        A   : IN  STD_LOGIC_VECTOR(15 downto 0);
        B   : IN  STD_LOGIC_VECTOR(15 downto 0);
        RES : OUT STD_LOGIC_VECTOR(15 downto 0)
    );
END bf16_adder;

ARCHITECTURE combinational OF bf16_adder IS

    -- ATTRIBUTE use_dsp : string;
    -- ATTRIBUTE use_dsp OF combinational : ARCHITECTURE IS "yes";

    -- =========================================================
    -- ALL VARIABLES MOVED TO ARCHITECTURE SIGNALS
    -- =========================================================
    SIGNAL s_mag_a, s_mag_b       : unsigned(14 downto 0);
    SIGNAL s_mag_l, s_mag_s       : unsigned(14 downto 0);
    SIGNAL s_sign_l, s_sign_s     : std_logic;
    
    SIGNAL s_exp_l, s_exp_s       : unsigned(7 downto 0);
    SIGNAL s_hidden_l, s_hidden_s : std_logic;
    SIGNAL s_mant_l, s_mant_s     : unsigned(7 downto 0);
    
    SIGNAL s_exp_diff             : unsigned(7 downto 0);
    SIGNAL s_shifted_s            : unsigned(7 downto 0);
    SIGNAL s_align_mask           : std_logic;
    SIGNAL s_mant_s_aligned       : unsigned(7 downto 0);
    
    SIGNAL s_sum                  : unsigned(8 downto 0); 
    SIGNAL s_lzc                  : unsigned(2 downto 0);
    SIGNAL s_sum_norm             : unsigned(7 downto 0);
    SIGNAL s_exp_adj              : signed(8 downto 0); 
    SIGNAL s_exp_final_calc       : signed(8 downto 0); 

BEGIN
    -- =========================================================
    -- CONCURRENT SIGNAL ASSIGNMENTS (No PROCESS block needed)
    -- =========================================================

    -- 1. Unpack Magnitudes
    s_mag_a <= unsigned(A(14 downto 0));
    s_mag_b <= unsigned(B(14 downto 0));

    -- 2. Sort by Absolute Magnitude
    s_mag_l  <= s_mag_a WHEN s_mag_a > s_mag_b ELSE s_mag_b;
    s_sign_l <= A(15)   WHEN s_mag_a > s_mag_b ELSE B(15);
    
    s_mag_s  <= s_mag_b WHEN s_mag_a > s_mag_b ELSE s_mag_a;
    s_sign_s <= B(15)   WHEN s_mag_a > s_mag_b ELSE A(15);

    -- 3. Extract Exponents
    s_exp_l <= s_mag_l(14 downto 7);
    s_exp_s <= s_mag_s(14 downto 7);
    
    -- 4. Strip Hidden Bits (Denormal Checking)
    s_hidden_l <= '0' WHEN s_exp_l = 0 ELSE '1';
    s_hidden_s <= '0' WHEN s_exp_s = 0 ELSE '1';
    
    s_mant_l <= s_hidden_l & s_mag_l(6 downto 0);
    s_mant_s <= s_hidden_s & s_mag_s(6 downto 0);

    -- 5. Calculate Difference & Alignment Shifting
    s_exp_diff  <= s_exp_l - s_exp_s;
    s_shifted_s <= shift_right(s_mant_s, to_integer(s_exp_diff(2 downto 0)));
    
    -- Generate mask to flush shifter if difference >= 8
    s_align_mask <= '0' WHEN s_exp_diff(7 downto 3) /= "00000" ELSE '1';
    
    -- Replace the variable FOR loop with a clean concurrent MUX
    s_mant_s_aligned <= s_shifted_s WHEN s_align_mask = '1' ELSE (others => '0');

    -- 6. Mantissa Addition/Subtraction
    s_sum <= resize(s_mant_l, 9) + s_mant_s_aligned WHEN s_sign_l = s_sign_s ELSE
             resize(s_mant_l, 9) - s_mant_s_aligned;

    -- 7. Calculate Leading Zero Count (LZC)
    s_lzc <= "000" WHEN s_sum(7) = '1' ELSE
             "001" WHEN s_sum(6) = '1' ELSE
             "010" WHEN s_sum(5) = '1' ELSE
             "011" WHEN s_sum(4) = '1' ELSE
             "100" WHEN s_sum(3) = '1' ELSE
             "101" WHEN s_sum(2) = '1' ELSE
             "110" WHEN s_sum(1) = '1' ELSE
             "111";

    -- 8. Normalization (Handles Overflow vs Standard Shift)
    s_sum_norm <= s_sum(8 downto 1) WHEN s_sum(8) = '1' ELSE
                  shift_left(s_sum(7 downto 0), to_integer(s_lzc));

    s_exp_adj  <= to_signed(1, 9) WHEN s_sum(8) = '1' ELSE
                  - signed(resize(s_lzc, 9)); 

    -- 9. Final Exponent Adder
    s_exp_final_calc <= signed(resize(s_exp_l, 9)) + s_exp_adj;

    -- 10. Output Packing & Clamping
    RES <= (others => '0') WHEN (s_sum_norm(7) = '0' OR s_exp_final_calc <= 0) ELSE
           s_sign_l & std_logic_vector(s_exp_final_calc(7 downto 0)) & std_logic_vector(s_sum_norm(6 downto 0));

END combinational;