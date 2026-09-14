library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csr_unit is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- ==========================================================
        -- Rozhraní pro instrukce (Zápis/Čtení z programu)
        -- ==========================================================
        csr_addr    : in  std_logic_vector(11 downto 0); -- 12bitová adresa registru
        csr_wdata   : in  std_logic_vector(31 downto 0); -- Data pro zápis
        csr_cmd     : in  std_logic_vector(1 downto 0);  -- Příkaz: 00=Nic, 01=Zápis(RW), 10=Nastav bity(RS), 11=Nuluj bity(RC)
        csr_rdata   : out std_logic_vector(31 downto 0); -- Přečtená data zpět do ALU/RegFile
        
        -- ==========================================================
        -- Systémové rozhraní (Pro hardware a periferie)
        -- ==========================================================
        pc_in       : in  std_logic_vector(31 downto 0); -- Aktuální Program Counter (pro uložení při přerušení)
        irq_ext     : in  std_logic;                     -- Externí přerušení (např. od GPIO/UART)
        is_mret     : in  std_logic;                     -- Procesor hlásí návrat z přerušení!
        
        epc_out     : out std_logic_vector(31 downto 0); -- Kam se má PC vrátit (z registru MEPC)
        trap_target : out std_logic_vector(31 downto 0); -- Kam má PC skočit při přerušení (z registru MTVEC)
        trap_fire   : out std_logic                      -- Signál pro PC multiplexer: "Zahoď všechno, máme přerušení!"
    );
end entity csr_unit;

architecture rtl of csr_unit is

    -- Fyzické registry (Minimum nutné pro Machine Mode)
    signal mstatus_mie  : std_logic;                       -- Master spínač přerušení (Bit 3 v MSTATUS)
    signal mstatus_mpie : std_logic;                       -- Záložní bit
    signal mtvec        : std_logic_vector(31 downto 0);   -- Vektor přerušení (Kam skočit)
    signal mepc         : std_logic_vector(31 downto 0);   -- Návratová adresa (Odkud jsme vyskočili)
    signal mcause       : std_logic_vector(31 downto 0);   -- Původce přerušení
    
    -- Vnitřní signál pro multiplexer čtení
    signal read_data    : std_logic_vector(31 downto 0);

begin

    -- ========================================================================
    -- 1. KOMBINAČNÍ ČTENÍ (Bez hodin - okamžitá odpověď)
    -- ========================================================================
    process(csr_addr, mstatus_mie, mstatus_mpie, mtvec, mepc, mcause)
    begin
        -- Výchozí stav (zabraňuje vzniku nechtěných klopných obvodů typu Latch)
        read_data <= (others => '0'); 
        
        case csr_addr is
            when x"300" => read_data(3) <= mstatus_mie; -- MSTATUS (mapujeme jen bit 3)
                           read_data(7) <= mstatus_mpie;
            when x"305" => read_data    <= mtvec;       -- MTVEC
            when x"341" => read_data    <= mepc;        -- MEPC
            when x"342" => read_data    <= mcause;      -- MCAUSE
            when others => null;                        -- Neznámý registr vrací nuly
        end case;
    end process;
    
    -- Připojení vnitřního signálu na venkovní porty
    csr_rdata   <= read_data;
    epc_out     <= mepc;
    trap_target <= mtvec;

    -- ========================================================================
    -- 2. SEKVENČNÍ ZÁPIS A PŘERUŠENÍ (Řízeno hodinovým signálem)
    -- ========================================================================
    process(clk)
        variable temp_write : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mstatus_mie <= '0';       -- Po resetu jsou přerušení bezpečně vypnuta
                mtvec       <= (others => '0');
                mepc        <= (others => '0');
                trap_fire   <= '0';
            else
                -- V každém taktu musí jít signál pro skok dolů, jinak bychom skákali donekonečna
                trap_fire <= '0'; 

                -- A) NÁVRAT Z PŘERUŠENÍ (Instrukce MRET)
                if is_mret = '1' then
                    mstatus_mie  <= mstatus_mpie; -- Obnova ze zálohy
                    mstatus_mpie <= '1';          -- RISC-V standard říká nastavit na 1

                -- B) VSTUP DO PŘERUŠENÍ (Hardwarový Trap)
                elsif irq_ext = '1' and mstatus_mie = '1' then
                    mstatus_mpie <= mstatus_mie; -- 1. Uložíme aktuální stav do zálohy
                    mstatus_mie  <= '0';         -- 2. Zablokujeme další přerušení (aby se nezacyklilo)
                    mepc         <= pc_in;       -- 3. Uložíme aktuální PC do mepc
                    mcause       <= x"8000000B"; -- 4. Hardwarový zápis původu (External Interrupt)
                    trap_fire    <= '1';         -- 5. Vystřelíme požadavek na zahození pipeliny a skok

                -- C) SOFTWAROVÝ ZÁPIS (Z instrukcí csr_cmd)
                elsif csr_cmd /= "00" then
                    -- ALU logika pro předpočítání výsledku zápisu
                    if    csr_cmd = "01" then temp_write := csr_wdata;                       -- CSRRW (Zápis)
                    elsif csr_cmd = "10" then temp_write := read_data or csr_wdata;          -- CSRRS (Nastav bity)
                    elsif csr_cmd = "11" then temp_write := read_data and (not csr_wdata);   -- CSRRC (Nuluj bity)
                    end if;

                    -- Uložení předpočítané hodnoty do správného registru
                    case csr_addr is
                        when x"300" => mstatus_mie  <= temp_write(3);
                                       mstatus_mpie <= temp_write(7); -- Zápis i do zálohy
                        when x"305" => mtvec        <= temp_write;
                        when x"341" => mepc         <= temp_write;
                        when x"342" => mcause       <= temp_write;    -- Softwarový zápis
                        when others => null; -- Zápis do neznámého registru je ticho zahozen
                    end case;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;