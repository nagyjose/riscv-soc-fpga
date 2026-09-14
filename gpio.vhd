library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gpio is
    generic (
        PINS : integer := 8 -- Počet fyzických pinů (1 až 32)
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;

        -- ==========================================================
        -- Sběrnicové rozhraní (MMIO)
        -- ==========================================================
        cs        : in  std_logic;                     -- Chip Select (1 = Procesor mluví s námi)
        wr_en     : in  std_logic;                     -- 1 = Zápis, 0 = Čtení
        addr      : in  std_logic_vector(2 downto 0);  -- Bity 4:2 z celkové adresy (0x00 až 0x10)
        wr_data   : in  std_logic_vector(31 downto 0); -- Data z procesoru
        rd_data   : out std_logic_vector(31 downto 0); -- Data pro procesor
        
        -- ==========================================================
        -- Výstup přerušení (Do řadiče nebo rovnou do irq_ext)
        -- ==========================================================
        irq_out   : out std_logic;
        
        -- ==========================================================
        -- Fyzické piny na FPGA
        -- ==========================================================
        gpio_pins : inout std_logic_vector(PINS-1 downto 0)
    );
end entity gpio;

architecture rtl of gpio is
    -- Hlavní registry
    signal r_data : std_logic_vector(PINS-1 downto 0);
    signal r_dir  : std_logic_vector(PINS-1 downto 0);
    signal r_mask : std_logic_vector(PINS-1 downto 0);
    signal r_edge : std_logic_vector(PINS-1 downto 0);
    signal r_pend : std_logic_vector(PINS-1 downto 0);
    
    -- Synchronizační registry (Ochrana proti metastabilitě z vnějšího světa)
    signal sync1, sync2, sync3 : std_logic_vector(PINS-1 downto 0);
    
    -- Vnitřní signály pro detekci a čtení
    signal edge_detected : std_logic_vector(PINS-1 downto 0);
    signal read_bus      : std_logic_vector(31 downto 0);

begin

    -- ========================================================================
    -- 1. TŘETÍ STAV (Tri-State Buffers) - FYZICKÉ ŘÍZENÍ PINŮ
    -- ========================================================================
    -- Pokud je DIR = '1', posíláme ven náš DATA registr.
    -- Pokud je DIR = '0', odpojíme pin (stav 'Z'), aby ho mohlo budit tlačítko.
    tristate_gen: for i in 0 to PINS-1 generate
        gpio_pins(i) <= r_data(i) when r_dir(i) = '1' else 'Z';
    end generate;

    -- ========================================================================
    -- 2. SYNCHRONIZÁTOR A DETEKCE HRAN (Vstupní cesta)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sync1 <= (others => '0');
                sync2 <= (others => '0');
                sync3 <= (others => '0');
            else
                -- Z fyzických pinů čteme vždy (i když jsou to výstupy).
                -- Protlačíme to přes 2 klopné obvody (sync1, sync2) pro stabilitu.
                sync1 <= gpio_pins;
                sync2 <= sync1;
                
                -- Třetí registr slouží k uchování minulé hodnoty pro detekci hrany
                sync3 <= sync2; 
            end if;
        end if;
    end process;

    -- Kombinační detekce hrany (Náběžná vs Sestupná podle r_edge)
    edge_gen: for i in 0 to PINS-1 generate
        edge_detected(i) <= (sync2(i) and not sync3(i)) when r_edge(i) = '0' else -- Náběžná hrana
                            (not sync2(i) and sync3(i));                          -- Sestupná hrana
    end generate;

    -- ========================================================================
    -- 3. SBĚRNICE - ZÁPIS A OBSLUHA REGISTRŮ
    -- ========================================================================
    process(clk)
        variable pend_clear_mask : std_logic_vector(PINS-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_data <= (others => '0');
                r_dir  <= (others => '0');
                r_mask <= (others => '0');
                r_edge <= (others => '0');
                r_pend <= (others => '0');
            else
                -- A) PŘÍPRAVA MASKY PRO MAZÁNÍ PŘERUŠENÍ
                pend_clear_mask := (others => '0');
                
                -- B) SBĚRNICOVÝ ZÁPIS Z PROCESORU
                if cs = '1' and wr_en = '1' then
                    case addr is
                        when "000" => r_data <= wr_data(PINS-1 downto 0);
                        when "001" => r_dir  <= wr_data(PINS-1 downto 0);
                        when "010" => r_mask <= wr_data(PINS-1 downto 0);
                        when "011" => r_edge <= wr_data(PINS-1 downto 0);
                        when "100" => pend_clear_mask := wr_data(PINS-1 downto 0); -- Tzv. W1C logika
                        when others => null;
                    end case;
                end if;
                
                -- C) HARDWAROVÁ AKTUALIZACE PENDING REGISTRU
                -- Hardware (edge_detected) má vždy prioritu nad smazáním z programu,
                -- aby nedošlo ke ztrátě přerušení, pokud přijdou ve stejném taktu.
                r_pend <= (r_pend and not pend_clear_mask) or edge_detected;
                
            end if;
        end if;
    end process;

    -- ========================================================================
    -- 4. SBĚRNICE - ČTENÍ Z REGISTRŮ
    -- ========================================================================
    process(addr, sync2, r_dir, r_mask, r_edge, r_pend)
    begin
        read_bus <= (others => '0'); -- Nulování horních bitů (pokud je PINS < 32)
        
        case addr is
            when "000" => read_bus(PINS-1 downto 0) <= sync2;  -- Čteme skutečný stav pinů!
            when "001" => read_bus(PINS-1 downto 0) <= r_dir;
            when "010" => read_bus(PINS-1 downto 0) <= r_mask;
            when "011" => read_bus(PINS-1 downto 0) <= r_edge;
            when "100" => read_bus(PINS-1 downto 0) <= r_pend;
            when others => null;
        end case;
    end process;
    
    -- Čtecí port je asynchronní/kombinační (procesor si data chytí do své pipeline)
    rd_data <= read_bus;

    -- ========================================================================
    -- 5. GENERÁTOR GLOBÁLNÍHO PŘERUŠENÍ
    -- ========================================================================
    -- Pokud alespoň jeden bit v PEND registru je nastavený a zároveň
    -- je pro něj v MASK registru povolené přerušení, křičíme na procesor.
    process(r_pend, r_mask)
        variable irq_active : std_logic;
    begin
        irq_active := '0';
        for i in 0 to PINS-1 loop
            if (r_pend(i) and r_mask(i)) = '1' then
                irq_active := '1';
            end if;
        end loop;
        irq_out <= irq_active;
    end process;

end architecture rtl;