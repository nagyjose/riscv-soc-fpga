library ieee;
use ieee.std_logic_1164.all;

entity store_formatter is
    port (
        funct3       : in  std_logic_vector(2 downto 0);  -- Typ instrukce (SB, SH, SW)
        addr_align   : in  std_logic_vector(1 downto 0);  -- Spodní 2 bity adresy
        reg_data     : in  std_logic_vector(31 downto 0); -- Data jdoucí z procesoru
        mem_write    : in  std_logic;                     -- Původní 1bitový signál zápisu
        
        mem_wr_data  : out std_logic_vector(31 downto 0); -- Zformátovaná data pro RAM
        mem_byte_ena : out std_logic_vector(3 downto 0)   -- 4bitová maska pro RAM
    );
end entity store_formatter;

architecture rtl of store_formatter is
begin
    process(funct3, addr_align, reg_data, mem_write)
    begin
        -- Výchozí hodnoty (samé nuly)
        mem_wr_data  <= (others => '0');
        mem_byte_ena <= "0000";

        if mem_write = '1' then
            case funct3 is
                when "000" => -- SB (Store Byte - 8 bitů)
                    case addr_align is
                        when "00" => mem_wr_data(7 downto 0)   <= reg_data(7 downto 0); mem_byte_ena <= "0001";
                        when "01" => mem_wr_data(15 downto 8)  <= reg_data(7 downto 0); mem_byte_ena <= "0010";
                        when "10" => mem_wr_data(23 downto 16) <= reg_data(7 downto 0); mem_byte_ena <= "0100";
                        when "11" => mem_wr_data(31 downto 24) <= reg_data(7 downto 0); mem_byte_ena <= "1000";
                        when others => null;
                    end case;
                    
                when "001" => -- SH (Store Halfword - 16 bitů)
                    case addr_align is
                        when "00" => mem_wr_data(15 downto 0)  <= reg_data(15 downto 0); mem_byte_ena <= "0011";
                        when "10" => mem_wr_data(31 downto 16) <= reg_data(15 downto 0); mem_byte_ena <= "1100";
                        when others => null; -- U SH by adresa 01 a 11 vyvolala v reálném HW výjimku
                    end case;
                    
                when "010" => -- SW (Store Word - 32 bitů)
                    mem_wr_data  <= reg_data;
                    mem_byte_ena <= "1111";
                    
                when others =>
                    null;
            end case;
        end if;
    end process;
end architecture rtl;