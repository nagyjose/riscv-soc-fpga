library ieee;
use ieee.std_logic_1164.all;

entity hazard_unit is
    port (
        -- 1. Vstupy pro detekci Zkratek (Forwarding)
        -- Co potřebuje ALU právě teď (ve fázi EX)?
        rs1_addr_ex : in std_logic_vector(4 downto 0);
        rs2_addr_ex : in std_logic_vector(4 downto 0);
        
        -- Co se právě počítá/zapisuje ve fázi MEM?
        rd_addr_mem : in std_logic_vector(4 downto 0);
        reg_wr_mem  : in std_logic;
        
        -- Co se právě zapisuje ve fázi WB (úplný konec)?
        rd_addr_wb  : in std_logic_vector(4 downto 0);
        reg_wr_wb   : in std_logic;
		  
		  -- 2. Vstupy pro detekci Load-Use Hazardu (čtení z ID fáze)
        rs1_addr_id : in std_logic_vector(4 downto 0);
        rs2_addr_id : in std_logic_vector(4 downto 0);
        rd_addr_ex  : in std_logic_vector(4 downto 0);
        res_src_ex  : in std_logic_vector(1 downto 0); -- Zda EX instrukce čte z RAM ("01")

        -- 3. Vstup pro detekci Skoků (Flushing)
        pc_src      : in std_logic;

        -- Výstupy pro Datovou cestu
        -- 00 = normální čtení, 10 = zkratka z MEM, 01 = zkratka z WB
        forward_a   : out std_logic_vector(1 downto 0); 
        forward_b   : out std_logic_vector(1 downto 0);
        
		  -- Výstupy pro zastavení času (Stall)
        stall_pc    : out std_logic;
        stall_if_id : out std_logic;
		  
        -- 1 = Smaž obsah těchto pipeline registrů
        flush_if_id : out std_logic;
        flush_id_ex : out std_logic
    );
end entity hazard_unit;

architecture rtl of hazard_unit is
	 signal lw_stall : std_logic;
begin

    -- ========================================================================
    -- LOGIKA PRO ZKRATKU A (ALU vstup pro Operand 1)
    -- ========================================================================
    process(rs1_addr_ex, rd_addr_mem, reg_wr_mem, rd_addr_wb, reg_wr_wb)
    begin
        -- Priorita 1: Instrukce hned za sebou (Forwarding z fáze MEM)
        -- Musíme ověřit, že zapisujeme (reg_wr = '1') a že nechráníme nulový registr x0!
        if (reg_wr_mem = '1') and (rd_addr_mem /= "00000") and (rd_addr_mem = rs1_addr_ex) then
            forward_a <= "10";
            
        -- Priorita 2: Instrukce ob jednu (Forwarding z fáze WB)
        elsif (reg_wr_wb = '1') and (rd_addr_wb /= "00000") and (rd_addr_wb = rs1_addr_ex) then
            forward_a <= "01";
            
        -- Jinak normální běh
        else
            forward_a <= "00";
        end if;
    end process;

    -- ========================================================================
    -- LOGIKA PRO ZKRATKU B (ALU vstup pro Operand 2)
    -- ========================================================================
    process(rs2_addr_ex, rd_addr_mem, reg_wr_mem, rd_addr_wb, reg_wr_wb)
    begin
        if (reg_wr_mem = '1') and (rd_addr_mem /= "00000") and (rd_addr_mem = rs2_addr_ex) then
            forward_b <= "10";
        elsif (reg_wr_wb = '1') and (rd_addr_wb /= "00000") and (rd_addr_wb = rs2_addr_ex) then
            forward_b <= "01";
        else
            forward_b <= "00";
        end if;
    end process;
	 
	 -- ========================================================================
    -- Detekce Load-Use Hazardu (Záchranná brzda)
    -- ========================================================================
    process(res_src_ex, rd_addr_ex, rs1_addr_id, rs2_addr_id)
    begin
        -- Zjišťujeme: Je instrukce v EX fázi čtení z RAM? (res_src = "01")
        -- A zároveň: Shoduje se její cílový registr se zdrojovými registry aktuální instrukce?
        if (res_src_ex = "01") and (rd_addr_ex /= "00000") and 
           ((rd_addr_ex = rs1_addr_id) or (rd_addr_ex = rs2_addr_id)) then
            lw_stall <= '1';
        else
            lw_stall <= '0';
        end if;
    end process;
	 
	 -- ========================================================================
    -- Směrování signálů
    -- ========================================================================
    -- Když brzdíme, nesmíme přepisovat PC ani registr IF/ID (držíme je na místě)
    stall_pc    <= lw_stall;
    stall_if_id <= lw_stall;

    -- ========================================================================
    -- LOGIKA PRO MAZÁNÍ PŘI SKOKU (Flushing)
    -- ========================================================================
    -- Pokud zjistíme skok (pc_src = '1'), smažeme rozpracované instrukce,
    -- které do pipeline omylem natekly.
    flush_if_id <= pc_src;
	 -- ID/EX mažeme buď kvůli skoku, nebo kvůli vložení NOPu při brzdění (Stall)!
    flush_id_ex <= pc_src or lw_stall;

end architecture rtl;