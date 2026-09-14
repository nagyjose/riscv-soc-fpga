library ieee;
use ieee.std_logic_1164.all;
use work.pkg_riscv.all; -- Importujeme náš balíček s Opcody!

entity control_unit is
    port (
        -- Vstupy (vytažené přímo z 32bitové instrukce)
        opcode    : in  std_logic_vector(6 downto 0);  -- Bity 6:0
        funct3    : in  std_logic_vector(2 downto 0);  -- Bity 14:12
        funct7    : in  std_logic_vector(6 downto 0);  -- Bity 31:25
        funct12   : in  std_logic_vector(11 downto 0); -- Horních 12 bitů pro detekci MRET
        
        -- Výstupy pro Datovou cestu (Main Decoder)
        reg_write : out std_logic;                     -- 1 = Zápis do reg. pole
        imm_src   : out std_logic_vector(2 downto 0);  -- Jak dekódovat konstantu
        alu_src   : out std_logic;                     -- 0 = Registr, 1 = Konstanta
        mem_write : out std_logic;                     -- 1 = Zápis do datové RAM
        res_src   : out std_logic_vector(1 downto 0);  -- Co se zapíše do reg: 00=ALU, 01=RAM, 10=PC+4
        branch    : out std_logic;                     -- 1 = Je to podmíněný skok
        jump      : out std_logic;                     -- 1 = Je to nepodmíněný skok (JAL)
        jalr      : out std_logic;                     -- 1 = Jedná se o skok přes registr (JALR)
        alu_src_a : out std_logic;                     -- 0 = rs1, 1 = PC (pro AUIPC)
        
        -- Výstup pro ALU (ALU Decoder)
        alu_ctrl  : out std_logic_vector(4 downto 0);

        -- Výstupy pro CSR jednotku
        csr_cmd   : out std_logic_vector(1 downto 0);  -- 00=Nic, 01=RW, 10=RS, 11=RC
        is_mret   : out std_logic;                     -- 1 = Návrat z přerušení
        md_req    : out std_logic                      -- 1 = Jde o násobení/dělení (M-Extension)
    );
end entity control_unit;

architecture rtl of control_unit is
    -- Vnitřní signál, kterým si Main Decoder "povídá" s ALU Dekodérem
    signal alu_op : std_logic_vector(1 downto 0);
