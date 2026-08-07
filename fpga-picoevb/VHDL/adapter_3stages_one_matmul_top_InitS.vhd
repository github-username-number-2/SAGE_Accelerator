LIBRARY ieee;

USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
--use work.adapter_top_pkg.ALL; -- matA, B, C data types
--use work.gelu_pkg.ALL; -- matA, B, C data types
use work.DataTypes_pkg.ALL; -- matA, B, C data types

ENTITY adapter_3_stages_bf16_OneMAC_top IS
PORT (
    --this is the I-th column of Matrix A
    --input_row_0, input_row_1, input_row_2, input_row_3, input_row_4, input_row_5, input_row_6, input_row_7: IN STD_LOGIC_VECTOR(15 downto 0);
    --col_in_a, row_in_b, row_in_c, final_out : arr_t := (others => (others => '0'));

    --this is the I-th row of Matrix B
    --input_col_0, input_col_1, input_col_2, input_col_3, input_col_4, input_col_5, input_col_6, input_col_7: IN STD_LOGIC_VECTOR(15 downto 0);

    clk, rst_n : IN STD_LOGIC;
    start: IN STD_LOGIC;

    mat_a, mat_b, mat_c : IN mat_2d_8_8_t; 
    
    b_col_1 : IN STD_LOGIC_VECTOR(15 downto 0);
    b_col_2 : IN STD_LOGIC_VECTOR(15 downto 0);
    --bias_1      : in std_logic_vector(15 downto 0);
    --SEL_mux: IN STD_LOGIC_VECTOR(2 downto 0);
    --CLK, RST_n, ENABLE : IN STD_LOGIC;

    -- Input from uart indicating that output transmit is done, 
    --     Output registers can be reset and we can jump to idle. 
    out_transmit_done: IN std_logic;


    -- ready output
    ready: OUT STD_LOGIC;

    -- FINAL OUTPUTS
    --final_out_0, final_out_1, final_out_2, final_out_3 : out std_logic_vector(15 downto 0);
    --final_out_4, final_out_5, final_out_6, final_out_7 : out std_logic_vector(15 downto 0)

    -- FINAL output matrix is 8x8
    mat_final: OUT mat_2d_8_8_t; 

    -- Output that indicates output mat generation is done. It tells 
    --    uart_transmission to start transmitting output matrix.
    out_gen_done: OUT std_logic

);
END adapter_3_stages_bf16_OneMAC_top;

