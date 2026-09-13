library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Zásadní knihovna pro matematiku!

entity alu is
    port (
        -- Vstupy (operandy)
        src_a     : in  std_logic_vector(31 downto 0);
        src_b     : in  std_logic_vector(31 downto 0);
        
        -- Řídicí signál (řekne ALU, co má zrovna dělat)
        alu_ctrl  : in  std_logic_vector(3 downto 0);
        
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
    begin
        case alu_ctrl is
            when "0000" => -- Sčítání (ADD)
                -- Musíme přetypovat std_logic_vector na unsigned, sečíst a vrátit zpět
                result <= std_logic_vector(unsigned(src_a) + unsigned(src_b));
                
            when "0001" => -- Odčítání (SUB)
                result <= std_logic_vector(unsigned(src_a) - unsigned(src_b));
                
            when "0010" => -- Logický součin (AND)
                result <= src_a and src_b;
                
            when "0011" => -- Logický součet (OR)
                result <= src_a or src_b;
                
            when "0100" => -- Exkluzivní součet (XOR)
                result <= src_a xor src_b;
                
            when "0101" => -- Logický posun vlevo (SLL)
                -- Posouváme src_a. O kolik bitů? To říká spodních 5 bitů src_b.
                result <= std_logic_vector(shift_left(unsigned(src_a), to_integer(unsigned(src_b(4 downto 0)))));
                
            when "0110" => -- Logický posun vpravo (SRL)
                result <= std_logic_vector(shift_right(unsigned(src_a), to_integer(unsigned(src_b(4 downto 0)))));
                
            when "0111" => -- Aritmetický posun vpravo (SRA - zachovává znaménko)
                -- Všimni si, že src_a přetypujeme na SIGNED (znaménkové číslo)
                result <= std_logic_vector(shift_right(signed(src_a), to_integer(unsigned(src_b(4 downto 0)))));
                
            when "1000" => -- Nastav 1, pokud je menší (SLT - signed)
                if signed(src_a) < signed(src_b) then
                    result <= x"00000001"; -- Hexadecimální zápis 32bitové jedničky
                else
                    result <= x"00000000";
                end if;
                
            when "1001" => -- Nastav 1, pokud je menší (SLTU - unsigned)
                if unsigned(src_a) < unsigned(src_b) then
                    result <= x"00000001";
                else
                    result <= x"00000000";
                end if;
                
            when others =>
                result <= (others => '0'); -- Pojistka proti neznámému kódu
        end case;
    end process;

    -- Propojení vnitřního signálu na reálný výstup
    alu_res <= result;
    
    -- Zero flag: Nastaví se na '1', pokud je výsledek přesně 0
    zero_flag <= '1' when result = x"00000000" else '0';

end architecture rtl;