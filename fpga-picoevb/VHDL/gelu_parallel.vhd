library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--use work.gelu_pkg.ALL; 
use work.DataTypes_pkg.ALL; 

entity gelu_ispa_epss_parallel is
    Port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        
        -- Parallel I/O: Array of 16-bit values (defined in gelu_pkg)
        data_in  : in  arr_t; 
        data_out : out arr_t
    );
end gelu_ispa_epss_parallel;

architecture Behavioral of gelu_ispa_epss_parallel is

    -- Declare the Single Core EPSS GeLU component
    component gelu_ispa_epss
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            x_in     : in  std_logic_vector(15 downto 0); 
            gelu_res : out std_logic_vector(15 downto 0)  
        );
    end component;

    -- Signal to convert active-low top reset to active-high internal reset
    signal rst_high : std_logic;

begin

    -- Invert reset for the instantiated modules
    rst_high <= not rst_n;

    -- Generate 8 Parallel Cores (matches your previous testbench scale)
    -- Note: You can change "0 to 7" to "data_in'range" if your package supports dynamic array sizing
    gen_gelu_cores: for i in 0 to 7 generate
    begin
        inst_gelu_epss: gelu_ispa_epss
            port map (
                clk      => clk,
                rst      => rst_high,
                x_in     => data_in(i),
                gelu_res => data_out(i)
            );
    end generate;

end Behavioral;
