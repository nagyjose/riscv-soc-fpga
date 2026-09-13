library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_ram is
    generic (
        -- ====================================================================
        -- ZDE MĚNÍŠ VELIKOST PAMĚTI (Jedno číslo vládne všem)
        -- ====================================================================
        RAM_SIZE_WORDS : integer := 1024  -- 64 slov = 256 bajtů
    );
    port (
        clk      : in  std_logic;
        
        -- Zápis a čtení z adresy (přichází z fáze MEM procesoru)
        addr     : in  std_logic_vector(31 downto 0);
        wr_data  : in  std_logic_vector(31 downto 0);
        rd_data  : out std_logic_vector(31 downto 0);
        
        -- Povel k zápisu
        wr_en    : in  std_logic_vector(3 downto 0) -- 4bitová maska zápisu
    );
end entity data_ram;

architecture rtl of data_ram is
    -- Automatický výpočet bajtů pro bezpečnostní pojistku
    constant RAM_SIZE_BYTES : integer := RAM_SIZE_WORDS * 4;

    -- Vytvoříme paměť o velikosti 64 slov (64 * 4 = 256 bajtů)
    -- Všechny buňky při startu naplníme nulami
    type ram_type is array (0 to RAM_SIZE_WORDS - 1) of std_logic_vector(31 downto 0);
    signal ram : ram_type := (others => (others => '0'));
	 
	 signal word_addr : integer;
	 
	 -- Vynucení do M4K bloků
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M4K";
begin

    word_addr <= to_integer(unsigned(addr(31 downto 2)));

    -- ========================================================================
    -- SYNCHRONNÍ ZÁPIS I ČTENÍ (Na sestupnou hranu hodin!)
    -- ========================================================================
    process(clk)
    begin
        if falling_edge(clk) then
            -- Bezpečnostní pojistka proti pádu simulátoru
            if unsigned(addr) < RAM_SIZE_BYTES then
                
                -- MASKOVANÝ ZÁPIS: Zapisujeme jen povolené bajty
                if wr_en(0) = '1' then ram(word_addr)(7 downto 0)   <= wr_data(7 downto 0);   end if;
                if wr_en(1) = '1' then ram(word_addr)(15 downto 8)  <= wr_data(15 downto 8);  end if;
                if wr_en(2) = '1' then ram(word_addr)(23 downto 16) <= wr_data(23 downto 16); end if;
                if wr_en(3) = '1' then ram(word_addr)(31 downto 24) <= wr_data(31 downto 24); end if;
                
                -- ČTENÍ
                rd_data <= ram(word_addr);
            else
                -- Adresa mimo rozsah vrací nuly
                rd_data <= (others => '0');
            end if;
        end if;
    end process;

end architecture rtl;