library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- synthesis translate_off
use std.textio.all;
use ieee.std_logic_textio.all;
-- synthesis translate_on

entity dual_port_ram is
    generic (
        RAM_SIZE_WORDS : integer := 2048;
        -- 1. ZMĚNA: Pro ModelSim MUSÍME číst surový .hex soubor!
        INIT_FILE      : string  := "program.hex"
    );
    port (
        clk         : in  std_logic;
        addr_a      : in  std_logic_vector(31 downto 0);
        wr_data_a   : in  std_logic_vector(31 downto 0);
        byte_ena_a  : in  std_logic_vector(3 downto 0);
        rd_data_a   : out std_logic_vector(31 downto 0);
        
        addr_b      : in  std_logic_vector(31 downto 0);
        wr_data_b   : in  std_logic_vector(31 downto 0);
        byte_ena_b  : in  std_logic_vector(3 downto 0);
        rd_data_b   : out std_logic_vector(31 downto 0)
    );
end entity dual_port_ram;

architecture rtl of dual_port_ram is
    type ram_type is array (0 to RAM_SIZE_WORDS - 1) of std_logic_vector(31 downto 0);

    -- ========================================================================
    -- FUNKCE POUZE PRO SIMULACI (Quartus tuto funkci vůbec neuvidí)
    -- ========================================================================
    -- synthesis translate_off
    impure function init_ram(filename : string) return ram_type is
        variable ram_content : ram_type := (others => (others => '0'));
        file     text_file   : text open read_mode is filename;
        variable text_line   : line;
        variable temp_word   : std_logic_vector(31 downto 0);
        variable mem_idx     : integer := 0;
    begin
        while not endfile(text_file) and mem_idx < RAM_SIZE_WORDS loop
            readline(text_file, text_line);
            if text_line.all'length > 0 then
                hread(text_line, temp_word);
                ram_content(mem_idx) := temp_word;
                mem_idx := mem_idx + 1;
            end if;
        end loop;
        return ram_content;
    end function;
    -- synthesis translate_on

    -- ========================================================================
    -- DEKLARACE PAMĚTI (Oddělení simulace a syntézy)
    -- ========================================================================
    
    -- A) TOTO VIDÍ JEN MODELSIM: Paměť inicializovaná VHDL funkcí z .hex souboru
    -- synthesis translate_off
    signal ram : ram_type := init_ram(INIT_FILE);
    -- synthesis translate_on
    
    -- B) TOTO VIDÍ JEN QUARTUS: Čistá neinicializovaná paměť (Dokonalá šablona pro M4K)
    -- synthesis read_comments_as_HDL on
    -- signal ram : ram_type;  
    -- attribute ram_init_file : string;
    -- attribute ram_init_file of ram : signal is "program.mif";
    -- attribute ramstyle : string;
    -- attribute ramstyle of ram : signal is "M4K";
	 -- synthesis read_comments_as_HDL off=
    
    signal word_addr_a : integer range 0 to RAM_SIZE_WORDS - 1;
    signal word_addr_b : integer range 0 to RAM_SIZE_WORDS - 1;

begin
    word_addr_a <= to_integer(unsigned(addr_a(12 downto 2)));
    word_addr_b <= to_integer(unsigned(addr_b(12 downto 2)));

    process(clk)
    begin
        if falling_edge(clk) then
            -- PORT A (Symetrický)
            if byte_ena_a(0) = '1' then ram(word_addr_a)(7 downto 0)   <= wr_data_a(7 downto 0);   end if;
            if byte_ena_a(1) = '1' then ram(word_addr_a)(15 downto 8)  <= wr_data_a(15 downto 8);  end if;
            if byte_ena_a(2) = '1' then ram(word_addr_a)(23 downto 16) <= wr_data_a(23 downto 16); end if;
            if byte_ena_a(3) = '1' then ram(word_addr_a)(31 downto 24) <= wr_data_a(31 downto 24); end if;
            rd_data_a <= ram(word_addr_a);
            
            -- PORT B (Symetrický)
            if byte_ena_b(0) = '1' then ram(word_addr_b)(7 downto 0)   <= wr_data_b(7 downto 0);   end if;
            if byte_ena_b(1) = '1' then ram(word_addr_b)(15 downto 8)  <= wr_data_b(15 downto 8);  end if;
            if byte_ena_b(2) = '1' then ram(word_addr_b)(23 downto 16) <= wr_data_b(23 downto 16); end if;
            if byte_ena_b(3) = '1' then ram(word_addr_b)(31 downto 24) <= wr_data_b(31 downto 24); end if;
            rd_data_b <= ram(word_addr_b);
        end if;
    end process;
end architecture rtl;