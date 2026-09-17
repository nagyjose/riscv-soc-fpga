library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_alu is
end entity tb_alu;

architecture sim of tb_alu is

    signal src_a     : std_logic_vector(31 downto 0);
    signal src_b     : std_logic_vector(31 downto 0);
    signal alu_ctrl  : std_logic_vector(4 downto 0);
    
    signal alu_res   : std_logic_vector(31 downto 0);
    signal zero_flag : std_logic;
    
    signal test_done : boolean := false;

begin

    -- Instanciace testované ALU
    u_alu: entity work.alu
        port map (
            src_a     => src_a,
            src_b     => src_b,
            alu_ctrl  => alu_ctrl,
            alu_res   => alu_res,
            zero_flag => zero_flag
        );

    -- Hlavní testovací proces
    stimulus: process
        -- Procedura pro automatické otestování a vyhodnocení jedné instrukce
        procedure verify_op (
            constant op_name : in string;
            constant a       : in std_logic_vector(31 downto 0);
            constant b       : in std_logic_vector(31 downto 0);
            constant ctrl    : in std_logic_vector(4 downto 0);
            constant exp_res : in std_logic_vector(31 downto 0)
        ) is
        begin
            src_a <= a;
            src_b <= b;
            alu_ctrl <= ctrl;
            wait for 10 ns;
            
            if alu_res /= exp_res then
                report LF & "CHYBA v instrukci: " & op_name & LF &
                       "Ocekavano: " & integer'image(to_integer(unsigned(exp_res))) & LF &
                       "Prijato:   " & integer'image(to_integer(unsigned(alu_res)))
                       severity failure;
            end if;
        end procedure;
        
    begin
        -- ====================================================================
        -- 1. ZÁKLADNÍ ARITMETIKA A POROVNÁVÁNÍ (RV32I)
        -- ====================================================================
        -- ADD: 15 + (-5) = 10
        verify_op("ADD", x"0000000F", x"FFFFFFFB", "00000", x"0000000A");
        
        -- SUB: 10 - 20 = -10 (0xFFFFFFF6)
        verify_op("SUB", x"0000000A", x"00000014", "00001", x"FFFFFFF6");
        
        -- SLT (Signed): -5 < 10 -> 1 (Pravda)
        verify_op("SLT", x"FFFFFFFB", x"0000000A", "01000", x"00000001");
        
        -- SLTU (Unsigned): 0xFFFFFFFB (obrovské číslo) < 10 -> 0 (Nepravda)
        verify_op("SLTU", x"FFFFFFFB", x"0000000A", "01001", x"00000000");


        -- ====================================================================
        -- 2. BARREL SHIFTER (RV32I)
        -- ====================================================================
        -- SLL: 0x00000001 << 4 = 0x00000010
        verify_op("SLL", x"00000001", x"00000004", "00101", x"00000010");
        
        -- SRA: 0x80000000 >> 4 = 0xF8000000 (Znaménkový posun)
        verify_op("SRA", x"80000000", x"00000004", "00111", x"F8000000");


        -- ====================================================================
        -- 3. LOGIKA A ROZŠÍŘENÍ Zbb
        -- ====================================================================
        -- ANDN: 0x0000FFFF and (not 0x00FF00FF) = 0x0000FF00
        verify_op("ANDN", x"0000FFFF", x"00FF00FF", "10000", x"0000FF00");
        
        -- XNOR: 0x0000FFFF xor (not 0x00FF00FF) = 0xFF0000FF
        verify_op("XNOR", x"0000FFFF", x"00FF00FF", "10010", x"FF0000FF");
        
        -- ROL: Rotace 0x80000001 o 1 vlevo = 0x00000003
        verify_op("ROL", x"80000001", x"00000001", "10011", x"00000003");
        
        -- ROR: Rotace 0x00000003 o 1 vpravo = 0x80000001
        verify_op("ROR", x"00000003", x"00000001", "10100", x"80000001");
        
        -- REV8: Obrácení endianity z 0x12345678 na 0x78563412
        verify_op("REV8", x"12345678", x"00000000", "11001", x"78563412");


        -- ====================================================================
        -- 4. MANIPULACE S BITY Zbs
        -- ====================================================================
        -- BSET: Nastavení 4. bitu (počítáno od nuly) -> 0x10
        verify_op("BSET", x"00000000", x"00000004", "10101", x"00000010");
        
        -- BCLR: Zhasnutí 4. bitu
        verify_op("BCLR", x"00000010", x"00000004", "10110", x"00000000");
        
        -- BINV: Inverze nultého bitu (z 0 na 1)
        verify_op("BINV", x"00000000", x"00000000", "10111", x"00000001");
        
        -- BEXT: Vytažení 31. bitu z čísla 0x80000000 -> 1
        verify_op("BEXT", x"80000000", x"0000001F", "11000", x"00000001");
        
        
        -- ====================================================================
        -- 5. OSTATNÍ
        -- ====================================================================
        -- PASS_B (Záchrana pro LUI)
        verify_op("PASS_B", x"00000000", x"DEADBEEF", "11111", x"DEADBEEF");

        -- Pokud test dojde až sem, vše je hardwarově správně!
        report LF & "==================================================" & LF &
                    "  [ SUCCESS ] Vsechny instrukce ALU jsou matematicky spravne!" & LF &
                    "==================================================" severity note;
        
        test_done <= true;
        wait;
    end process;

end architecture sim;