library ieee;
use ieee.std_logic_1164.all;

entity imm_gen is
    port (
        -- Vstup: Horních 25 bitů instrukce (spodních 7 bitů je Opcode, ty nepotřebujeme)
        instr    : in  std_logic_vector(31 downto 7);
        
        -- Vstup z Dekodéru: Jaký formát konstanty máme poskládat
        imm_src  : in  std_logic_vector(2 downto 0);
        
        -- Výstup: Krásně poskládaná 32bitová konstanta s rozšířeným znaménkem
        imm_ext  : out std_logic_vector(31 downto 0)
    );
end entity imm_gen;

architecture rtl of imm_gen is
begin
    process(instr, imm_src)
    begin
        case imm_src is
        
            -- ==============================================================
            -- I-Type (Instrukce jako ADDI nebo LW)
            -- Konstanta je v horních 12 bitech (31 až 20)
            -- ==============================================================
            when "000" => 
                -- Vezmeme bity 31 až 20 a naskládáme je dolů.
                -- Znaménkové rozšíření: bit 31 rozkopírujeme do horních 20 bitů výstupu.
                imm_ext <= (31 downto 12 => instr(31)) & instr(31 downto 20);
                
            -- ==============================================================
            -- S-Type (Zápis do paměti: SW)
            -- Konstanta je roztržená: bity 31:25 a bity 11:7
            -- ==============================================================
            when "001" => 
                imm_ext <= (31 downto 12 => instr(31)) & instr(31 downto 25) & instr(11 downto 7);
                
            -- ==============================================================
            -- B-Type (Podmíněné skoky: BEQ, BNE)
            -- Skok je vždy o sudý počet bajtů, takže úplně nultý bit je natvrdo '0'.
            -- Bity jsou opět rozházené.
            -- ==============================================================
            when "010" => 
                imm_ext <= (31 downto 12 => instr(31)) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
                
            -- ==============================================================
            -- J-Type (Nepodmíněné dlouhé skoky: JAL)
            -- ==============================================================
            when "011" => 
                imm_ext <= (31 downto 20 => instr(31)) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
                
            -- ==============================================================
            -- U-Type (Načtení velkých konstant: LUI, AUIPC)
            -- Konstanta zabírá horních 20 bitů instrukce, dolních 12 bitů se plní nulami.
            -- ==============================================================
            when "100" => 
                imm_ext <= instr(31 downto 12) & x"000"; -- x"000" je 12 nul (3x hex nula)
                
            -- Výchozí stav (bezpečnostní pojistka)
            when others => 
                imm_ext <= (others => '0');
                
        end case;
    end process;
end architecture rtl;