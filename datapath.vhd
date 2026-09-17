library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_riscv.all;

entity datapath is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic; -- Reset (aktivní v 1)
        
        -- Rozhraní pro Instrukční paměť (ROM) - Fáze IF
        instr_addr   : out std_logic_vector(31 downto 0);
        instr_data   : in  std_logic_vector(31 downto 0);
        
        -- Rozhraní pro Datovou paměť (RAM) - Fáze MEM
        mem_addr     : out std_logic_vector(31 downto 0);
        mem_wr_data  : out std_logic_vector(31 downto 0);
        mem_rd_data  : in  std_logic_vector(31 downto 0);
        mem_byte_ena : out std_logic_vector(3 downto 0);

        irq_ext_in   : in  std_logic;
        irq_timer_in : in  std_logic  -- Vstup pro MTIME přerušení
    );
end entity datapath;

architecture rtl of datapath is

    -- ========================================================================
    -- DEFINICE TYPŮ PRO PIPELINE REGISTRY (Jako 'struct' v C)
    -- ========================================================================
    
    -- 1. Fáze IF/ID (Mezi čtením instrukce a dekódováním)
    type if_id_reg_t is record
        pc         : std_logic_vector(31 downto 0);
        pc_plus_4  : std_logic_vector(31 downto 0);
        instr      : std_logic_vector(31 downto 0);
    end record;

    -- 2. Fáze ID/EX (Mezi dekodérem a ALU)
    type id_ex_reg_t is record
        pc         : std_logic_vector(31 downto 0);
        pc_plus_4  : std_logic_vector(31 downto 0);
        funct3     : std_logic_vector(2 downto 0);
        reg_data1  : std_logic_vector(31 downto 0);
        reg_data2  : std_logic_vector(31 downto 0);
        imm        : std_logic_vector(31 downto 0);
        rs1_addr   : std_logic_vector(4 downto 0); -- Adresy registrů si musíme pamatovat
        rs2_addr   : std_logic_vector(4 downto 0);
        rd_addr    : std_logic_vector(4 downto 0); -- Cílový registr
        -- Řídicí signály, které musí cestovat dál s instrukcí
        reg_write  : std_logic;
        res_src    : std_logic_vector(1 downto 0);
        mem_write  : std_logic;
        alu_ctrl   : std_logic_vector(4 downto 0);
        alu_src    : std_logic;
        branch     : std_logic;
        jump       : std_logic;
        jalr       : std_logic;                    
        alu_src_a  : std_logic;  
        csr_cmd    : std_logic_vector(1 downto 0);
        is_mret    : std_logic; 
        md_req     : std_logic;                 
    end record;

    -- 3. Fáze EX/MEM (Mezi ALU a Datovou RAM)
    type ex_mem_reg_t is record
        alu_res    : std_logic_vector(31 downto 0);
        wr_data    : std_logic_vector(31 downto 0); -- Data pro uložení do RAM
        rd_addr    : std_logic_vector(4 downto 0);  -- Cílový registr stále cestuje!
        csr_rdata  : std_logic_vector(31 downto 0);
        -- Řídicí signály
        reg_write  : std_logic;
        res_src    : std_logic_vector(1 downto 0);
        mem_write  : std_logic;
        pc_plus_4  : std_logic_vector(31 downto 0); -- Návratová adresa pro JAL/JALR
        funct3     : std_logic_vector(2 downto 0);  -- Přenos typu (B/H/W)
    end record;

    -- 4. Fáze MEM/WB (Mezi Datovou RAM a zápisem zpět do registrů)
    type mem_wb_reg_t is record
        alu_res    : std_logic_vector(31 downto 0);
        mem_data   : std_logic_vector(31 downto 0);
        rd_addr    : std_logic_vector(4 downto 0);
        csr_rdata  : std_logic_vector(31 downto 0);
        -- Řídicí signály
        reg_write  : std_logic;
        res_src    : std_logic_vector(1 downto 0);
        pc_plus_4  : std_logic_vector(31 downto 0);  
    end record;

    -- ========================================================================
    -- Vytvoření samotných signálů z našich typů (Toto jsou ty fyzické klopné obvody)
    -- ========================================================================
    signal if_id  : if_id_reg_t;
    signal id_ex  : id_ex_reg_t;
    signal ex_mem : ex_mem_reg_t;
    signal mem_wb : mem_wb_reg_t;

    -- Sem ještě přidáme vnitřní dráty pro propojování
    signal pc_current : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_next    : std_logic_vector(31 downto 0);

    -- ========================================================================
    -- Vnitřní propojovací signály (drátování mezi krabičkami)
    -- ========================================================================
    -- Signály z Dekodéru ve fázi ID
    signal id_reg_write : std_logic;
    signal id_imm_src   : std_logic_vector(2 downto 0);
    signal id_alu_src   : std_logic;
    signal id_mem_write : std_logic;
    signal id_res_src   : std_logic_vector(1 downto 0);
    signal id_branch    : std_logic;
    signal id_jump      : std_logic;
    signal id_jalr      : std_logic;
    signal id_alu_src_a : std_logic;
    signal id_alu_ctrl  : std_logic_vector(4 downto 0);
    signal id_imm_ext   : std_logic_vector(31 downto 0);
    signal id_rd_data1  : std_logic_vector(31 downto 0);
    signal id_rd_data2  : std_logic_vector(31 downto 0);
    signal id_csr_cmd   : std_logic_vector(1 downto 0);
    signal id_is_mret   : std_logic;
    signal id_md_req    : std_logic;
    
    -- Vstupy pro ALU ve fázi EX
    signal ex_alu_src_a : std_logic_vector(31 downto 0);
    signal ex_alu_src_b : std_logic_vector(31 downto 0);
    signal ex_alu_res   : std_logic_vector(31 downto 0);

    -- Multiplexery pro zkratky (Co se reálně vypočítalo v dané fázi)
    signal wb_result    : std_logic_vector(31 downto 0);
    signal mem_result   : std_logic_vector(31 downto 0);

    -- Signály pro výpočet adresy další instrukce
    signal pc_plus_4 : std_logic_vector(31 downto 0);
    signal pc_target : std_logic_vector(31 downto 0);
    signal pc_src    : std_logic; -- Výhybka: 0 = PC+4, 1 = Skok

    -- Signály pro CSR jednotku a obsluhu přerušení
    signal ex_csr_rdata : std_logic_vector(31 downto 0);
    signal epc_out      : std_logic_vector(31 downto 0);
    signal trap_target  : std_logic_vector(31 downto 0);
    signal trap_fire    : std_logic;

    -- ========================================================================
    -- Signály pro Hazard Unit (Řešení kolizí a skoků)
    -- ========================================================================
    signal forward_a    : std_logic_vector(1 downto 0);
    signal forward_b    : std_logic_vector(1 downto 0);
    signal flush_if_id  : std_logic;
    signal flush_id_ex  : std_logic;
    signal flush_ex_mem : std_logic;

    signal stall_pc	    : std_logic;
    signal stall_if_id  : std_logic;
    signal stall_id_ex  : std_logic;
    
    -- Mezisignály pro vstupy do ALU (po aplikování zkratky)
    signal alu_src_a_fw : std_logic_vector(31 downto 0);
    signal alu_src_b_fw : std_logic_vector(31 downto 0);

    -- Signál pro upravená data načtená z RAM
    signal mem_rd_data_fmt : std_logic_vector(31 downto 0);

    -- Signály pro M-rozšíření
    signal md_res       : std_logic_vector(31 downto 0);
    signal md_ready     : std_logic;
    signal ex_result    : std_logic_vector(31 downto 0); -- Výsledek, co reálně opouští EX

