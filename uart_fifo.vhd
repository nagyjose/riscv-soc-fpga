library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_fifo is
    generic (
        ADDR_WIDTH : integer := 9 -- 2^9 = Hloubka 512 bytů
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Zápis (od UART RX modulu)
        wr_en    : in  std_logic;
        wr_data  : in  std_logic_vector(7 downto 0);
        
        -- Čtení (od Procesoru)
        rd_en    : in  std_logic;
        rd_data  : out std_logic_vector(7 downto 0);
        
        -- Stavy
        empty    : out std_logic;
        full     : out std_logic
    );
end entity uart_fifo;

architecture rtl of uart_fifo is
    constant FIFO_DEPTH : integer := 2**ADDR_WIDTH;
    type ram_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
    
    -- Vynucení použití hardwarového bloku M4K
    signal ram : ram_type;
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M4K"; 
    
    signal wr_ptr : unsigned(ADDR_WIDTH-1 downto 0);
    signal rd_ptr : unsigned(ADDR_WIDTH-1 downto 0);
    signal count  : unsigned(ADDR_WIDTH downto 0);
    
    signal is_full  : std_logic;
    signal is_empty : std_logic;
begin

    -- ========================================================================
    -- 1. ČISTÁ PAMĚŤ (Bez resetu - Quartus z tohoto vyrobí M4K)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' and is_full = '0' then
                ram(to_integer(wr_ptr)) <= wr_data;
            end if;
            
            -- First-Word Fall-Through (FWFT): Data leží na výstupu vždy,
            -- signál rd_en pouze posune ukazatel na další znak.
            rd_data <= ram(to_integer(rd_ptr));
        end if;
    end process;

    -- ========================================================================
    -- 2. LOGIKA UKAZATELŮ A POČÍTADLA (Zde používáme reset a normální LEs)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_ptr <= (others => '0');
                rd_ptr <= (others => '0');
                count  <= (others => '0');
            else
                -- Zápis posune ukazatel hlavy
                if wr_en = '1' and is_full = '0' then
                    wr_ptr <= wr_ptr + 1;
                end if;
                
                -- Čtení posune ukazatel ocasu
                if rd_en = '1' and is_empty = '0' then
                    rd_ptr <= rd_ptr + 1;
                end if;
                
                -- Bezpečné počítání prvků (ošetřeno proti současnému čtení a zápisu)
                if (wr_en = '1' and is_full = '0') and (rd_en = '0' or is_empty = '1') then
                    count <= count + 1;
                elsif (rd_en = '1' and is_empty = '0') and (wr_en = '0' or is_full = '1') then
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;

    is_empty <= '1' when count = 0 else '0';
    is_full  <= '1' when count = FIFO_DEPTH else '0';
    
    empty <= is_empty;
    full  <= is_full;

end architecture rtl;