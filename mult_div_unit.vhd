library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult_div_unit is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Řídicí signály
        md_req   : in  std_logic;                    -- 1 = Požadavek na výpočet
        funct3   : in  std_logic_vector(2 downto 0); -- Typ operace (MUL, DIV...)
        
        -- Vstupy (Operandy odpojené z ALU)
        src_a    : in  std_logic_vector(31 downto 0);
        src_b    : in  std_logic_vector(31 downto 0);
        
        -- Výstupy
        md_res   : out std_logic_vector(31 downto 0);
        md_ready : out std_logic                     -- 1 = Výsledek je hotový
    );
end entity mult_div_unit;

architecture rtl of mult_div_unit is

    -- ========================================================================
    -- 1. KOMBINAČNÍ NÁSOBIČKA (DSP Bloky)
    -- ========================================================================
    -- Signály pro nafouknutí na 33 bitů a obří 66bitový výsledek
    signal a_ext, b_ext : signed(32 downto 0);
    signal mult_res_66  : signed(65 downto 0);
    signal mult_res_32  : std_logic_vector(31 downto 0);

    -- ========================================================================
    -- 2. SEKVENČNÍ DĚLIČKA (Stavový automat)
    -- ========================================================================
    type state_type is (IDLE, DIVIDE, FINISH);
    signal state : state_type;
    
    signal count       : integer range 0 to 32;
    signal rq_reg      : unsigned(63 downto 0);
    signal divisor_reg : unsigned(31 downto 0);
    
    -- Pomocné registry pro zpracování specifik RISC-V
    signal sign_div    : std_logic; -- Znaménko podílu
    signal sign_rem    : std_logic; -- Znaménko zbytku
    signal is_div_zero : std_logic;
    signal is_overflow : std_logic;
    
    signal div_res_32  : std_logic_vector(31 downto 0);

