library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all; -- Nutné pro funkci hread (čtení hex čísel)

entity inst_rom is
    generic (
        -- Nastavení velikosti a jména souboru
        ROM_SIZE_WORDS : integer := 1024;        -- 1024 slov = 4 KB
        INIT_FILE      : string  := "program.hex" -- Soubor, ze kterého čteme
    );
    port (
        clk        : in  std_logic;
        instr_addr : in  std_logic_vector(31 downto 0);
        instr_data : out std_logic_vector(31 downto 0)
    );
end entity inst_rom;

architecture rtl of inst_rom is

    type rom_type is array (0 to ROM_SIZE_WORDS - 1) of std_logic_vector(31 downto 0);

    -- ========================================================================
    -- FUNKCE PRO NAČTENÍ EXTERNÍHO SOUBORU
    -- ========================================================================
    impure function init_rom(filename : string) return rom_type is
        file     text_file   : text open read_mode is filename;
        variable text_line   : line;
        variable rom_content : rom_type := (others => (others => '0'));
        variable i           : integer := 0;
        variable temp_word   : std_logic_vector(31 downto 0);
    begin
        -- Čteme soubor řádek po řádku, dokud nenarazíme na konec nebo nenaplníme ROM
        while not endfile(text_file) and i < ROM_SIZE_WORDS loop
            readline(text_file, text_line);
            
            -- Ochrana: přeskočíme prázdné řádky
            if text_line.all'length > 0 then
                hread(text_line, temp_word); -- Převede textový HEX na logický vektor
                rom_content(i) := temp_word;
                i := i + 1;
            end if;
        end loop;
        return rom_content;
    end function;

    -- Vytvoření samotné paměti a její naplnění výstupem z naší funkce
    signal rom : rom_type := init_rom(INIT_FILE);
    
    signal word_addr : integer;
    constant ROM_SIZE_BYTES : integer := ROM_SIZE_WORDS * 4;

begin

    -- RISC-V adresuje po bajtech, paměť je po slovech (ignorujeme spodní 2 bity)
    word_addr <= to_integer(unsigned(instr_addr(31 downto 2)));

    -- ========================================================================
    -- ČTENÍ Z PAMĚTI (Na sestupnou hranu, aby byla data včas pro IF fázi)
    -- ========================================================================
    process(clk)
    begin
        if falling_edge(clk) then
            -- Bezpečnostní pojistka proti čtení mimo paměť
            if unsigned(instr_addr) < ROM_SIZE_BYTES then
                instr_data <= rom(word_addr);
            else
                instr_data <= (others => '0'); -- NOP instrukce
            end if;
        end if;
    end process;

end architecture rtl;