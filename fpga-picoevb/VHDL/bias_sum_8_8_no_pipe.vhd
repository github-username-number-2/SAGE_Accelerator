LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY bias_sum_8_8 IS
    PORT (
        -- --------------------------------------
        -- --------------------------------------
        -- Modified by Che: bf16_adder_pipe has been replaced by regular bf16_adder without clk  
        -- --------------------------------------
        --clk : IN STD_LOGIC; -- Added clock port to support the pipelined adder
        input_row_0, input_row_1, input_row_2, input_row_3, 
        input_row_4, input_row_5, input_row_6, input_row_7 : IN STD_LOGIC_VECTOR(15 downto 0);
        b_col : IN STD_LOGIC_VECTOR(15 downto 0);
        output_row_0, output_row_1, output_row_2, output_row_3, 
        output_row_4, output_row_5, output_row_6, output_row_7 : OUT STD_LOGIC_VECTOR(15 downto 0)
    );
END bias_sum_8_8;

ARCHITECTURE structural OF bias_sum_8_8 IS

    -------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    -------------------------------------------------------------------
    -- Using a common bf16_add for MAC, gelu and bias_sum
    COMPONENT bf16_adder IS
        PORT (
            --clk : IN  STD_LOGIC;
            A   : IN  STD_LOGIC_VECTOR(15 downto 0);
            B   : IN  STD_LOGIC_VECTOR(15 downto 0);
            RES : OUT STD_LOGIC_VECTOR(15 downto 0)
        );
    END COMPONENT;

    --COMPONENT bf16_add IS
    --    PORT (
    --        --clk : IN  STD_LOGIC;
    --        A   : IN  STD_LOGIC_VECTOR(15 downto 0);
    --        B   : IN  STD_LOGIC_VECTOR(15 downto 0);
    --        S : OUT STD_LOGIC_VECTOR(15 downto 0)
    --    );
    --END COMPONENT;

    -------------------------------------------------------------------
    -- TYPE DEFINITIONS & INTERNAL SIGNALS
    -------------------------------------------------------------------
    TYPE array_8x16 IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(15 downto 0);
    SIGNAL row_inputs  : array_8x16;
    SIGNAL row_outputs : array_8x16;

BEGIN

    -- 1. Map discrete ports to internal input array
    row_inputs(0) <= input_row_0;
    row_inputs(1) <= input_row_1;
    row_inputs(2) <= input_row_2;
    row_inputs(3) <= input_row_3;
    row_inputs(4) <= input_row_4;
    row_inputs(5) <= input_row_5;
    row_inputs(6) <= input_row_6;
    row_inputs(7) <= input_row_7;

    -- 2. Parallel Pipelined Adder Generation
    gen_bias_adders: FOR i IN 0 TO 7 GENERATE
        inst_adder : bf16_adder
            PORT MAP (
                --clk => clk,
                A   => row_inputs(i),
                B   => b_col,
                RES => row_outputs(i)
            );
        --inst_adder : bf16_add
        --    PORT MAP (
        --        --clk => clk,
        --        A   => row_inputs(i),
        --        B   => b_col,
        --        S => row_outputs(i)
        --    );
    END GENERATE gen_bias_adders;

    -- 3. Map internal output array to discrete output ports
    output_row_0 <= row_outputs(0);
    output_row_1 <= row_outputs(1);
    output_row_2 <= row_outputs(2);
    output_row_3 <= row_outputs(3);
    output_row_4 <= row_outputs(4);
    output_row_5 <= row_outputs(5);
    output_row_6 <= row_outputs(6);
    output_row_7 <= row_outputs(7);

END structural;
