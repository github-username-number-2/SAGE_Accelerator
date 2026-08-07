LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY MAC IS
    GENERIC ( 
        data_size : POSITIVE := 16; 
        acc_size  : POSITIVE := 16  
    );
    PORT( 
        data_in_A, data_in_B : IN STD_LOGIC_VECTOR(data_size-1 downto 0);
        CLK, RST_n, ENABLE   : IN STD_LOGIC;
        data_out             : OUT STD_LOGIC_VECTOR(acc_size-1 downto 0)
    );
END MAC;

ARCHITECTURE structural OF MAC IS

    -------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    -------------------------------------------------------------------
    COMPONENT BF16_MUL IS
        PORT (
            a : in  std_logic_vector(15 downto 0);
            b : in  std_logic_vector(15 downto 0);
            p : out std_logic_vector(15 downto 0)
        );
    END COMPONENT;

    -- Changed to your new purely combinational adder
    --COMPONENT bf16_adder IS
    --    PORT (
    --        A   : IN  STD_LOGIC_VECTOR(15 downto 0);
    --        B   : IN  STD_LOGIC_VECTOR(15 downto 0);
	    -- ----------------------------
	    -- Use one bf16_adder for MAC and gelu
	    -- ----------------------------
            --RES : OUT STD_LOGIC_VECTOR(15 downto 0)
   --         S : OUT STD_LOGIC_VECTOR(15 downto 0)
   --     );
   -- END COMPONENT;

    -- Changed to your new purely combinational adder
    --COMPONENT BF16_ADD IS
    COMPONENT bf16_adder IS
        PORT (
            A   : IN  STD_LOGIC_VECTOR(15 downto 0);
            B   : IN  STD_LOGIC_VECTOR(15 downto 0);
	    -- ----------------------------
	    -- Use one bf16_adder for MAC and gelu
	    -- ----------------------------
            RES : OUT STD_LOGIC_VECTOR(15 downto 0)

            --S : OUT STD_LOGIC_VECTOR(15 downto 0)
        );
    END COMPONENT;

    -------------------------------------------------------------------
    -- INTERNAL SIGNALS
    -------------------------------------------------------------------
    SIGNAL product_slv : STD_LOGIC_VECTOR(15 downto 0);
    SIGNAL adder_out   : STD_LOGIC_VECTOR(15 downto 0);
    SIGNAL acc_reg     : STD_LOGIC_VECTOR(15 downto 0);

BEGIN

    -- 1. Combinational Multiplier
    inst_mult : BF16_MUL
        PORT MAP (
            a => data_in_A,
            b => data_in_B,
            p => product_slv
        );

    -- 2. Combinational Adder (No CLK port needed)
    --inst_adder : BF16_ADD
    inst_adder : bf16_adder
        PORT MAP (
            A   => product_slv,
            B   => acc_reg,
	    -- ----------------------------
	    -- Use one bf16_adder for MAC and gelu
	    -- ----------------------------
            RES => adder_out
            --S => adder_out
        );

    -- 3. Accumulator Register
    PROCESS(CLK, RST_n)
    BEGIN
        IF RST_n = '0' THEN
            acc_reg <= (others => '0');
        ELSIF rising_edge(CLK) THEN
            IF ENABLE = '1' THEN
                acc_reg <= adder_out;
            END IF;
        END IF;
    END PROCESS;

    data_out <= acc_reg;

END structural;
