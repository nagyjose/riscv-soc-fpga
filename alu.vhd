library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Zásadní knihovna pro matematiku!

entity alu is
    port (
        -- Vstupy (operandy)
        src_a     : in  std_logic_vector(31 downto 0);
        src_b     : in  std_logic_vector(31 downto 0);
        
        -- Řídicí signál (řekne ALU, co má zrovna dělat)
        alu_ctrl  : in  std_logic_vector(4 downto 0);
        
        -- Výstupy
        alu_res   : out std_logic_vector(31 downto 0);
        zero_flag : out std_logic
    );
end entity alu;

architecture rtl of alu is

    function bit_reverse(v : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable res : std_logic_vector(31 downto 0);
    begin
        for i in 0 to 31 loop
            res(i) := v(31 - i);
        end loop;
        return res;
    end function;

    -- 1. Jednotná Aritmetika (ADD, SUB, SLT, SLTU)
    signal is_sub        : std_logic;
    signal is_signed_cmp : std_logic;
    signal a_ext         : std_logic_vector(32 downto 0);
    signal b_ext         : std_logic_vector(32 downto 0);
    signal b_inv         : std_logic_vector(32 downto 0);
    signal adder_res     : unsigned(32 downto 0);
    signal arith_res     : std_logic_vector(31 downto 0);

    -- 2. Jednotná Logika (AND, OR, XOR, ANDN, ORN, XNOR, BSET, BCLR, BINV)
    signal bit_mask      : std_logic_vector(31 downto 0);
    signal b_logic_raw   : std_logic_vector(31 downto 0);
    signal b_logic       : std_logic_vector(31 downto 0);
    signal invert_b      : std_logic;
    signal logic_res     : std_logic_vector(31 downto 0);

    -- 3. Jednotný 5stupňový Barrel Shifter (SLL, SRL, SRA, ROL, ROR, BEXT)
    signal is_left       : std_logic;
    signal is_rotate     : std_logic;
    signal is_sra        : std_logic;
    signal shift_in      : std_logic_vector(31 downto 0);
    signal high_32       : std_logic_vector(31 downto 0);
    signal ext_shift     : std_logic_vector(63 downto 0);
    signal shamt         : std_logic_vector(4 downto 0);
    signal stg4          : std_logic_vector(47 downto 0);
    signal stg3          : std_logic_vector(39 downto 0);
    signal stg2          : std_logic_vector(35 downto 0);
    signal stg1          : std_logic_vector(33 downto 0);
    signal stg0          : std_logic_vector(31 downto 0);
    signal shifter_res   : std_logic_vector(31 downto 0);
    
    -- 4. Výstupní MUX
    signal out_mux_sel   : std_logic_vector(1 downto 0);
    signal other_res     : std_logic_vector(31 downto 0);

    signal result        : std_logic_vector(31 downto 0);

begin

    -- ========================================================================
    -- 1. SDÍLENÁ ARITMETICKÁ JEDNOTKA (Jediná 33bitová sčítačka)
    -- ========================================================================
    is_sub        <= '1' when (alu_ctrl = "00001" or alu_ctrl = "01000" or alu_ctrl = "01001") else '0';
    is_signed_cmp <= '1' when (alu_ctrl = "01000") else '0';

    a_ext <= (src_a(31) and is_signed_cmp) & src_a;
    b_ext <= (src_b(31) and is_signed_cmp) & src_b;
    b_inv <= not b_ext when is_sub = '1' else b_ext;

    process(a_ext, b_inv, is_sub)
        variable cin : unsigned(32 downto 0);
    begin
        cin := (others => '0');
        cin(0) := is_sub;
        adder_res <= unsigned(a_ext) + unsigned(b_inv) + cin;
    end process;

    arith_res <= (31 downto 1 => '0') & adder_res(32) when (alu_ctrl = "01000" or alu_ctrl = "01001")
                 else std_logic_vector(adder_res(31 downto 0));

    -- ========================================================================
    -- 2. SDÍLENÁ LOGICKÁ JEDNOTKA
    -- ========================================================================
    process(src_b)
        variable idx : integer range 0 to 31;
    begin
        idx := to_integer(unsigned(src_b(4 downto 0)));
        bit_mask <= (others => '0');
        bit_mask(idx) <= '1';
    end process;

    b_logic_raw <= bit_mask when (alu_ctrl = "10101" or alu_ctrl = "10110" or alu_ctrl = "10111") else src_b;
    invert_b    <= '1' when (alu_ctrl = "10000" or alu_ctrl = "10001" or alu_ctrl = "10010" or alu_ctrl = "10110") else '0';
    b_logic     <= not b_logic_raw when invert_b = '1' else b_logic_raw;

    process(src_a, b_logic, alu_ctrl)
    begin
        if (alu_ctrl = "00010" or alu_ctrl = "10000" or alu_ctrl = "10110") then
            logic_res <= src_a and b_logic;
        elsif (alu_ctrl = "00011" or alu_ctrl = "10001" or alu_ctrl = "10101") then
            logic_res <= src_a or b_logic;
        else
            logic_res <= src_a xor b_logic;
        end if;
    end process;

    -- ========================================================================
    -- 3. JEDNOTNÝ 5STUPŇOVÝ BARREL SHIFTER (Pravý posuvník se zrcadlením)
    -- ========================================================================
    is_left   <= '1' when (alu_ctrl = "00101" or alu_ctrl = "10011") else '0';
    is_rotate <= '1' when (alu_ctrl = "10011" or alu_ctrl = "10100") else '0';
    is_sra    <= '1' when (alu_ctrl = "00111") else '0';

    shift_in <= bit_reverse(src_a) when is_left = '1' else src_a;

    high_32 <= shift_in                 when is_rotate = '1' else
               (others => shift_in(31)) when is_sra = '1' else
               (others => '0');

    ext_shift <= high_32 & shift_in;
    shamt     <= src_b(4 downto 0);

    -- 5 diskrétních multiplexních stupňů
    stg4 <= ext_shift(63 downto 16) when shamt(4) = '1' else ext_shift(47 downto 0);
    stg3 <= stg4(47 downto 8)       when shamt(3) = '1' else stg4(39 downto 0);
    stg2 <= stg3(39 downto 4)       when shamt(2) = '1' else stg3(35 downto 0);
    stg1 <= stg2(35 downto 2)       when shamt(1) = '1' else stg2(33 downto 0);
    stg0 <= stg1(32 downto 1)       when shamt(0) = '1' else stg1(31 downto 0);

    shifter_res <= bit_reverse(stg0)               when is_left = '1' else
                   ((31 downto 1 => '0') & stg0(0)) when alu_ctrl = "11000" else
                   stg0;

	-- ========================================================================
	-- 4. HIERARCHICKÝ VÝSTUPNÍ MULTIPLEXER (Optimalizace pro 4-LUT)
	-- ========================================================================
	-- Dekódování kategorie instrukce do pouhých 2 bitů
	out_mux_sel <= 
        "00" when (alu_ctrl = "00000" or alu_ctrl = "00001" or alu_ctrl = "01000" or alu_ctrl = "01001") else
        "01" when (alu_ctrl = "00101" or alu_ctrl = "00110" or alu_ctrl = "00111" or alu_ctrl = "10011" or alu_ctrl = "10100" or alu_ctrl = "11000") else
        "10" when (alu_ctrl = "11001" or alu_ctrl = "11111") else
        "11"; -- Logické operace
	
    -- Sdílený blok pro REV8 a PASS_B
    other_res <= (src_a(7 downto 0) & src_a(15 downto 8) & src_a(23 downto 16) & src_a(31 downto 24)) when alu_ctrl = "11001" else src_b;
    
    -- Finální 4-to-1 hardwarový MUX
    with out_mux_sel select result <=
        arith_res   when "00",
        shifter_res when "01",
        other_res   when "10",
        logic_res   when others;   

    alu_res   <= result;
    zero_flag <= '1' when result = x"00000000" else '0';

end architecture rtl;