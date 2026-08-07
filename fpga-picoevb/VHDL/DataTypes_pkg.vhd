library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package DataTypes_pkg is

    -- =============================================================
    -- 1. 1D Array Type 
    -- =============================================================
    type arr_t is array (0 to 7) of std_logic_vector(15 downto 0);

    -- =============================================================
    -- 2. 2D Array Type for matA, B and C 
    -- =============================================================
    type mat_2d_8_8_t is array (0 to 7, 0 to 7) of std_logic_vector(15 downto 0);
    
    type gelu_out_8cols_8_arr_t_t is array (0 to 7) of arr_t; 

    --type bus_array_t is array (0 to 7) of std_logic_vector(15 downto 0);
    -- =============================================================
    -- 2. Internal LUT Types and Constants
    -- =============================================================
    --type lut_array_t is array (0 to 31) of signed(15 downto 0);

end package DataTypes_pkg;