architecture adapter_3_stages_top_arch of adapter_3_stages_bf16_OneMAC_top is

    -- 1. Component Declaration: MAC Unit
    component MAC_bias_8x8_8_reg
        Port (
            input_row_0, input_row_1, input_row_2, input_row_3  :IN STD_LOGIC_VECTOR(15 downto 0); 
            input_row_4, input_row_5, input_row_6, input_row_7: IN STD_LOGIC_VECTOR(15 downto 0);
            
            input_col_0, input_col_1, input_col_2, input_col_3 : IN STD_LOGIC_VECTOR(15 downto 0);
            input_col_4, input_col_5, input_col_6, input_col_7: IN STD_LOGIC_VECTOR(15 downto 0);
            
            b_col    : IN STD_LOGIC_VECTOR(15 downto 0);
            SEL_mux  : IN STD_LOGIC_VECTOR(2 downto 0);
            CLK, RST_n, ENABLE : IN STD_LOGIC;
            
            output_row_0, output_row_1, output_row_2, output_row_3 : OUT STD_LOGIC_VECTOR(15 downto 0);
            output_row_4, output_row_5, output_row_6, output_row_7: OUT STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;

    -- 1. Declare Stage 1 (The MAC Wrapper you just verified)
--    component adapter_stage1
--        Port (
--            clk, rst_n, enable : in std_logic;
--            mat_a_row_0, mat_a_row_1, mat_a_row_2, mat_a_row_3 : in std_logic_vector(15 downto 0);
--            mat_a_row_4, mat_a_row_5, mat_a_row_6, mat_a_row_7 : in std_logic_vector(15 downto 0);
--            mat_b_col_0, mat_b_col_1, mat_b_col_2, mat_b_col_3 : in std_logic_vector(15 downto 0);
--            mat_b_col_4, mat_b_col_5, mat_b_col_6, mat_b_col_7 : in std_logic_vector(15 downto 0);
--            bias_1    : in std_logic_vector(15 downto 0);
--            sel_mux_1 : in std_logic_vector(2 downto 0);
--            output_row_0, output_row_1, output_row_2, output_row_3 : out std_logic_vector(15 downto 0);
--            output_row_4, output_row_5, output_row_6, output_row_7 : out std_logic_vector(15 downto 0)
--        );
--    end component;

    -- 2. Declare GeLU Block
    --component gelu_parallel
    --    Port (
    --        clk      : in  std_logic;
    --        rst_n    : in  std_logic;
    --        data_in  : in  arr_t; 
    --        data_out : out arr_t
    --    );
    --end component;
    
    component gelu_ispa_epss_parallel 
        Port (
            clk      : in  std_logic;
            rst_n    : in  std_logic;
            data_in  : in  arr_t; 
            data_out : out arr_t
        );
    end component;

    -- ================
    -- Define the sel signal that switch between phase1 and phase3 for the shared one MAC
    -- ================
    signal sel_stage_1or3: std_logic; 

    -- Define the new_input_MAC_rst_n to reset MAC for new input
    signal new_input_MAC_rst_n: std_logic;

    -- Define actual signals that connects to the input of the only one MAC unit, they are determined by 
    -- a select signal of a 2 to 1 MUX which selects mat_a , mat_b as input for phase 1, and selects 
    -- mat_d and mat_c as input for phase 3
 
    signal real_input_row_0, real_input_row_1, real_input_row_2, real_input_row_3  :STD_LOGIC_VECTOR(15 downto 0); 
    signal real_input_row_4, real_input_row_5, real_input_row_6, real_input_row_7: STD_LOGIC_VECTOR(15 downto 0);  

    signal real_input_col_0, real_input_col_1, real_input_col_2, real_input_col_3 : STD_LOGIC_VECTOR(15 downto 0);
    signal real_input_col_4, real_input_col_5, real_input_col_6, real_input_col_7: STD_LOGIC_VECTOR(15 downto 0);  
     
    signal real_b_col    : STD_LOGIC_VECTOR(15 downto 0);
    signal real_ENABLE   : STD_LOGIC;

    -- define actual signals that connects to the outputs of the only one MAC unit, they are determined by 
    -- a select signal of a 2 to 1 MUX which selects mat_ab as output for phase 1, and selects 
    -- mat_e output for phase 3

    --signal real_output_row_0, real_output_row_1, real_output_row_2, real_output_row_3 : STD_LOGIC_VECTOR(15 downto 0);
    --signal real_output_row_4, real_output_row_5, real_output_row_6, real_output_row_7: STD_LOGIC_VECTOR(15 downto 0);



    -- -----------------------
    -- Shared MAC, mac1 removed
    -- -----------------------
    -- Signals to connect Stage 1 Output -> GeLU Input
    --signal mac1_out_0, mac1_out_1, mac1_out_2, mac1_out_3 : std_logic_vector(15 downto 0);
    --signal mac1_out_4, mac1_out_5, mac1_out_6, mac1_out_7 : std_logic_vector(15 downto 0);

    -- -----------------------
    -- MAC_out_col (one col consisting of 8 values)
    -- -----------------------
    signal mac_out_col: arr_t;


    signal enable_1: STD_LOGIC;

    -- Signals for gelu inputs/outputs
    signal gelu_in_bus  : arr_t;
    signal gelu_out_bus : arr_t;

    -- ====================================
    -- Removed gelu_res by Wenjie: no need
    -- ====================================
    -- Signals connecting GeLU Output -> MAC Input in phase 3 (1 Col consists of Rows)
    --signal gelu_res_0, gelu_res_1, gelu_res_2, gelu_res_3 : std_logic_vector(15 downto 0);
    --signal gelu_res_4, gelu_res_5, gelu_res_6, gelu_res_7 : std_logic_vector(15 downto 0);

    -- =============================================================================
    -- =============================================================================
    -- Create new register signals to store gelu_out_bus for 8 cycles to store all 8 cols of gelu_out matrix (matD)
    --  This is because we cannot start phase 3 until all 8 cols of gelu out matrix (matD) has been generated and stored
    -- =============================================================================
    -- Why we must create storage for gelu out cols?
    -- ---------------------------------------------
    --   If we change the select mux to choose gelu_out col to be connect to MAC input col and input row, for the 
    --   first 3 clock cycles for loading "gelu_out_col_0 to gelu_out_col_2" as "col_0_in_D to col_2_in_D" for MAC inputs,  
    --   we must turn on accumulator enable=1 in order to accumulate results for these 3 input cols to avoid loss of matD x matC result
    --   data. But if we turn on accumulator enable=1, then the output cols 6-7 of current matAB result will accumulate new values and 
    --   will change its value, resulting in lost of data for output cols 6-7 in matAB results, which goes to gelu_input, resulting in
    --   incorrect gelu output values. 
    -- =============================================================================
    --signal stored_gelu_out_8cols_reg, stored_gelu_out_8cols_next: mat_2d_8_8_t;
    signal stored_gelu_out_8cols_reg, stored_gelu_out_8cols_next: gelu_out_8cols_8_arr_t_t; 

    signal gelu_out_col_i_cnt_reg, gelu_out_col_i_cnt_next: unsigned(3 downto 0); 
    signal col_in_stored_gelu_out_8cols: arr_t;

    --signal stored_gelu_out_col_0_reg, stored_gelu_out_col_0_next: arr_t;
    --signal stored_gelu_out_col_1_reg, stored_gelu_out_col_1_next: arr_t;
    --signal stored_gelu_out_col_2_reg, stored_gelu_out_col_2_next: arr_t;
    --signal stored_gelu_out_col_3_reg, stored_gelu_out_col_3_next: arr_t;
    --signal stored_gelu_out_col_4_reg, stored_gelu_out_col_4_next: arr_t;
    --signal stored_gelu_out_col_5_reg, stored_gelu_out_col_5_next: arr_t;
    --signal stored_gelu_out_col_6_reg, stored_gelu_out_col_6_next: arr_t;
    --signal stored_gelu_out_col_7_reg, stored_gelu_out_col_7_next: arr_t;

    constant MAT_DIM: integer := 8;
    --type real_8_8_t is array (0 to MAT_DIM-1, 0 to  MAT_DIM-1) of real;
    
    
    -- Define sel_mux for phase 1: sel_mux_1_reg, and phase 3: sel_mux_2_reg:
    --signal clk, rst_n, enable : std_logic := '0';
    signal sel_mux_1_reg, sel_mux_1_next : unsigned(2 downto 0);
    signal sel_mux_2_reg, sel_mux_2_next : unsigned(2 downto 0);
    signal real_sel_mux  : unsigned(2 downto 0);
    --signal bias_1, bias_2 : std_logic_vector(15 downto 0) := (others => '0');

    -- Mat inputs: col_in_a, and row_in_b (each are 8 values)
    --type arr_t is array (0 to 7) of std_logic_vector(15 downto 0);
    signal col_in_a, row_in_b : arr_t := (others => (others => '0'));
   
    -- Note: Both need to be more than 3 bits, in order to specify a value out of 0-7 cols range
    --       in order to disable the update of gelu_out_col_i registers and final_mat_col_i registers
    signal matA_col_matB_row_i_reg, matA_col_matB_row_i_next: unsigned(3 downto 0);  

    signal matD_col_matC_row_i_reg, matD_col_matC_row_i_next: unsigned(3 downto 0);  


    -- Matrix C Inputs (1 Row consists of Cols) - Post-factor for 2nd MAC
    -- (The GeLU output will be the Pre-factor Columns of Matrix D)
    -- Note: changed mat_c_col_0 - mat_c_col_7 to be row_in_c:
    --signal mat_c_col_0, mat_c_col_1, mat_c_col_2, mat_c_col_3 : std_logic_vector(15 downto 0);
    --signal mat_c_col_4, mat_c_col_5, mat_c_col_6, mat_c_col_7 : std_logic_vector(15 downto 0);
    signal row_in_c: arr_t := (others => (others => '0'));

    signal enable_2: STD_LOGIC;

    -- ---------------------
    -- This is a signal that is used to reset MAC before starting stage 3
    -- ---------------------
    signal stage3_MAC_rst_n: STD_LOGIC;
    -- ---------------------
    -- This is the actual reset that connects to the common MAC 
    -- ---------------------
    signal actual_MAC_rst_n: STD_LOGIC;

    -- Final matrix registers 8x8
    signal mat_final_reg, mat_final_next: mat_2d_8_8_t; 

    signal wait_2_cycles_cnter_reg, wait_2_cycles_cnter_next: unsigned(1 downto 0);
    type state_type is (Idle, Initialize, Load_matA_cols_matB_rows, Read_matAB_cols_init, Read_matAB_cols, start_phase_3, Load_matD_cols_matC_rows, Read_final_mat_cols_init, Read_final_mat_cols, wait_out_transmit_done);
    signal state_reg, state_next : state_type;

    signal ready_reg, ready_next : std_logic;

    signal start_mm_d: std_logic;
    signal ready_mm_d: std_logic;
    --type arr_t is array (0 to 7) of std_logic_vector(15 downto 0);
    
    --type mat_2d_8_8_t is array (0 to 7, 0 to 7) of std_logic_vector(15 downto 0);

    --constant MAT_A : real_2d_8_8_t :
       -- (0.1,  0.8,  0.3,  0.2, 0, 0, 0, 0),
        --(0.2,  0.36, 0.2,  0.52,  0, 0, 0, 0),
       -- (0.03, 0.2,  0.1,  07, 0, 0, 0, 0),
       -- (0.04, 0.14, 0.0,  0.9,  0, 0, 0, 0),
       -- (0.05, 0.1,  0.29, 0.1,  0, 0, 0, 0),
        --(0.62, 0.12, 0.4,  0.75,  0, 0, 0, 0),
        --(0.07, 0.9,  0.34, 0.1,  0, 0, 0, 0),
        --(0.88, 0.4,  0.1,  0.4,  0, 0, 0, 0)
    --);
    
   -- constant MAT_B : real_8_8_t := (
      --  (0.1,  0.8,  0.3,  0.2, 0, 0, 0, 0),
        --(0.2,  0.36, 0.2,  0.52,  0, 0, 0, 0),
        --(0.03, 0.2,  0.1,  07, 0, 0, 0, 0),
        --(0.04, 0.14, 0.0,  0.9,  0, 0, 0, 0),
        --(0.05, 0.1,  0.29, 0.1,  0, 0, 0, 0),
        --(0.62, 0.12, 0.4,  0.75,  0, 0, 0, 0),
        --(0.07, 0.9,  0.34, 0.1,  0, 0, 0, 0),
        --(0.88, 0.4,  0.1,  0.4,  0, 0, 0, 0)
    --); it will be in tb

    begin

    -- =============================================================================
    -- Instantiation one common MAC for phase 1 and 3 
    -- =============================================================================
    -- Phase 1: First Matrix Multiplication (Mat_A x Mat_B)
    -- Phase 3: Second Matrix Multiplication (Mat_D x Mat_C), Mat_D consists of gelu_out_bus (gelu_res_0 to gelu_res_7)
    -- =============================================================================

    inst_common_mac_for_stage1_and_3: MAC_bias_8x8_8_reg
        port map (
            CLK         => clk,
            RST_n       => actual_MAC_rst_n,
            ENABLE      => real_ENABLE,
        
            input_row_0 => real_input_row_0, 
            input_row_1 => real_input_row_1, 
            input_row_2 => real_input_row_2, 
            input_row_3 => real_input_row_3, 
            input_row_4 => real_input_row_4, 
            input_row_5 => real_input_row_5, 
            input_row_6 => real_input_row_6, 
            input_row_7 => real_input_row_7, 
        
            input_col_0 => real_input_col_0,
            input_col_1 => real_input_col_1,
            input_col_2 => real_input_col_2,
            input_col_3 => real_input_col_3,
            input_col_4 => real_input_col_4,
            input_col_5 => real_input_col_5,
            input_col_6 => real_input_col_6,
            input_col_7 => real_input_col_7,
        
            b_col       => real_b_col,     
            SEL_mux     => std_logic_vector(real_sel_mux),
        
            output_row_0 => mac_out_col(0),
            output_row_1 => mac_out_col(1),
            output_row_2 => mac_out_col(2),
            output_row_3 => mac_out_col(3),
            output_row_4 => mac_out_col(4),
            output_row_5 => mac_out_col(5),
            output_row_6 => mac_out_col(6),
            output_row_7 => mac_out_col(7)
        );

    -- real input col for MAC:  mat_a when phase1, gelu_out_bus when phase3
    -- input col: rows 1 to 7:
    real_input_row_0 <= col_in_a(0) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(0);
    real_input_row_1 <= col_in_a(1) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(1);
    real_input_row_2 <= col_in_a(2) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(2);
    real_input_row_3 <= col_in_a(3) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(3);
    real_input_row_4 <= col_in_a(4) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(4);
    real_input_row_5 <= col_in_a(5) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(5);
    real_input_row_6 <= col_in_a(6) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(6);
    real_input_row_7 <= col_in_a(7) when (sel_stage_1or3 = '0' ) else 
                        col_in_stored_gelu_out_8cols(7);

    -- real input row for MAC:  mat_b when phase1, mat_c when phase3
    -- one input row: cols 1 to 7:
    real_input_col_0 <= row_in_b(0) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(0);
    real_input_col_1 <= row_in_b(1) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(1);
    real_input_col_2 <= row_in_b(2) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(2);
    real_input_col_3 <= row_in_b(3) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(3);
    real_input_col_4 <= row_in_b(4) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(4);
    real_input_col_5 <= row_in_b(5) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(5);
    real_input_col_6 <= row_in_b(6) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(6);
    real_input_col_7 <= row_in_b(7) when (sel_stage_1or3 = '0' ) else 
                        row_in_c(7);

    -- real bias value for MAC:  b_col_1 when phase1, b_col_2 when phase3
    real_b_col <= b_col_1 when (sel_stage_1or3 = '0' ) else 
                  b_col_2; 
    real_sel_mux <= sel_mux_1_reg when (sel_stage_1or3 = '0' ) else 
                    sel_mux_2_reg;
        
    -- enable accumulator for Phase 1 MAC: matA x matB; or Phase 3: matD x matC 
    real_ENABLE <= enable_1 when (sel_stage_1or3 = '0' ) else 
                   enable_2;

    -- real output of MAC (1 output col) will be split into 2 branches: 
    --    1. One goes to gelu_in_bus. 2. One goes to "final_mat_col_i_next": 


    -- =============================================================================
    -- =============================================================================
    -- Connect Phase1 output with Phase2 input: Connect each col of matAB (8 values) to gelu_in_bus (8 values) 
    gelu_in_bus <= mac_out_col when sel_stage_1or3 = '0' else
		   (others => (others => '0'));

    -- =============================================================================
    -- Instantiate Phase 2: GeLU Activation
    -- =============================================================================
    --inst_gelu: gelu_parallel
    inst_gelu: gelu_ispa_epss_parallel 
        port map (
            clk      => clk,
            rst_n    => rst_n,
            data_in  => gelu_in_bus,
            data_out => gelu_out_bus
        );

    -- actual_MAC_rst_n connects to top-level "rst_n" AND 'new_input_MAC_rst_n' when stage 1, 
    ---    or "stage3_MAC_rst_n" when stage 3
    -- Note: when stage_1, it must be the ANDed result of rst_n and new_input_MAC_rst_n because the reset is active low
    actual_MAC_rst_n <= (rst_n and new_input_MAC_rst_n) when sel_stage_1or3='0' else 
			stage3_MAC_rst_n;
    

    -- Removed gelu_res_0: no need
    --gelu_res_0 <= gelu_out_bus(0);
    --gelu_res_1 <= gelu_out_bus(1);
    --gelu_res_2 <= gelu_out_bus(2);
    --gelu_res_3 <= gelu_out_bus(3);
    --gelu_res_4 <= gelu_out_bus(4);
    --gelu_res_5 <= gelu_out_bus(5);
    --gelu_res_6 <= gelu_out_bus(6);
    --gelu_res_7 <= gelu_out_bus(7);
    
    -- =============================================================================
    -- =============================================================================
    -- Create new register signals to store gelu_out_bus for 8 cycles to store all 8 cols of gelu_out matrix (matD)
    --  This is because we cannot start phase 3 until all 8 cols of gelu out matrix (matD) has been generated and stored
    -- =============================================================================
    --signal stored_gelu_out_col_0_reg, stored_gelu_out_col_0_next: arr_t;
    --signal stored_gelu_out_col_1_reg, stored_gelu_out_col_1_next: arr_t;
    --signal stored_gelu_out_col_2_reg, stored_gelu_out_col_2_next: arr_t;
    --signal stored_gelu_out_col_3_reg, stored_gelu_out_col_3_next: arr_t;
    --signal stored_gelu_out_col_4_reg, stored_gelu_out_col_4_next: arr_t;
    --signal stored_gelu_out_col_5_reg, stored_gelu_out_col_5_next: arr_t;
    --signal stored_gelu_out_col_6_reg, stored_gelu_out_col_6_next: arr_t;
    --signal stored_gelu_out_col_7_reg, stored_gelu_out_col_7_next: arr_t;



    -- =============================================================================
    -- Creat state registers and data registers
    -- =============================================================================
    process(clk, rst_n)
        begin
        --if rst_n = '1'reset = '1' then
        if rst_n = '0' then
	    -- Initiate State registers
            state_reg <= Idle;

            ready_reg <= '1';
	    -- ---------------------------
	    -- Initiate Data registers
	    -- ---------------------------
            sel_mux_1_reg <= (others => '0');
            sel_mux_2_reg <= (others => '0');

	    -- ---------------------------
	    -- sel_matAB_col_i and sel_store_matD_col_i for selecting one output col at a time 
	    -- Note: Both need to be more than 3 bits, in order to specify a value out of 0-7 cols range
	    --       in order to disable the update of gelu_out_col_i registers and final_mat_col_i registers
	    -- ---------------------------
            matA_col_matB_row_i_reg <= (others => '0');
            matD_col_matC_row_i_reg <= (others => '0');

            gelu_out_col_i_cnt_reg <= (others => '0');

            stored_gelu_out_8cols_reg <= (others => (others => (others => '0')));
            mat_final_reg <= (others => (others => (others => '0')));

            wait_2_cycles_cnter_reg  <= (others => '0');
 

            --stored_gelu_out_col_0_reg <= (others => (others => '0'));
            --stored_gelu_out_col_1_reg <= (others => (others => '0'));
            --stored_gelu_out_col_2_reg <= (others => (others => '0'));
            --stored_gelu_out_col_3_reg <= (others => (others => '0'));
            --stored_gelu_out_col_4_reg <= (others => (others => '0'));
            --stored_gelu_out_col_5_reg <= (others => (others => '0'));
            --stored_gelu_out_col_6_reg <= (others => (others => '0'));
            --stored_gelu_out_col_7_reg <= (others => (others => '0'));

        elsif rising_edge(clk) then
	    -- Update State registers
            state_reg <= state_next;

            ready_reg <= ready_next;

	    -- Update Data registers
            sel_mux_1_reg <= sel_mux_1_next;
            sel_mux_2_reg <= sel_mux_2_next;

            matA_col_matB_row_i_reg <= matA_col_matB_row_i_next; 
            matD_col_matC_row_i_reg <= matD_col_matC_row_i_next;

            gelu_out_col_i_cnt_reg <= gelu_out_col_i_cnt_next;

            stored_gelu_out_8cols_reg <= stored_gelu_out_8cols_next; 
            mat_final_reg <= mat_final_next;

            wait_2_cycles_cnter_reg  <= wait_2_cycles_cnter_next;
            --stored_gelu_out_col_0_reg <= stored_gelu_out_col_0_next; 
            --stored_gelu_out_col_1_reg <= stored_gelu_out_col_1_next; 
            --stored_gelu_out_col_2_reg <= stored_gelu_out_col_2_next; 
            --stored_gelu_out_col_3_reg <= stored_gelu_out_col_3_next; 
            --stored_gelu_out_col_4_reg <= stored_gelu_out_col_4_next; 
            --stored_gelu_out_col_5_reg <= stored_gelu_out_col_5_next; 
            --stored_gelu_out_col_6_reg <= stored_gelu_out_col_6_next; 
            --stored_gelu_out_col_7_reg <= stored_gelu_out_col_7_next; 

        end if;
    end process;

  process(ready_reg, start, state_reg, matA_col_matB_row_i_reg, matD_col_matC_row_i_reg, sel_mux_1_reg, sel_mux_2_reg, 
	  stored_gelu_out_8cols_reg, mat_final_reg, mat_a, mat_b, gelu_out_col_i_cnt_reg, gelu_out_bus,
          mat_c, mac_out_col, wait_2_cycles_cnter_reg, out_transmit_done )
    begin
    -- =============================================
    --specify default values for register inputs(_next)
    -- =============================================

        ready_next <= ready_reg;

        --state_reg stores the current state
        --state_next stores the next state
        state_next  <= state_reg;

        matA_col_matB_row_i_next <= matA_col_matB_row_i_reg; 
        matD_col_matC_row_i_next <= matD_col_matC_row_i_reg;

        -- reset MAC when receiving new input (only in Idle)
        new_input_MAC_rst_n <= '1';

	-- Select output cols for phase_1 and phase_3 respectively
        sel_mux_1_next <= sel_mux_1_reg;
        sel_mux_2_next <= sel_mux_2_reg;

        gelu_out_col_i_cnt_next <= gelu_out_col_i_cnt_reg;

	-- Stored gelu out col registers
        stored_gelu_out_8cols_next <= stored_gelu_out_8cols_reg; 

        -- Default value for mat_final
        mat_final_next <= mat_final_reg;

        wait_2_cycles_cnter_next <= wait_2_cycles_cnter_reg;
        --stored_gelu_out_col_0_next <= stored_gelu_out_col_0_reg; 
        --stored_gelu_out_col_1_next <= stored_gelu_out_col_1_reg; 
        --stored_gelu_out_col_2_next <= stored_gelu_out_col_2_reg; 
        --stored_gelu_out_col_3_next <= stored_gelu_out_col_3_reg; 
        --stored_gelu_out_col_4_next <= stored_gelu_out_col_4_reg; 
        --stored_gelu_out_col_5_next <= stored_gelu_out_col_5_reg; 
        --stored_gelu_out_col_6_next <= stored_gelu_out_col_6_reg; 
        --stored_gelu_out_col_7_next <= stored_gelu_out_col_7_reg; 

        -- default value for sel_stage_1or3 
        sel_stage_1or3 <= '0';

        -- Default values of enable signals for enabling accumulator for phase 1 and 3 
        enable_1 <= '0';
	enable_2 <= '0';

        -- default value to reset MAC before starting stage 3 (do not reset) 
        stage3_MAC_rst_n <= '1'; 

        out_gen_done <= '0'; 


        case state_reg is
        
            when Idle =>
		-- Set ready = 1 to tell outside it is ready for processing next input
                ready_next <= '1';

                -- Check if start=1
                if start = '1' then
                    ready_next <= '0';
                    state_next <= Initialize;
                end if;


            -- -------------------
            -- Initialize after start
            -- -------------------
            when Initialize =>

                -- Reset the wait_2_cycles_cnter
                wait_2_cycles_cnter_next <= (others => '0');

                -- Reset the wait_2_cycles_cnter
                mat_final_next <= (others => (others => (others => '0')));


                -- Reset the MAC to be ready for new input
                new_input_MAC_rst_n <= '1'; 

                -- enable accumulator for 1st matmul matA x matB
                sel_stage_1or3 <= '0';

                -- Enable accumulator for 1st matmul matA x matB. 
                -- Default value is 0, need to set for all states for phase 1
                enable_1 <= '1';

                -- Initialize i
                matA_col_matB_row_i_next <= (others => '0'); --reset to 0, start counting;
                state_next <= Load_matA_cols_matB_rows;

            -- -------------------
	    -- Load the i-th col in a, and i-th row in b at a time, repeat 8 cycles to load all 8 cols/rows
            -- Where i is: matA_col_matB_row_i_reg
            -- -------------------
            when Load_matA_cols_matB_rows =>

		-- Enable accumulator for phase 1 matmul matA x matB. 
		-- Default value is 0, need to set for all states for phase 1
		enable_1 <= '1';

                col_in_a(0) <= mat_a(0, to_integer(matA_col_matB_row_i_reg));
                col_in_a(1) <= mat_a(1, to_integer(matA_col_matB_row_i_reg));
                col_in_a(2) <= mat_a(2, to_integer(matA_col_matB_row_i_reg));
                col_in_a(3) <= mat_a(3, to_integer(matA_col_matB_row_i_reg));
                col_in_a(4) <= mat_a(4, to_integer(matA_col_matB_row_i_reg));
                col_in_a(5) <= mat_a(5, to_integer(matA_col_matB_row_i_reg));
                col_in_a(6) <= mat_a(6, to_integer(matA_col_matB_row_i_reg));
                col_in_a(7) <= mat_a(7, to_integer(matA_col_matB_row_i_reg));
                    
                row_in_b(0) <= mat_b( to_integer(matA_col_matB_row_i_reg), 0);
                row_in_b(1) <= mat_b( to_integer(matA_col_matB_row_i_reg), 1);
                row_in_b(2) <= mat_b( to_integer(matA_col_matB_row_i_reg), 2);
                row_in_b(3) <= mat_b( to_integer(matA_col_matB_row_i_reg), 3);
                row_in_b(4) <= mat_b( to_integer(matA_col_matB_row_i_reg), 4);
                row_in_b(5) <= mat_b( to_integer(matA_col_matB_row_i_reg), 5);
                row_in_b(6) <= mat_b( to_integer(matA_col_matB_row_i_reg), 6);
                row_in_b(7) <= mat_b( to_integer(matA_col_matB_row_i_reg), 7);
                    
                -- Repeat 8 cycles to load all 8 cols/rows
                if matA_col_matB_row_i_reg < 7 then
                    matA_col_matB_row_i_next <= matA_col_matB_row_i_reg + 1;
                else  
                    state_next <= Read_matAB_cols_init;
	        end if;


            -- Wait for 1 more clock cycle after processing the last column x row
            when Read_matAB_cols_init =>
                
                -- Disable accumulator for matA x matB to preserve all 8 output cols values unchanged
                enable_1 <= '0';

		-- Initiazlie MAC output col select to 0
                sel_mux_1_next <= (others => '0');

		-- Initiazlie gelu output col counter to 0
                gelu_out_col_i_cnt_next <= (others => '0');


                state_next <= Read_matAB_cols;
                
            when Read_matAB_cols =>
                
                -- Assign sel_mux_1 values from 0-7 to output one col at a time 
                if (sel_mux_1_reg < 7) then
                    sel_mux_1_next <= sel_mux_1_reg +1;
                end if;

		-- ---------------------------------------------------------
		-- The first matAB col (gelu_in_bus) takes (4+1) cycles to produce
		--     the corresponding gelu_out_bus values
		-- ---------------------------------------------------------
		-- gelu_out_bus for first matAB col will be ready after (4+1) cycles 
		-- i.e., (4+1) cycles later (at the 5th cycle), gelu_out_bus has the 1st col of matD 
		--       for the 2nd MatMul 
		-- ---------------------------------------------------------

                -- We have to start to store the gelu output columns at the sixth cycle otherwise they will be lost. 
                --if (sel_mux_1_reg > 5) then -- (4+2) cycles later
                --if (sel_mux_1_reg > 4) then -- 5 cycles or (4+1) cycles later?
                if (sel_mux_1_reg > 3) then -- 4 cycles cycles later
                    -- ===========================================
                    -- In this one-MAC version of adapter, we cannot start loading MAT D 
                    --    untill all 8 gelu output columns are produced and stored.
                    -- Start to store the gelu output columns at the sixth cycle otherwise they will be lost.  

                    -- Start a new counter gelu_out_col_i_cnt to track which output col in current gelu_out_bus
                    gelu_out_col_i_cnt_next <= gelu_out_col_i_cnt_reg + 1; 

                    --type gelu_out_8cols_arr_t is array (0 to 7) of arr_t; 
		    -- signal stored_gelu_out_8cols_reg gelu_out_8cols_8_arr_t_t; 

                    -- Store the current_gelu_out_col as the (i=gelu_out_col_i_cnt)-th col
                    stored_gelu_out_8cols_next(to_integer(gelu_out_col_i_cnt_reg)) <= gelu_out_bus;

		    -- ------------------------------------------
                    -- After storing the last gelu_out_col, start phase_3 
		    -- ------------------------------------------
                    if (gelu_out_col_i_cnt_reg = 7) then
                        --stored_gelu_out_col_7_next <= gelu_out_bus;

                        -- Need to further add 1 to set the gelu_out_col_i_cnt to 8 so that it 
			--    is out of range 0-7 to stop updating the 8 cols of gelu_out
                        gelu_out_col_i_cnt_next <= gelu_out_col_i_cnt_reg + 1; 

                        -- All 8 gelu_output cols have been saved in regs. Jump to Phase 3
                        state_next <= start_phase_3;
                    end if; 
                end if;

            -- Start a new state for starting Phase 3
            when start_phase_3 => 
                -- -----------------------------------
                -- Set sel_stage_1or3 to 1 to indicate that the one MAC will be used 
                --     for phase3 next 
                -- Setting sel_stage_1or3=1 will automatically assign appropriate values 
                --     to MAC inputs in above "when else" 
                -- -----------------------------------
                -- Need to keep setting this to '1' in all states of Phase3 (default is 0) 
                sel_stage_1or3 <= '1';

                -- Need to reset MAC before starting stage 3, reset for one cycle is enough 
                stage3_MAC_rst_n <= '0'; 

                -- -----------------------------------
                -- Enable accumulator for 2nd matmul matD x matC
                -- Here with 1 mac, we need to wait until all gelu output cols have been stored
                --   before setting enable_2 = 1
                -- -----------------------------------
                -- Need to assert it in all states during phase 3 computation
                enable_2 <= '1';

                -- Initialize matD_col_matC_row counter to 0
                matD_col_matC_row_i_next <= (others => '0'); 

                state_next <= Load_matD_cols_matC_rows;

            when Load_matD_cols_matC_rows =>
                -- -----------------------------------
		-- Need to keep setting stage to stage3 in all states of Phase3 (default is 0) 
                -- -----------------------------------
                sel_stage_1or3 <= '1';

                -- -----------------------------------
                -- Enable accumulator for 2nd matmul matD x matC
                -- -----------------------------------
                -- Need to assert it in all states during phase 3 computation
                enable_2 <= '1';

                -- -----------------------------------
                --   for the 2nd MatMul calculation
		-- Note: sel_mux_2_reg will be selected instead of sel_mux_1_reg 
                -- -----------------------------------
		-- ===========================================
		-- Load matD_col_i as stored_gelu_out_col_i_reg to real_input_row_i: 
		-- ===========================================
		col_in_stored_gelu_out_8cols <= stored_gelu_out_8cols_reg(to_integer(matD_col_matC_row_i_reg));

		-- ===========================================
		-- Load matC_row_i: Similar to assign the i-th row in matB 
		-- ===========================================
                -- Note: changed mat_c_col_0 - mat_c_col_7 to row_in_c 
                row_in_c(0) <= mat_c(to_integer(matD_col_matC_row_i_reg), 0); 
                row_in_c(1) <= mat_c(to_integer(matD_col_matC_row_i_reg), 1);
                row_in_c(2) <= mat_c(to_integer(matD_col_matC_row_i_reg), 2);
                row_in_c(3) <= mat_c(to_integer(matD_col_matC_row_i_reg), 3);
                row_in_c(4) <= mat_c(to_integer(matD_col_matC_row_i_reg), 4);
                row_in_c(5) <= mat_c(to_integer(matD_col_matC_row_i_reg), 5);
                row_in_c(6) <= mat_c(to_integer(matD_col_matC_row_i_reg), 6);
                row_in_c(7) <= mat_c(to_integer(matD_col_matC_row_i_reg), 7);
        
		-- ===========================================
		-- Increment matD_col_matC_row_i_next 
		-- ===========================================
                -- -----------------------------------
                -- Start loading matD_col_i and matC_row_i where i starts at 0
                -- -----------------------------------
                if matD_col_matC_row_i_reg < 7 then
                    matD_col_matC_row_i_next <= matD_col_matC_row_i_reg + 1;  
		else
                    state_next <= Read_final_mat_cols_init;
		end if;

            when Read_final_mat_cols_init =>
                -- -----------------------------------
		-- Need to keep setting stage to stage3 in all states of Phase3 (default is 0) 
                -- -----------------------------------
                sel_stage_1or3 <= '1';
                
		-- Disable accumulator for 2nd matmul matD x matC
		enable_2 <= '0';

		-- Initialize MAC output select col to 0 for phase 3
                sel_mux_2_next <= (others => '0');

                state_next <= Read_final_mat_cols;
                
            when Read_final_mat_cols =>
                -- -----------------------------------
		-- Need to keep setting stage to stage3 in all states of Phase3 (default is 0) 
                -- -----------------------------------
                sel_stage_1or3 <= '1';
                
		-- Assign current mac_out_col to the (sel_mux_2_reg)-th col of final output mat
		-- Note: since mac_out_col result won't be available until 2 cycles later after setting sel_mux_2_reg value
                --       We will assign the current mac_out_col to mat_final_next(i, sel_mux_2_reg-2)	

		if (sel_mux_2_reg >= 2 and wait_2_cycles_cnter_reg < 3 ) then 
                    mat_final_next(0, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(0);
                    mat_final_next(1, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(1);
                    mat_final_next(2, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(2);
                    mat_final_next(3, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(3);
                    mat_final_next(4, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(4);
                    mat_final_next(5, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(5);
                    mat_final_next(6, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(6);
                    mat_final_next(7, to_integer(sel_mux_2_reg + wait_2_cycles_cnter_reg - 2)) <= mac_out_col(7);
                end if;

		-- Assign sel_mux_2 values from 0-7 to output 1 col at a time 
		if (sel_mux_2_reg < 7) then
		    sel_mux_2_next <= sel_mux_2_reg +1;
		--else 
                --    state_next <= Idle;
                elsif (wait_2_cycles_cnter_reg > 2) then 
                    state_next <= wait_out_transmit_done;
		else 
                    -- increment wait_2_cycles_cnter by 1
                    wait_2_cycles_cnter_next <= wait_2_cycles_cnter_reg+1; 
		end if;

            when wait_out_transmit_done =>
                -- -----------------------------------
		-- Need to keep setting stage to stage3 in all states of Phase3 (default is 0) 
                -- -----------------------------------
                sel_stage_1or3 <= '1';

                out_gen_done <= '1';
                if out_transmit_done = '1' then 
                    state_next <= Idle;

                    -- Wait at this state to preserve mat_final values for uart to transmit
                    --state_next <= wait_out_transmit_done;
                end if;
   
                
        end case;
    end process;

    ready <= ready_reg;

    mat_final <= mat_final_reg;

end adapter_3_stages_top_arch;