begin

    -- ========================================================================
    -- 1. HLAVNÍ DEKODÉR (Závisí pouze na OPCODE)
    -- ========================================================================
    process(opcode, funct3, funct7, funct12)
    begin
        -- Výchozí hodnoty (prevence proti nechtěným paměťovým zápisům)
        reg_write <= '0';  imm_src   <= "000"; alu_src   <= '0';  mem_write <= '0';
        res_src   <= "00"; branch    <= '0';   jump      <= '0';  alu_op    <= "00"; 
        jalr      <= '0';  alu_src_a <= '0';   csr_cmd   <= "00"; is_mret   <= '0';
        md_req    <= '0';

        case opcode is
            when OPC_OP => -- R-Type instrukce (např. ADD, SUB, AND)
                reg_write <= '1';
                alu_src   <= '0';   -- ALU bere data z registru B
                -- Rozhodnutí: Běžná ALU vs. Násobička (podle funct7)
                if funct7 = "0000001" then
                    md_req <= '1';  -- Aktivace M-rozšíření
                    alu_op <= "00"; -- Obyčejná ALU ať si třeba sčítá, její výsledek stejně zahodíme
                else
                    alu_op <= "10"; -- Standardní instrukce (ADD, SUB, XOR...)
                end if;
                
            when OPC_OP_IMM => -- I-Type instrukce (např. ADDI, ORI)
                reg_write <= '1';
                imm_src   <= "000"; -- Konstanta formátu I
                alu_src   <= '1';   -- ALU bere data z vygenerované konstanty (Immediate)
                alu_op    <= "10";  -- Rozhodni se podle funct3
                
            when OPC_LOAD => -- Čtení z paměti (LW)
                reg_write <= '1';
                imm_src   <= "000"; -- Adresa se počítá jako Registr + I-konstanta
                alu_src   <= '1';
                res_src   <= "01";  -- Do reg. pole chceme zapsat data z RAM, ne z ALU
                alu_op    <= "00";  -- ALU musí sčítat (počítá adresu v paměti)
                
            when OPC_STORE => -- Zápis do paměti (SW)
                imm_src   <= "001"; -- Konstanta formátu S (je v instrukci roztrhaná)
                alu_src   <= '1';
                mem_write <= '1';   -- POVOLÍME ZÁPIS DO RAM!
                alu_op    <= "00";  -- ALU opět sčítá adresu
                
            when OPC_BRANCH => -- Podmíněný skok (BEQ, BNE)
                imm_src   <= "010"; -- Konstanta formátu B
                alu_src   <= '0';   -- Porovnáváme dva registry
                branch    <= '1';
                alu_op    <= "01";  -- ALU odčítá (komparátor), abychom zjistili rovnost (zero_flag)
				
				when OPC_LUI =>
                reg_write <= '1';
                imm_src   <= "100"; -- U-Type konstanta
                alu_src   <= '1';   -- ALU bere konstantu
                res_src   <= "00";  -- Zapisujeme výsledek z ALU
                alu_op    <= "00";  -- ALU bude sčítat (x0 + imm = imm)
                
            when OPC_AUIPC =>
                reg_write <= '1';
                imm_src   <= "100"; -- U-Type konstanta
                alu_src_a <= '1';   -- ALU bere do vstupu A přímo PC!
                alu_src   <= '1';   -- ALU bere do vstupu B konstantu
                res_src   <= "00";  -- Zapisujeme výsledek z ALU
                alu_op    <= "00";  -- ALU sečte PC + imm
                
            when OPC_JAL =>
                jump      <= '1';
                reg_write <= '1';
                imm_src   <= "011"; -- J-Type konstanta
                res_src   <= "10";  -- Do registru nezapisujeme ALU, ale Návratovou adresu (PC+4)
                
            when OPC_JALR =>
                jump      <= '1';
                jalr      <= '1';
                reg_write <= '1';
                imm_src   <= "000"; -- I-Type konstanta
                alu_op    <= "00";  -- ALU sečte rs1 + imm (výpočet cíle skoku)
                res_src   <= "10";  -- Do registru zapíšeme Návratovou adresu (PC+4)
                
            -- ====================================================================
            -- SYSTÉMOVÉ INSTRUKCE A CSR (Opcode 1110011)
            -- ====================================================================
            when OPC_SYSTEM => 
                if funct3 = "000" then
                    -- Pod-dekódování pro MRET, ECALL, EBREAK (zajímá nás MRET)
                    if funct12 = x"302" then
                        is_mret <= '1';
                    end if;
                else
                    -- Standardní CSR instrukce (CSRRW, CSRRS, CSRRC)
                    reg_write <= '1';  -- Vždy čteme původní stav CSR do našeho rd registru
                    res_src   <= "11"; -- Přikážeme datové cestě: "Ulož do rd data z CSR!"
                    
                    if funct3 = "001" then
                        csr_cmd <= "01"; -- Zápis nového stavu
                    elsif funct3 = "010" then
                        csr_cmd <= "10"; -- Nastavení bitů (Set)
                    elsif funct3 = "011" then
                        csr_cmd <= "11"; -- Nulování bitů (Clear)
                    end if;
                end if;

            when others =>
                -- Ostatní instrukce
                null;
        end case;
    end process;

    -- ========================================================================
    -- 2. ALU DEKODÉR (Závisí na ALU_OP z hlavního dekodéru, funct3 a funct7)
    -- ========================================================================
    process(alu_op, funct3, funct7, opcode)
    begin
        -- Výchozí hodnota pro ALU je sčítání
        alu_ctrl <= "00000"; 
        
        case alu_op is
            when "00" => -- ALU počítá adresy pro Load/Store
                alu_ctrl <= "00000"; -- Sčítání (ADD)
                
            when "01" => -- ALU porovnává pro skoky (Branch)
                alu_ctrl <= "00001"; -- Odčítání (SUB) -> vygeneruje zero_flag
                
            when "10" => -- R-Type nebo I-Type (rozhoduje funct3)
                case funct3 is
                    when "000" => 
                        -- Zde je chyták: U I-Type (ADDI) funct7 neexistuje.
                        -- U R-Type (ADD/SUB) záleží na bitu funct7_b5 (0=ADD, 1=SUB).
                        if opcode = OPC_OP and funct7(5) = '1' then
                            alu_ctrl <= "00001"; -- SUB
                        else
                            alu_ctrl <= "00000"; -- ADD / ADDI
                        end if;
                    
                    when "001" =>
                        if    funct7 = "0110000" then alu_ctrl <= "10011"; -- ROL (Rotate Left)
                        elsif funct7 = "0010100" then alu_ctrl <= "10101"; -- BSET (Bit Set) / BSETI
                        elsif funct7 = "0100100" then alu_ctrl <= "10110"; -- BCLR (Bit Clear) / BCLRI
                        elsif funct7 = "0110100" then alu_ctrl <= "10111"; -- BINV (Bit Invert) / BINVI
                        else                          alu_ctrl <= "00101"; -- SLL (Shift Left Logical)
                        end if;
                    
                    when "010" => alu_ctrl <= "01000"; -- SLT (Set Less Than) / SLTI
                    when "011" => alu_ctrl <= "01001"; -- SLTU / SLTIU
                    
                    when "100" =>
                        if opcode(5) = '1' and funct7 = "0100000" then 
                            alu_ctrl <= "10010"; -- XNOR
                        else
                            alu_ctrl <= "00100"; -- XOR / XORI
                        end if;
                    
                    when "101" => 
                        if    funct7 = "0110000" then alu_ctrl <= "10100"; -- ROR / RORI
                        elsif funct7 = "0100000" then alu_ctrl <= "00111"; -- SRA / SRAI
                        elsif funct7 = "0100100" then alu_ctrl <= "11000"; -- BEXT (Bit Extract) / BEXTI
                        elsif funct7 = "0110100" then alu_ctrl <= "11001"; -- REV8 (Byte Reverse)
                        else                          alu_ctrl <= "00110"; -- SRL / SRLI
                        end if;
                    
                    when "110" => 
                        if opcode(5) = '1' and funct7 = "0100000" then 
                            alu_ctrl <= "10001"; -- ORN (OR NOT)
                        else                       
                            alu_ctrl <= "00011"; -- OR / ORI
                        end if;
                    
                    when "111" => 
                        if opcode(5) = '1' and funct7 = "0100000" then 
                            alu_ctrl <= "10000"; -- ANDN (AND NOT)
                        else
                            alu_ctrl <= "00010"; -- AND / ANDI
                        end if;
                    
                    when others => alu_ctrl <= "00000";
                end case;
                
            when others =>
                alu_ctrl <= "00000";
        end case;
    end process;

end architecture rtl;