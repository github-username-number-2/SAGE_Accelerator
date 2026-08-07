library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.DataTypes_pkg.all; 

entity adapter_top is
    port (
        clk                      : in std_logic;
        rst_n                    : in std_logic;
        
        -- Data Ports (Matching AXI FSMD variables)
        x_in                     : in std_logic_vector(31 downto 0);
        y_out                    : out std_logic_vector(31 downto 0);
        
        -- Write Handshake Signals (SW -> HW)
        C_code_wdata_update_done : in std_logic;
        wdata_read_done          : out std_logic;
        
        -- Read Handshake Signals (HW -> SW)
        C_code_rdata_read_done   : in std_logic;
        rdata_ready_from_hw      : out std_logic
    );
end adapter_top;

architecture rtl of adapter_top is

    -- Internal Matrices and Biases
    signal mat_a_reg, mat_a_next : mat_2d_8_8_t;
    signal mat_b_reg, mat_b_next : mat_2d_8_8_t;
    signal mat_c_reg, mat_c_next : mat_2d_8_8_t;

    signal b_col_1_reg, b_col_1_next : std_logic_vector(15 downto 0) := (others => '0');
    signal b_col_2_reg, b_col_2_next : std_logic_vector(15 downto 0) := (others => '0');

    -- Sub-module Interface
    signal ffn_start             : std_logic;
    signal ffn_ready             : std_logic;
    signal ffn_out_gen_done      : std_logic;
    signal ffn_out_transmit_done : std_logic;
    signal ffn_mat_final         : mat_2d_8_8_t := (others => (others => (others => '0')));

    -- FSMD States
    type state_type is (
        receive_32bit_word, 
        ack_sw_handshake, 
        start_ffn, 
        wait_ffn_output_complete, 
        present_output, 
        ack_read_handshake
    );

    signal state_reg, state_next : state_type;

    -- Counters and Indices
    signal in_elem_cnt_reg, in_elem_cnt_next   : unsigned(7 downto 0) := (others => '0');
    signal out_elem_cnt_reg, out_elem_cnt_next : unsigned(7 downto 0) := (others => '0');

    signal in_mat_idx      : unsigned(1 downto 0);
    signal in_mat_row_idx  : unsigned(2 downto 0);
    signal in_mat_col_idx  : unsigned(2 downto 0);

    signal out_mat_row_idx : unsigned(2 downto 0);
    signal out_mat_col_idx : unsigned(2 downto 0);

    -- Registered Outputs for Handshake Flags (Prevents logic latches)
    signal wdata_read_done_reg, wdata_read_done_next         : std_logic := '0';
    signal rdata_ready_from_hw_reg, rdata_ready_from_hw_next : std_logic := '0';

