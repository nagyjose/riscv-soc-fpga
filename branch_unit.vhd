library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity branch_unit is
    port (
        a        : in  std_logic_vector(31 downto 0);
        b        : in  std_logic_vector(31 downto 0);
        funct3   : in  std_logic_vector(2 downto 0); -- Říká nám, jaký typ skoku to je
        branch   : in  std_logic;                    -- 1 = Je to podmíněný skok
        jump     : in  std_logic;                    -- 1 = Je to nepodmíněný skok
        
        pc_src   : out std_logic                     -- Výstup naší výhybky pro PC
    );
end entity branch_unit;

architecture rtl of branch_unit is
begin
    process(a, b, funct3, branch, jump)
        -- Pomocné proměnné pro přehlednost VHDL kódu
        variable is_equal         : boolean;
        variable is_less_signed   : boolean;
        variable is_less_unsigned : boolean;
    begin
        -- Vypočítáme si všechny stavy
        is_equal         := (a = b);
        is_less_signed   := (signed(a) < signed(b));
        is_less_unsigned := (unsigned(a) < unsigned(b));

        -- Výchozí stav (neskáčeme)
        pc_src <= '0';

        -- Nepodmíněný skok (JAL, JALR)
        if jump = '1' then
            pc_src <= '1';
        
        -- Podmíněné skoky (Branch)
        elsif branch = '1' then
            case funct3 is
                when "000" => -- BEQ (Equal)
                    if is_equal then pc_src <= '1'; end if;
                when "001" => -- BNE (Not Equal)
                    if not is_equal then pc_src <= '1'; end if;
                when "100" => -- BLT (Less Than, Signed)
                    if is_less_signed then pc_src <= '1'; end if;
                when "101" => -- BGE (Greater or Equal, Signed)
                    if not is_less_signed then pc_src <= '1'; end if;
                when "110" => -- BLTU (Less Than, Unsigned)
                    if is_less_unsigned then pc_src <= '1'; end if;
                when "111" => -- BGEU (Greater or Equal, Unsigned)
                    if not is_less_unsigned then pc_src <= '1'; end if;
                when others =>
                    pc_src <= '0';
            end case;
        end if;
    end process;
end architecture rtl;