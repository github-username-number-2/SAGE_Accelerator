LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY MAC_bias_8x8_8_reg IS
PORT (
    input_row_0, input_row_1, input_row_2, input_row_3, input_row_4, input_row_5, input_row_6, input_row_7: IN STD_LOGIC_VECTOR(15 downto 0);
    input_col_0, input_col_1, input_col_2, input_col_3, input_col_4, input_col_5, input_col_6, input_col_7: IN STD_LOGIC_VECTOR(15 downto 0);
    b_col : IN STD_LOGIC_VECTOR(15 downto 0);
    SEL_mux: IN STD_LOGIC_VECTOR(2 downto 0);
    CLK, RST_n, ENABLE : IN STD_LOGIC;
    output_row_0, output_row_1, output_row_2, output_row_3, output_row_4, output_row_5, output_row_6, output_row_7: OUT STD_LOGIC_VECTOR(15 downto 0)
);
END MAC_bias_8x8_8_reg;

ARCHITECTURE behaviour OF MAC_bias_8x8_8_reg IS
    COMPONENT MAC_8x8_8_reg IS
    PORT (
        input_row_0, input_row_1, input_row_2, input_row_3, input_row_4, input_row_5, input_row_6, input_row_7: IN STD_LOGIC_VECTOR(15 downto 0);
        input_col_0, input_col_1, input_col_2, input_col_3, input_col_4, input_col_5, input_col_6, input_col_7: IN STD_LOGIC_VECTOR(15 downto 0);
        SEL_mux: IN STD_LOGIC_VECTOR(2 downto 0);
        CLK, RST_n, ENABLE : IN STD_LOGIC;
        output_row_0, output_row_1, output_row_2, output_row_3, output_row_4, output_row_5, output_row_6, output_row_7: OUT STD_LOGIC_VECTOR(15 downto 0)
    );
    END COMPONENT;

    COMPONENT bias_sum_8_8 IS
    PORT (
        --clk : IN STD_LOGIC; 
        input_row_0, input_row_1, input_row_2, input_row_3, input_row_4, input_row_5, input_row_6, input_row_7: IN STD_LOGIC_VECTOR(15 downto 0);
        b_col : IN STD_LOGIC_VECTOR(15 downto 0);
        output_row_0, output_row_1, output_row_2, output_row_3, output_row_4, output_row_5, output_row_6, output_row_7: OUT STD_LOGIC_VECTOR(15 downto 0)
    );
    END COMPONENT;

    COMPONENT regnbit IS 
        GENERIC ( N : POSITIVE := 16); 
        PORT( D: IN STD_LOGIC_VECTOR(N-1 downto 0); CLK, RST_n, ENABLE : IN STD_LOGIC; Q : OUT STD_LOGIC_VECTOR(N-1 downto 0)); 
    END COMPONENT;

    SIGNAL output_row_MAC_base_0, output_row_MAC_base_1, output_row_MAC_base_2, output_row_MAC_base_3, 
           output_row_MAC_base_4, output_row_MAC_base_5, output_row_MAC_base_6, output_row_MAC_base_7: STD_LOGIC_VECTOR(15 downto 0);
    SIGNAL b_col_reg: STD_LOGIC_VECTOR(15 downto 0);

BEGIN
    MAC_base: MAC_8x8_8_reg PORT MAP(
        input_row_0=>input_row_0, input_row_1=>input_row_1, input_row_2=>input_row_2, input_row_3=>input_row_3, 
        input_row_4=>input_row_4, input_row_5=>input_row_5, input_row_6=>input_row_6, input_row_7=>input_row_7,
        input_col_0=>input_col_0, input_col_1=>input_col_1, input_col_2=>input_col_2, input_col_3=>input_col_3, 
        input_col_4=>input_col_4, input_col_5=>input_col_5, input_col_6=>input_col_6, input_col_7=>input_col_7,
        SEL_mux=>SEL_mux, CLK=>CLK, RST_n=>RST_n, ENABLE=>ENABLE,
        output_row_0=>output_row_MAC_base_0, output_row_1=>output_row_MAC_base_1, output_row_2=>output_row_MAC_base_2, output_row_3=>output_row_MAC_base_3,
        output_row_4=>output_row_MAC_base_4, output_row_5=>output_row_MAC_base_5, output_row_6=>output_row_MAC_base_6, output_row_7=>output_row_MAC_base_7
    );

    bias_reg: regnbit GENERIC MAP(N=>16) PORT MAP(CLK=>CLK, RST_n=>RST_n, ENABLE=>'1', D=>b_col, Q=>b_col_reg);

    bias_sum: bias_sum_8_8 PORT MAP(
        --clk=>CLK, 
        input_row_0=>output_row_MAC_base_0, input_row_1=>output_row_MAC_base_1, input_row_2=>output_row_MAC_base_2, input_row_3=>output_row_MAC_base_3,
        input_row_4=>output_row_MAC_base_4, input_row_5=>output_row_MAC_base_5, input_row_6=>output_row_MAC_base_6, input_row_7=>output_row_MAC_base_7,
        b_col=>b_col_reg, 
        output_row_0=>output_row_0, output_row_1=>output_row_1, output_row_2=>output_row_2, output_row_3=>output_row_3,
        output_row_4=>output_row_4, output_row_5=>output_row_5, output_row_6=>output_row_6, output_row_7=>output_row_7
    );
END behaviour;
