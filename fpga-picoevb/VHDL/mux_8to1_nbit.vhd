LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY mux_8to1_nbit IS
    GENERIC( N : POSITIVE := 16 );
    PORT (I0, I1, I2, I3, I4, I5, I6, I7: IN STD_LOGIC_VECTOR(N-1 downto 0);
          SEL_mux: IN STD_LOGIC_VECTOR(2 downto 0);
          O: OUT STD_LOGIC_VECTOR(N-1 downto 0));
END mux_8to1_nbit;

ARCHITECTURE behaviour OF mux_8to1_nbit IS
    COMPONENT mux_4to1_nbit_base IS GENERIC ( N : POSITIVE); PORT( I0, I1, I2, I3: IN STD_LOGIC_VECTOR(N-1 downto 0); SEL : IN STD_LOGIC_VECTOR(1 downto 0); O : OUT STD_LOGIC_VECTOR(N-1 downto 0)); END COMPONENT;
    COMPONENT mux_2to1_nbit_base IS GENERIC ( N : POSITIVE); PORT( I0, I1: IN STD_LOGIC_VECTOR(N-1 downto 0); SEL : IN STD_LOGIC; O : OUT STD_LOGIC_VECTOR(N-1 downto 0)); END COMPONENT;
    SIGNAL m0_out, m1_out: STD_LOGIC_VECTOR(N-1 downto 0);
BEGIN
    m0: mux_4to1_nbit_base GENERIC MAP(N) PORT MAP(I0, I1, I2, I3, SEL_mux(1 downto 0), m0_out);
    m1: mux_4to1_nbit_base GENERIC MAP(N) PORT MAP(I4, I5, I6, I7, SEL_mux(1 downto 0), m1_out);
    mout: mux_2to1_nbit_base GENERIC MAP(N) PORT MAP(m0_out, m1_out, SEL_mux(2), O);
END behaviour;