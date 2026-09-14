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
    -- Vnitřní signál pro uložení mezivýsledku
    signal result : std_logic_vector(31 downto 0);
begin

    -- Kombinační proces: spustí se KDYKOLIV se změní nějaký vstup
    process(src_a, src_b, alu_ctrl)
        variable shamt    : integer range 0 to 31;
        variable bit_mask : std_logic_vector(31 downto 0);
    begin
        -- Vypočítáme si pomocné proměnné pro bitové operace předem
        shamt    := to_integer(unsigned(src_b(4 downto 0)));
        bit_mask := std_logic_vector(shift_left(to_unsigned(1, 32), shamt));

        case alu_ctrl is
            -- ================================================================
            -- Základní instrukce RV32I
            -- ================================================================
            when "00000" => -- Sčítání (ADD)
                -- Musíme přetypovat std_logic_vector na unsigned, sečíst a vrátit zpět
                result <= std_logic_vector(unsigned(src_a) + unsigned(src_b));
                
            when "00001" => -- Odčítání (SUB)
                result <= std_logic_vector(unsigned(src_a) - unsigned(src_b));
                
            when "00010" => -- Logický součin (AND)
                result <= src_a and src_b;
                
            when "00011" => -- Logický součet (OR)
                result <= src_a or src_b;
                
            when "00100" => -- Exkluzivní součet (XOR)
                result <= src_a xor src_b;
                
            when "00101" => -- Logický posun vlevo (SLL)
                -- Posouváme src_a. O kolik bitů? To říká spodních 5 bitů src_b.
                result <= std_logic_vector(shift_left(unsigned(src_a), to_integer(unsigned(src_b(4 downto 0)))));
                
            when "00110" => -- Logický posun vpravo (SRL)
                result <= std_logic_vector(shift_right(unsigned(src_a), to_integer(unsigned(src_b(4 downto 0)))));
                
            when "00111" => -- Aritmetický posun vpravo (SRA - zachovává znaménko)
                -- Všimni si, že src_a přetypujeme na SIGNED (znaménkové číslo)
                result <= std_logic_vector(shift_right(signed(src_a), to_integer(unsigned(src_b(4 downto 0)))));
                
            when "01000" => -- Nastav 1, pokud je menší (SLT - signed)
                if signed(src_a) < signed(src_b) then
                    result <= x"00000001"; -- Hexadecimální zápis 32bitové jedničky
                else
                    result <= x"00000000";
                end if;
                
            when "01001" => -- Nastav 1, pokud je menší (SLTU - unsigned)
                if unsigned(src_a) < unsigned(src_b) then
                    result <= x"00000001";
                else
                    result <= x"00000000";
                end if;

            -- ================================================================
            -- Rozšířené instrukce (Zbb a Zbs rozšíření)
            -- ================================================================
            when "10000" => result <= src_a and (not src_b); -- ANDN
            when "10001" => result <= src_a or  (not src_b); -- ORN
            when "10010" => result <= src_a xor (not src_b); -- XNOR
            
            when "10011" => -- ROL (Rotate Left)
                if shamt = 0 then result <= src_a;
                else result <= std_logic_vector(shift_left(unsigned(src_a), shamt) or shift_right(unsigned(src_a), 32 - shamt)); end if;
                
            when "10100" => -- ROR (Rotate Right)
                if shamt = 0 then result <= src_a;
                else result <= std_logic_vector(shift_right(unsigned(src_a), shamt) or shift_left(unsigned(src_a), 32 - shamt)); end if;
                
            when "10101" => result <= src_a or bit_mask;         -- BSET
            when "10110" => result <= src_a and (not bit_mask);  -- BCLR
            when "10111" => result <= src_a xor bit_mask;        -- BINV
            
            when "11000" => -- BEXT (Bit Extract: Posuneme bit na pozici 0 a zbytek zamaskujeme)
                result <= std_logic_vector(shift_right(unsigned(src_a), shamt) and x"00000001");
                
            when "11001" => -- REV8 (Byte Reverse)
                result <= src_a(7 downto 0) & src_a(15 downto 8) & src_a(23 downto 16) & src_a(31 downto 24);

            when others =>
                result <= (others => '0'); -- Pojistka proti neznámému kódu
        end case;
    end process;

    -- Propojení vnitřního signálu na reálný výstup
    alu_res <= result;
    
    -- Zero flag: Nastaví se na '1', pokud je výsledek přesně 0
    zero_flag <= '1' when result = x"00000000" else '0';

end architecture rtl;