begin

    -- ========================================================================
    -- PROPOJENÍ S VNĚJŠÍM SVĚTEM (Paměti)
    -- ========================================================================
    
    -- Posíláme data ven z procesoru
    instr_addr  <= pc_current;
    mem_addr    <= ex_mem.alu_res;

    -- ========================================================================
    -- A. INSTANTIACE KOMPONENT (FÁZE DECODE - ID)
    -- ========================================================================

    -- 1. Řídicí jednotka (Dekodér)
    -- Dívá se na instrukci, která je aktuálně v záchytném registru IF/ID
    u_control_unit: entity work.control_unit
        port map (
            opcode    => if_id.instr(6 downto 0),
            funct3    => if_id.instr(14 downto 12),
            funct7    => if_id.instr(31 downto 25),
            funct12   => if_id.instr(31 downto 20),
            
            reg_write => id_reg_write,
            imm_src   => id_imm_src,
            alu_src   => id_alu_src,
            mem_write => id_mem_write,
            res_src   => id_res_src,
            branch    => id_branch,
            jump      => id_jump,
            jalr      => id_jalr,      
            alu_src_a => id_alu_src_a,
            alu_ctrl  => id_alu_ctrl,
            csr_cmd   => id_csr_cmd, 
            is_mret   => id_is_mret,
            md_req    => id_md_req
        );

    -- 2. Generátor konstant
    u_imm_gen: entity work.imm_gen
        port map (
            instr    => if_id.instr(31 downto 7),
            imm_src  => id_imm_src,
            imm_ext  => id_imm_ext
        );

    -- 3. Registrové pole
    -- Čte data z registrů na základě adres RS1 (19:15) a RS2 (24:20).
    -- Zápis (Write-Back) se ale řídí signály z ÚPLNĚ POSLEDNÍ fáze pipeline (mem_wb)!
    u_reg_file: entity work.reg_file
        port map (
            clk      => clk,
            rd_addr1 => if_id.instr(19 downto 15),
            rd_data1 => id_rd_data1,
            
            rd_addr2 => if_id.instr(24 downto 20),
            rd_data2 => id_rd_data2,
            
            wr_en    => mem_wb.reg_write,  -- Povolení k zápisu z konce pipeline
            wr_addr  => mem_wb.rd_addr,    -- Cílová adresa z konce pipeline
            wr_data  => wb_result          -- Výsledek k zapsání
        );

    -- ========================================================================
    -- B. HAZARD UNIT A ZKRATKY (FORWARDING) PRO ALU (FÁZE EXECUTE - EX)
    -- ========================================================================
    u_hazard_unit: entity work.hazard_unit
        port map (
            rs1_addr_ex  => id_ex.rs1_addr,
            rs2_addr_ex  => id_ex.rs2_addr,
            rd_addr_mem  => ex_mem.rd_addr,
            reg_wr_mem   => ex_mem.reg_write,
            rd_addr_wb   => mem_wb.rd_addr,
            reg_wr_wb    => mem_wb.reg_write,
            
            rs1_addr_id  => if_id.instr(19 downto 15),
            rs2_addr_id  => if_id.instr(24 downto 20),
            rd_addr_ex   => id_ex.rd_addr,
            res_src_ex   => id_ex.res_src,
            
            pc_src       => pc_src,
            
            forward_a    => forward_a,
            forward_b    => forward_b,
            stall_pc     => stall_pc,
            stall_if_id  => stall_if_id,
            stall_id_ex  => stall_id_ex,
            flush_if_id  => flush_if_id,
            flush_id_ex  => flush_id_ex,
            flush_ex_mem => flush_ex_mem,
            md_ready     => md_ready
        );

    -- 0. Zjištění skutečného výsledku z fáze MEM (pro zkratky)
    -- Poznámka: res_src="01" (Load z RAM) tu není, protože paměť má vždy Load-Use stall (1 takt)                                 
    with ex_mem.res_src select mem_result <=  
        ex_mem.pc_plus_4 when "10",   -- Návratová adresa JAL
        ex_mem.csr_rdata when "11",   -- Přečtená data z CSR
        ex_mem.alu_res   when others; -- Běžný výpočet

    -- 1. Zkratka pro Operand A                       
    with forward_a select alu_src_a_fw <=
        mem_result      when "10",   -- Zkratka z fáze MEM
        wb_result       when "01",   -- Zkratka z fáze WB
        id_ex.reg_data1 when others; -- Normální čtení z registru

    -- 2. Zkratka pro Operand B (před rozhodnutím o konstantě)
    with forward_b select alu_src_b_fw <=
        mem_result      when "10",
        wb_result       when "01",
        id_ex.reg_data2 when others;

    -- 3. Multiplexer před ALU: Registr vs. Konstanta
    ex_alu_src_a <= id_ex.pc  when id_ex.alu_src_a = '1' else alu_src_a_fw;
    ex_alu_src_b <= id_ex.imm when id_ex.alu_src   = '1' else alu_src_b_fw;


    -- 4. ALU (Aritmeticko-logická jednotka)
    -- Bere data výhradně z pipeline registru ID/EX
    u_alu: entity work.alu
        port map (
            src_a     => ex_alu_src_a,
            src_b     => ex_alu_src_b,
            alu_ctrl  => id_ex.alu_ctrl,
            alu_res   => ex_alu_res,
            zero_flag => open
        );

    -- 5. Vyhodnocování skoků (Branch Unit)
    u_branch_unit: entity work.branch_unit
        port map (
            a        => alu_src_a_fw,   -- Chráněno proti hazardům
            b        => alu_src_b_fw,   -- Pozor: Musí to být čistý registr, ne konstanta z ALU!
            funct3   => id_ex.funct3,
            branch   => id_ex.branch,
            jump     => id_ex.jump,
            pc_src   => pc_src
        );

    -- 6. M-rozšíření (Násobička/dělička)
    u_mult_div: entity work.mult_div_unit
        port map (
            clk      => clk,
            rst      => rst,
            md_req   => id_ex.md_req,     -- Ten nový signál z dekodéru
            funct3   => id_ex.funct3,
            src_a    => ex_alu_src_a,     -- Ošetřeno forwardováním!
            src_b    => ex_alu_src_b,
            md_res   => md_res,
            md_ready => md_ready
        );

    -- 7. Multiplexer na konci fáze EX: Standardní ALU vs. Násobička/Dělička
    ex_result <= md_res when id_ex.md_req = '1' else ex_alu_res;

    -- ========================================================================
    -- JEDNOTKA ŘÍDICÍCH REGISTRŮ (CSR Unit) - Fáze EX
    -- ========================================================================
    u_csr_unit: entity work.csr_unit
        port map (
            clk         => clk,
            rst         => rst,
            
            -- Adresa CSR je horních 12 bitů, což náš I-Type dekodér vyhazuje jako konstantu!
            csr_addr    => id_ex.imm(11 downto 0), 
            csr_wdata   => alu_src_a_fw,           -- Data pro zápis s ošetřeným hazardem
            csr_cmd     => id_ex.csr_cmd,
            csr_rdata   => ex_csr_rdata,
            
            pc_in       => id_ex.pc,               -- Aktuální PC (kdyby přišlo přerušení)
            irq_ext     => irq_ext_in,             -- IRQ pro GPIO/Timer
            irq_timer   => irq_timer_in,           -- Signál pro Trap Kód 7
            is_mret     => id_ex.is_mret,
            
            epc_out     => epc_out,
            trap_target => trap_target,
            trap_fire   => trap_fire
        );

    -- ========================================================================
    -- C. KOMPONENTY - FÁZE MEMORY (MEM) - NOVÉ FORMÁTOVAČE
    -- ========================================================================
    u_store_formatter: entity work.store_formatter
        port map (
            funct3       => ex_mem.funct3,
            addr_align   => ex_mem.alu_res(1 downto 0),
            reg_data     => ex_mem.wr_data,
            mem_write    => ex_mem.mem_write,
            mem_wr_data  => mem_wr_data,      -- Jde ven z procesoru do RAM
            mem_byte_ena => mem_byte_ena      -- Jde ven z procesoru do RAM
        );

    u_load_formatter: entity work.load_formatter
        port map (
            funct3     => ex_mem.funct3,     
            addr_align => ex_mem.alu_res(1 downto 0),
            mem_data   => mem_rd_data,        -- Surová data rovnou z RAM (nyní jsou platná!)
            rd_data    => mem_rd_data_fmt     -- Zformátovaný výsledek
        );

    -- ========================================================================
    -- D. WRITE-BACK MULTIPLEXER (Co se zapíše zpět do registru?)
    -- ========================================================================
    with mem_wb.res_src select wb_result <=
        mem_wb.mem_data  when "01",
        mem_wb.pc_plus_4 when "10", -- Návratová adresa JAL
        mem_wb.csr_rdata when "11", -- Data z CSR
        mem_wb.alu_res   when others;

    -- ========================================================================
    -- E. LOGIKA PROGRAM COUNTERU (PC) A SKOKŮ
    -- ========================================================================
    
    -- 1. Normální krok: PC + 4
    -- Adresu posouváme vždy z aktuální hodnoty PC
    pc_plus_4 <= std_logic_vector(unsigned(pc_current) + 4);

    -- 2. Cílová adresa pro skok
    -- Počítá se ve fázi EX: Instrukce, která skok vyvolala, leží v registru id_ex.
    -- K její adrese (id_ex.pc) přičteme rozbalenou konstantu (id_ex.imm).
    pc_target <= std_logic_vector(unsigned(id_ex.pc) + unsigned(id_ex.imm));

    -- 3. Hlavní multiplexer pro další instrukci
    -- Zde se určuje definitivní hodnota pro pc_next.
    -- U JALR je cílem vypočtená adresa z ALU se smazaným nultým bitem.
    -- Ostatní skoky (JAL, Branch) používají normální pc_target.
    -- Trap a MRET mají absolutní prioritu nad čímkoliv jiným!
    process(trap_fire, trap_target, id_ex.is_mret, epc_out, id_ex.jalr, ex_alu_res, pc_src, pc_target, pc_plus_4)
    begin
        if trap_fire = '1' then
            pc_next <= trap_target;
        elsif id_ex.is_mret = '1' then
            pc_next <= epc_out;
        elsif id_ex.jalr = '1' then
            pc_next <= ex_alu_res(31 downto 1) & '0';
        elsif pc_src = '1' then
            pc_next <= pc_target;
        else
            pc_next <= pc_plus_4;
        end if;
    end process;


    -- ========================================================================
    -- F. HLAVNÍ HODINOVÝ PROCES (Tlukot srdce procesoru)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset smaže úplně celou pipeline a nastaví PC na 0
                pc_current <= (others => '0');
                
                -- Vynulujeme řídicí signály, aby se nic nezapisovalo
                id_ex.reg_write  <= '0'; id_ex.mem_write  <= '0';
                id_ex.branch     <= '0'; id_ex.jump       <= '0';
                id_ex.jalr 	     <= '0'; id_ex.csr_cmd    <= "00";
                id_ex.is_mret    <= '0'; ex_mem.reg_write <= '0'; 
                ex_mem.mem_write <= '0'; mem_wb.reg_write <= '0';
            else
                -- ==========================================================
                -- 1. Posun Program Counteru(pouze pokud nebrzdíme)
                -- ==========================================================
                if stall_pc = '0' then
                    pc_current <= pc_next;
                end if;

                -- ==========================================================
                -- 2. PŘEKLOPENÍ DO FÁZE IF/ID (S možností výmazu)
                -- ==========================================================
                if (flush_if_id = '1') or (trap_fire = '1') or (id_ex.is_mret = '1') then
                    if_id.instr     <= (others => '0'); -- NOP instrukce
                    if_id.pc        <= (others => '0');
                    if_id.pc_plus_4 <= (others => '0');
                elsif stall_if_id = '0' then -- Zápis pouze pokud nebrzdíme 
                    if_id.instr     <= instr_data;
                    if_id.pc        <= pc_current;
                    if_id.pc_plus_4 <= pc_plus_4;
                end if;

                -- ==========================================================
                -- 3. PŘEKLOPENÍ DO FÁZE ID/EX (S možností výmazu)
                -- ==========================================================
                if (flush_id_ex = '1') or (trap_fire = '1') or (id_ex.is_mret = '1') then
                    -- Zabijeme řídicí signály, data můžou zůstat jaká chtějí, nic se nestane
                    id_ex.reg_write <= '0';
                    id_ex.mem_write <= '0';
                    id_ex.branch    <= '0';
                    id_ex.jump      <= '0';
                    id_ex.res_src   <= "00";
                    id_ex.rd_addr   <= "00000";
                    id_ex.csr_cmd   <= "00";
                    id_ex.is_mret   <= '0';
                    id_ex.md_req    <= '0';
                elsif stall_id_ex = '0' then
                    -- Komplexní překlopení dat a řídicích signálů
                    id_ex.pc         <= if_id.pc;
                    id_ex.funct3     <= if_id.instr(14 downto 12);
                    id_ex.reg_data1  <= id_rd_data1;
                    id_ex.reg_data2  <= id_rd_data2;
                    id_ex.imm        <= id_imm_ext;
                    id_ex.rs1_addr   <= if_id.instr(19 downto 15);
                    id_ex.rs2_addr   <= if_id.instr(24 downto 20);
                    id_ex.rd_addr    <= if_id.instr(11 downto 7);
                    id_ex.csr_cmd    <= id_csr_cmd;
                    id_ex.is_mret    <= id_is_mret;
                    
                    id_ex.reg_write  <= id_reg_write;
                    id_ex.res_src    <= id_res_src;
                    id_ex.mem_write  <= id_mem_write;
                    id_ex.branch     <= id_branch;
                    id_ex.jump       <= id_jump;
                    id_ex.jalr       <= id_jalr;
                    id_ex.alu_src_a  <= id_alu_src_a;
                    id_ex.alu_ctrl   <= id_alu_ctrl;
                    id_ex.alu_src    <= id_alu_src;
                    id_ex.md_req     <= id_md_req;
                end if;

                -- ==========================================================
                -- 4. FÁZE EX/MEM
                -- ==========================================================
                if flush_ex_mem = '1' then
                    ex_mem.reg_write <= '0';
                    ex_mem.mem_write <= '0';
                else
                    ex_mem.alu_res   <= ex_result;
                    ex_mem.wr_data   <= alu_src_b_fw; -- Data chráněná proti hazardům.
                    ex_mem.rd_addr   <= id_ex.rd_addr;
                    ex_mem.csr_rdata <= ex_csr_rdata; -- Data přečtená z CSR posíláme dál
                    
                    ex_mem.reg_write <= id_ex.reg_write;
                    ex_mem.res_src   <= id_ex.res_src;
                    ex_mem.mem_write <= id_ex.mem_write;
                    
                    ex_mem.pc_plus_4 <= id_ex.pc_plus_4; -- Návratová adresa do paměťové fáze
                    ex_mem.funct3    <= id_ex.funct3;
                end if;

                -- ==========================================================
                -- 5. FÁZE MEM/WB
                -- ==========================================================
                mem_wb.alu_res    <= ex_mem.alu_res;
                mem_wb.mem_data   <= mem_rd_data_fmt;
                mem_wb.rd_addr    <= ex_mem.rd_addr;
                mem_wb.csr_rdata  <= ex_mem.csr_rdata; -- Data se blíží k cílovému registru
                
                mem_wb.reg_write  <= ex_mem.reg_write;
                mem_wb.res_src    <= ex_mem.res_src;
                
                mem_wb.pc_plus_4  <= ex_mem.pc_plus_4;
            end if;
        end if;
    end process;

end architecture rtl;