begin

    -- ========================================================================
    -- ČÁST A: LOGIKA NÁSOBENÍ (Vždy běží na pozadí kombinačně)
    -- ========================================================================
    -- Znaménkové vs Neznaménkové rozšíření na 33 bitů
    process(src_a, src_b, funct3)
    begin
        -- Výchozí stav: Unsigned rozšíření (Přilepíme čistou nulu na pozici 32)
        a_ext <= signed('0' & src_a);
        b_ext <= signed('0' & src_b);
        
        case funct3 is
            when "000" | "001" => -- MUL, MULH (Oba operandy jsou Signed)
                a_ext <= signed(src_a(31) & src_a);
                b_ext <= signed(src_b(31) & src_b);
                
            when "010" =>         -- MULHSU (A je Signed, B je Unsigned)
                a_ext <= signed(src_a(31) & src_a);
                b_ext <= signed('0' & src_b);
                
            when others =>        -- MULHU (Oba operandy jsou Unsigned)
                -- Zůstává výchozí stav s připojenou '0'
                null;
        end case;
    end process;

    -- Samotné násobení (Zde Quartus odvodí M4K DSP bloky)
    mult_res_66 <= a_ext * b_ext;

    mult_res_32 <= std_logic_vector(mult_res_66(31 downto 0)) when funct3 = "000" else
                   std_logic_vector(mult_res_66(63 downto 32));

    -- ========================================================================
    -- ČÁST B: STAVOVÝ AUTOMAT DĚLIČKY
    -- ========================================================================
    process(clk)
        variable a_abs, b_abs : unsigned(31 downto 0);
        variable shifted_rq   : unsigned(63 downto 0);
        variable diff         : unsigned(32 downto 0); -- o bit větší pro kontrolu podtečení
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
            else
                case state is
                    when IDLE =>
                        -- Startujeme pouze pokud je to požadavek na dělení! (funct3 začíná na '1')
                        if md_req = '1' and funct3(2) = '1' then
                            -- 1. Zjištění absolutních hodnot
                            if (funct3 = "100" or funct3 = "110") and src_a(31) = '1' then
                                a_abs := unsigned(-signed(src_a));
                            else
                                a_abs := unsigned(src_a);
                            end if;
                            
                            if (funct3 = "100" or funct3 = "110") and src_b(31) = '1' then
                                b_abs := unsigned(-signed(src_b));
                            else
                                b_abs := unsigned(src_b);
                            end if;

                            -- 2. Příprava registrů
                            rq_reg(63 downto 32) <= (others => '0');
                            rq_reg(31 downto 0)  <= a_abs;
                            divisor_reg          <= b_abs;
                            count                <= 32;
                            
                            -- 3. Zjištění RISC-V extrémů a znamének
                            sign_div <= src_a(31) xor src_b(31);
                            sign_rem <= src_a(31);
                            
                            is_div_zero <= '0';
                            is_overflow <= '0';
                            if src_b = x"00000000" then
                                is_div_zero <= '1';
                            elsif src_a = x"80000000" and src_b = x"FFFFFFFF" then
                                is_overflow <= '1';
                            end if;

                            state <= DIVIDE;
                        end if;

                    when DIVIDE =>
                        if count > 0 then
                            -- Shift vlevo
                            shifted_rq := rq_reg(62 downto 0) & '0';
                            
                            -- Zkusíme odečíst dělitele z horní poloviny (přetypováno na 33b pro prevenci chyb)
                            diff := ('0' & shifted_rq(63 downto 32)) - ('0' & divisor_reg);
                            
                            -- Pokud nedošlo k podtečení (výsledek je >= 0)
                            if diff(32) = '0' then
                                rq_reg(63 downto 32) <= diff(31 downto 0);
                                rq_reg(31 downto 1)  <= shifted_rq(31 downto 1);
                                rq_reg(0)            <= '1'; -- Uspěli jsme, zapisujeme 1
                            else
                                rq_reg <= shifted_rq;        -- Neuspěli jsme, LSB zůstává 0
                            end if;
                            
                            count <= count - 1;
                        else
                            state <= FINISH;
                        end if;

                    when FINISH =>
                        -- Jeden takt na aplikaci znamének a vyřešení výjimek
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- ČÁST C: FINÁLNÍ FORMÁTOVÁNÍ VÝSLEDKU DĚLENÍ A VÝBĚR NA VÝSTUP
    -- ========================================================================
    process(funct3, rq_reg, sign_div, sign_rem, is_div_zero, is_overflow, src_a)
        variable temp_q, temp_r : std_logic_vector(31 downto 0);
    begin
        -- Vytažení surových výsledků z registru a aplikace znamének
        if sign_div = '1' and (funct3 = "100" or funct3 = "110") then 
            temp_q := std_logic_vector(-signed(rq_reg(31 downto 0)));
        else
            temp_q := std_logic_vector(rq_reg(31 downto 0));
        end if;

        if sign_rem = '1' and (funct3 = "100" or funct3 = "110") then
            temp_r := std_logic_vector(-signed(rq_reg(63 downto 32)));
        else
            temp_r := std_logic_vector(rq_reg(63 downto 32));
        end if;

        -- Aplikace RISC-V výjimek (Přetečení a dělení nulou)
        if is_div_zero = '1' then
            temp_q := x"FFFFFFFF"; -- -1
            temp_r := src_a;
        elsif is_overflow = '1' then
            temp_q := x"80000000";
            temp_r := x"00000000";
        end if;

        -- Výběr, co posíláme ven
        if funct3 = "100" or funct3 = "101" then
            div_res_32 <= temp_q; -- DIV, DIVU
        else
            div_res_32 <= temp_r; -- REM, REMU
        end if;
    end process;

    -- ========================================================================
    -- ČÁST D: ŘÍZENÍ VÝSTUPNÍHO MULTIPLEXERU A PIPELINY
    -- ========================================================================
    -- Multiplexer výsledku: Násobení (funct3 začíná na 0), Dělení (funct3 začíná na 1)
    md_res <= mult_res_32 when funct3(2) = '0' else div_res_32;

    -- Řízení času:
    -- Pokud žádáme dělení, procesor MUSÍ čekat, dokud nedojdeme do stavu FINISH.
    -- Pokud žádáme násobení, je to kombinační, hotovo ihned.
    process(md_req, funct3, state)
    begin
        if md_req = '1' then
            if funct3(2) = '1' then
                -- Dělení
                if state = FINISH then
                    md_ready <= '1'; -- Křičíme: "Hotovo, můžete jet dál!"
                else
                    md_ready <= '0'; -- Křičíme: "Stát! Zastavte pipelinu!"
                end if;
            else
                -- Násobení (vždy hotovo ihned)
                md_ready <= '1';
            end if;
        else
            md_ready <= '1'; -- Výchozí stav (procesor může běžet)
        end if;
    end process;

end architecture rtl;