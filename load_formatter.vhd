library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity load_formatter is
    port (
        funct3     : in  std_logic_vector(2 downto 0);  -- Typ instrukce (LB, LH, LW, LBU, LHU)
        addr_align : in  std_logic_vector(1 downto 0);  -- Spodní 2 bity adresy
        mem_data   : in  std_logic_vector(31 downto 0); -- Surová data přečtená z RAM
        
        rd_data    : out std_logic_vector(31 downto 0)  -- Finální data jdoucí do registru
    );
end entity load_formatter;

architecture rtl of load_formatter is
    signal b_data : std_logic_vector(7 downto 0);  -- Vyříznutý bajt
    signal h_data : std_logic_vector(15 downto 0); -- Vyříznuté půlslovo
begin

    -- 1. Výřez správného bajtu (záleží na 2 spodních bitech adresy)
    b_data <= mem_data(7 downto 0)   when addr_align = "00" else
              mem_data(15 downto 8)  when addr_align = "01" else
              mem_data(23 downto 16) when addr_align = "10" else
              mem_data(31 downto 24);

    -- 2. Výřez správného půlslova (záleží jen na 1. bitu adresy)
    h_data <= mem_data(15 downto 0)  when addr_align(1) = '0' else
              mem_data(31 downto 16);

    -- 3. Finální formátování (Znaménkové nebo nulové rozšíření na 32 bitů)
    process(funct3, b_data, h_data, mem_data)
    begin
        case funct3 is
            when "000" => -- LB (Load Byte - Signed)
                -- Bezpečné rozšíření pomocí standardní knihovny
                rd_data <= std_logic_vector(resize(signed(b_data), 32));
                
            when "100" => -- LBU (Load Byte - Unsigned)
                rd_data <= std_logic_vector(resize(unsigned(b_data), 32));
                
            when "001" => -- LH (Load Halfword - Signed)
                rd_data <= std_logic_vector(resize(signed(h_data), 32));
                
            when "101" => -- LHU (Load Halfword - Unsigned)
                rd_data <= std_logic_vector(resize(unsigned(h_data), 32));
                
            when "010" => -- LW (Load Word)
                rd_data <= mem_data;
                
            when others =>
                rd_data <= mem_data;
        end case;
    end process;
end architecture rtl;