LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY MAC_8x8_8_reg IS
PORT (
    input_row_0, input_row_1, input_row_2, input_row_3, input_row_4, input_row_5, input_row_6, input_row_7: IN STD_LOGIC_VECTOR(15 downto 0);
    input_col_0, input_col_1, input_col_2, input_col_3, input_col_4, input_col_5, input_col_6, input_col_7: IN STD_LOGIC_VECTOR(15 downto 0);
    SEL_mux: IN STD_LOGIC_VECTOR(2 downto 0); --selecting input for output
    CLK, RST_n, ENABLE : IN STD_LOGIC;
    output_row_0, output_row_1, output_row_2, output_row_3, output_row_4, output_row_5, output_row_6, output_row_7: OUT STD_LOGIC_VECTOR(15 downto 0)
);
END MAC_8x8_8_reg;

ARCHITECTURE behaviour OF MAC_8x8_8_reg IS
    COMPONENT MAC IS GENERIC (data_size: POSITIVE:=16; acc_size: POSITIVE:=16); PORT(data_in_A, data_in_B: IN STD_LOGIC_VECTOR(data_size-1 downto 0); CLK, RST_n, ENABLE: IN STD_LOGIC; data_out: OUT STD_LOGIC_VECTOR(acc_size-1 downto 0)); END COMPONENT;
    COMPONENT mux_8to1_nbit IS GENERIC (N: POSITIVE:=16); PORT(I0, I1, I2, I3, I4, I5, I6, I7: IN STD_LOGIC_VECTOR(N-1 downto 0); SEL_mux: IN STD_LOGIC_VECTOR(2 downto 0); O: OUT STD_LOGIC_VECTOR(N-1 downto 0)); END COMPONENT;
    COMPONENT regnbit IS GENERIC (N: POSITIVE:=16); PORT(D: IN STD_LOGIC_VECTOR(N-1 downto 0); CLK, RST_n, ENABLE: IN STD_LOGIC; Q: OUT STD_LOGIC_VECTOR(N-1 downto 0)); END COMPONENT;
    COMPONENT ff IS PORT(D, CLK, RST_n, ENABLE: IN STD_LOGIC; Q: OUT STD_LOGIC); END COMPONENT;

    TYPE bus_arr is array(0 to 7) of STD_LOGIC_VECTOR(15 downto 0);
    TYPE mac_grid_arr is array(0 to 7, 0 to 7) of STD_LOGIC_VECTOR(15 downto 0);

    SIGNAL in_rows, in_cols, reg_rows, reg_cols : bus_arr;
    SIGNAL mac_outs : mac_grid_arr;
    SIGNAL mux_outs, reg_outs : bus_arr;
    SIGNAL reg_SEL_mux: STD_LOGIC_VECTOR(2 downto 0);
    SIGNAL reg_ENABLE_in : STD_LOGIC;

BEGIN
    -- Input Map
    in_rows(0)<=input_row_0; in_rows(1)<=input_row_1; in_rows(2)<=input_row_2; in_rows(3)<=input_row_3;
    in_rows(4)<=input_row_4; in_rows(5)<=input_row_5; in_rows(6)<=input_row_6; in_rows(7)<=input_row_7;
    in_cols(0)<=input_col_0; in_cols(1)<=input_col_1; in_cols(2)<=input_col_2; in_cols(3)<=input_col_3;
    in_cols(4)<=input_col_4; in_cols(5)<=input_col_5; in_cols(6)<=input_col_6; in_cols(7)<=input_col_7;

    enable_ff_inst: ff PORT MAP(ENABLE, CLK, RST_n, '1', reg_ENABLE_in);
    sel_reg: regnbit GENERIC MAP(3) PORT MAP(SEL_mux, CLK, RST_n, '1', reg_SEL_mux);

    GEN_ROWS: for r in 0 to 7 generate
        row_reg: regnbit GENERIC MAP(16) PORT MAP(in_rows(r), CLK, RST_n, ENABLE, reg_rows(r));
        col_reg: regnbit GENERIC MAP(16) PORT MAP(in_cols(r), CLK, RST_n, ENABLE, reg_cols(r));
        
        GEN_COLS: for c in 0 to 7 generate
            MAC_inst: MAC GENERIC MAP(16, 16) PORT MAP(reg_rows(r), reg_cols(c), CLK, RST_n, reg_ENABLE_in, mac_outs(r,c));
        end generate;

        mux_inst: mux_8to1_nbit GENERIC MAP(16) PORT MAP(
            mac_outs(r,0), mac_outs(r,1), mac_outs(r,2), mac_outs(r,3), 
            mac_outs(r,4), mac_outs(r,5), mac_outs(r,6), mac_outs(r,7),
            reg_SEL_mux, mux_outs(r)); --selecting output
            
        out_reg: regnbit GENERIC MAP(16) PORT MAP(mux_outs(r), CLK, RST_n, '1', reg_outs(r));
    end generate;

    output_row_0<=reg_outs(0); output_row_1<=reg_outs(1); output_row_2<=reg_outs(2); output_row_3<=reg_outs(3);
    output_row_4<=reg_outs(4); output_row_5<=reg_outs(5); output_row_6<=reg_outs(6); output_row_7<=reg_outs(7);
END behaviour;