begin

    
    -- FFN Compute Core Instantiation
    
    ffn_unit : entity work.adapter_3_stages_bf16_OneMAC_top
        port map (
            clk               => clk,
            rst_n             => rst_n,
            start             => ffn_start,
            mat_a             => mat_a_reg,
            mat_b             => mat_b_reg,
            mat_c             => mat_c_reg,
            b_col_1           => b_col_1_reg,
            b_col_2           => b_col_2_reg,
            out_transmit_done => ffn_out_transmit_done,
            ready             => ffn_ready,
            mat_final         => ffn_mat_final,
            out_gen_done      => ffn_out_gen_done
        );

    
    -- Index Extraction Logic
    
    -- A 32-bit word = 2 elements. Cnt increases by 2 each cycle.
    in_mat_col_idx <= in_elem_cnt_reg(2 downto 0);
    in_mat_row_idx <= in_elem_cnt_reg(5 downto 3);
    in_mat_idx     <= in_elem_cnt_reg(7 downto 6);

    out_mat_col_idx <= out_elem_cnt_reg(2 downto 0);
    out_mat_row_idx <= out_elem_cnt_reg(5 downto 3);

    
    -- Combinational Output Assignment
    
    -- Concatenates two 16-bit BF16 elements to form one 32-bit word for AXI read
    y_out <= ffn_mat_final(to_integer(out_mat_row_idx), to_integer(out_mat_col_idx) + 1) & 
             ffn_mat_final(to_integer(out_mat_row_idx), to_integer(out_mat_col_idx));

    wdata_read_done     <= wdata_read_done_reg;
    rdata_ready_from_hw <= rdata_ready_from_hw_reg;

    
    -- Synchronous Process
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state_reg               <= receive_32bit_word;
            mat_a_reg               <= (others => (others => (others => '0')));
            mat_b_reg               <= (others => (others => (others => '0')));
            mat_c_reg               <= (others => (others => (others => '0')));
            b_col_1_reg             <= (others => '0');
            b_col_2_reg             <= (others => '0');
            in_elem_cnt_reg         <= (others => '0');
            out_elem_cnt_reg        <= (others => '0');
            wdata_read_done_reg     <= '0';
            rdata_ready_from_hw_reg <= '0';
        elsif rising_edge(clk) then
            state_reg               <= state_next;
            mat_a_reg               <= mat_a_next;
            mat_b_reg               <= mat_b_next;
            mat_c_reg               <= mat_c_next;
            b_col_1_reg             <= b_col_1_next;
            b_col_2_reg             <= b_col_2_next;
            in_elem_cnt_reg         <= in_elem_cnt_next;
            out_elem_cnt_reg        <= out_elem_cnt_next;
            wdata_read_done_reg     <= wdata_read_done_next;
            rdata_ready_from_hw_reg <= rdata_ready_from_hw_next;
        end if;
    end process;

    
    -- Next-State & Combinational Logic Process
    
    process(
        state_reg, C_code_wdata_update_done, x_in, in_mat_idx, 
        in_mat_row_idx, in_mat_col_idx, mat_a_reg, mat_b_reg, mat_c_reg, 
        b_col_1_reg, b_col_2_reg, in_elem_cnt_reg, ffn_ready, ffn_out_gen_done, 
        out_elem_cnt_reg, C_code_rdata_read_done, wdata_read_done_reg, 
        rdata_ready_from_hw_reg, ffn_mat_final
    )
    begin
        -- Default assignments to prevent latches
        state_next               <= state_reg;
        mat_a_next               <= mat_a_reg;
        mat_b_next               <= mat_b_reg;
        mat_c_next               <= mat_c_reg;
        b_col_1_next             <= b_col_1_reg;
        b_col_2_next             <= b_col_2_reg;
        in_elem_cnt_next         <= in_elem_cnt_reg;
        out_elem_cnt_next        <= out_elem_cnt_reg;
        wdata_read_done_next     <= wdata_read_done_reg;
        rdata_ready_from_hw_next <= rdata_ready_from_hw_reg;
        
        ffn_start             <= '0';
        ffn_out_transmit_done <= '0';

        case state_reg is
 
            
            -- 1. WRITE LOOP (97 iterations / 194 elements)
            
            when receive_32bit_word =>
                if (C_code_wdata_update_done = '1') then
                    -- Route 32-bit x_in to the correct matrix based on current index
                    if (in_mat_idx = 0) then 
                        mat_a_next(to_integer(in_mat_row_idx), to_integer(in_mat_col_idx))   <= x_in(15 downto 0);
                        mat_a_next(to_integer(in_mat_row_idx), to_integer(in_mat_col_idx)+1) <= x_in(31 downto 16);
                    elsif (in_mat_idx = 1) then 
                        mat_b_next(to_integer(in_mat_row_idx), to_integer(in_mat_col_idx))   <= x_in(15 downto 0);
                        mat_b_next(to_integer(in_mat_row_idx), to_integer(in_mat_col_idx)+1) <= x_in(31 downto 16);
                    elsif (in_mat_idx = 2) then 
                        mat_c_next(to_integer(in_mat_row_idx), to_integer(in_mat_col_idx))   <= x_in(15 downto 0);
                        mat_c_next(to_integer(in_mat_row_idx), to_integer(in_mat_col_idx)+1) <= x_in(31 downto 16);
                    else 
                        if (in_elem_cnt_reg = 192) then 
                            b_col_1_next <= x_in(15 downto 0);
                            b_col_2_next <= x_in(31 downto 16);
                        end if;
                    end if;

                    in_elem_cnt_next     <= in_elem_cnt_reg + 2; 
                    wdata_read_done_next <= '1'; -- Signal AXI FSMD that data is latched
                    state_next           <= ack_sw_handshake;
                end if;

            when ack_sw_handshake =>
                -- Wait for C driver to clear the flag
                if (C_code_wdata_update_done = '0') then
                    wdata_read_done_next <= '0';
                    
                    if (in_elem_cnt_reg >= 194) then 
                        in_elem_cnt_next <= (others => '0'); 
                        state_next       <= start_ffn;
                    else 
                        state_next       <= receive_32bit_word;
                    end if;
                end if;

            
            -- 2. COMPUTE PHASE
            
            when start_ffn =>
                if (ffn_ready = '1') then
                    ffn_start  <= '1';
                    state_next <= wait_ffn_output_complete;
                end if;
                
            when wait_ffn_output_complete =>
                if (ffn_out_gen_done = '1') then 
                    state_next <= present_output;
                end if;

            
            -- 3. READ LOOP (32 iterations / 64 elements)
            
            when present_output =>
                -- `y_out` is combinational and constantly updated by `out_elem_cnt_reg`
                rdata_ready_from_hw_next <= '1'; -- Signal SW that y_out is ready to read
                
                if (C_code_rdata_read_done = '1') then
                    state_next <= ack_read_handshake;
                end if;

            when ack_read_handshake =>
                rdata_ready_from_hw_next <= '0';
                
                if (C_code_rdata_read_done = '0') then
                    
                    if (out_elem_cnt_reg >= 62) then
                        -- Entire matrix read back! Send done flag and return to Idle.
                        ffn_out_transmit_done <= '1'; 
                        out_elem_cnt_next     <= (others => '0');
                        state_next            <= receive_32bit_word; 
                    else
                        -- Increment index to present the next 32-bit word (2 elements)
                        out_elem_cnt_next <= out_elem_cnt_reg + 2;
                        state_next        <= present_output; 
                    end if;
                end if;

        end case;
    end process;

end rtl;
