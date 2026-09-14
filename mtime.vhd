library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mtime is
    generic (
        SYS_CLK_FREQ : integer := 100000000; -- Systémové hodiny (100 MHz)
        TIMER_FREQ   : integer := 1000000    -- Frekvence časovače (1 MHz = 1 us)
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;

        -- Sběrnicové rozhraní (MMIO)
        cs        : in  std_logic;
        wr_en     : in  std_logic;
        addr      : in  std_logic;                     -- 0 = MTIME, 1 = MTIMECMP
        wr_data   : in  std_logic_vector(31 downto 0);
        rd_data   : out std_logic_vector(31 downto 0);
        
        -- Výstup přerušení rovnou do CSR jednotky
        timer_irq : out std_logic
    );
end entity mtime;

architecture rtl of mtime is
    -- Výpočet pro děličku: (100 000 000 / 1 000 000) - 1 = 99
    constant PRESCALER_MAX : integer := (SYS_CLK_FREQ / TIMER_FREQ) - 1;
    signal prescaler : integer range 0 to PRESCALER_MAX;
    
    -- Registry (používáme unsigned pro snadné porovnávání)
    signal r_mtime    : unsigned(31 downto 0);
    signal r_mtimecmp : unsigned(31 downto 0);
begin

    -- ========================================================================
    -- 1. HLAVNÍ ČÍTAČ, DĚLIČKA A ZÁPIS
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                prescaler  <= 0;
                r_mtime    <= (others => '0');
                -- Nastavíme komparátor na maximum (samé jedničky), aby hned nezvonil
                r_mtimecmp <= (others => '1'); 
            else
                -- A) Logika předděličky (Zpomalení na 1 MHz)
                if prescaler = PRESCALER_MAX then
                    prescaler <= 0;
                    r_mtime   <= r_mtime + 1; -- Tikne pouze jednou za mikrosekundu
                else
                    prescaler <= prescaler + 1;
                end if;
                
                -- B) Sběrnicový zápis z procesoru
                if cs = '1' and wr_en = '1' then
                    if addr = '1' then
                        -- Dovolíme zápis POUZE do komparátoru (MTIMECMP na adrese 0x04)
                        r_mtimecmp <= unsigned(wr_data);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- 2. SBĚRNICOVÉ ČTENÍ A KOMPARÁTOR
    -- ========================================================================
    -- Procesor může číst oba registry
    rd_data <= std_logic_vector(r_mtime) when addr = '0' else 
               std_logic_vector(r_mtimecmp);

    -- Hardwarový generátor přerušení: Zvoní, dokud MTIME >= MTIMECMP
    timer_irq <= '1' when (r_mtime >= r_mtimecmp) else '0';

end architecture rtl;