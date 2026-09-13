library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_file is
    port (
        clk      : in  std_logic;
        
        -- Čtecí port 1 (Pro Operand A)
        rd_addr1 : in  std_logic_vector(4 downto 0);
        rd_data1 : out std_logic_vector(31 downto 0);
        
        -- Čtecí port 2 (Pro Operand B)
        rd_addr2 : in  std_logic_vector(4 downto 0);
        rd_data2 : out std_logic_vector(31 downto 0);
        
        -- Zapisovací port (Z fáze Write-Back)
        wr_en    : in  std_logic;
        wr_addr  : in  std_logic_vector(4 downto 0);
        wr_data  : in  std_logic_vector(31 downto 0)
    );
end entity reg_file;

architecture rtl of reg_file is
    -- Definice pole 32 registrů, každý o šířce 32 bitů
    type reg_array is array (0 to 31) of std_logic_vector(31 downto 0);
    
    -- Fyzické vytvoření paměti a její naplnění nulami
    signal registers : reg_array := (others => (others => '0'));

    -- ========================================================================
    -- VYNUCENÍ M4K BLOKŮ (Šetříme Logické Elementy na Cyclone II)
    -- ========================================================================
    attribute ramstyle : string;
    
    -- Pro vynucení do BRAM (M4K v Cyclone II):
    attribute ramstyle of registers : signal is "M4K";

    -- Pro vynucení do Logických elementů (LUTs / Flip-Flops):
    -- attribute ramstyle of registers : signal is "logic";

    -- Mezisignály pro data, která vypadnou z paměti
    signal out_data1 : std_logic_vector(31 downto 0);
    signal out_data2 : std_logic_vector(31 downto 0);
begin

    -- ========================================================================
    -- SYNCHRONNÍ BLOK (Na sestupnou hranu hodin)
    -- ========================================================================
    process(clk)
    begin
        -- falling_edge zaručí, že data budou připravena dříve, než
        -- si je v dalším taktu chytne hlavní pipeline registr (id_ex)
        if falling_edge(clk) then
            
            -- Zápis do M4K paměti
            if wr_en = '1' and wr_addr /= "00000" then
                registers(to_integer(unsigned(wr_addr))) <= wr_data;
            end if;
            
            -- Synchronní čtení z M4K paměti
            out_data1 <= registers(to_integer(unsigned(rd_addr1)));
            out_data2 <= registers(to_integer(unsigned(rd_addr2)));
            
        end if;
    end process;

    -- ========================================================================
    -- BEZPEČNOSTNÍ POJISTKA PRO REGISTR X0 A INTERNAL FORWARDING
    -- ========================================================================
    -- V M4K paměti na adrese 0 může být odpad (při startu FPGA).
    -- Proto na výstupu data natvrdo přepíšeme na nuly, pokud někdo čte z x0
    -- Pokud se ve stejném taktu do registru zapisuje a zároveň z něj čte,
    -- musíme data přeposlat přímo ze zápisu (tzv. Write-Through), protože
    -- M4K/LE paměť by vrátila starou hodnotu těsně před zápise.
    rd_data1 <= (others => '0') when rd_addr1 = "00000" else 
                wr_data         when (wr_en = '1' and rd_addr1 = wr_addr) else 
                out_data1;
                
    rd_data2 <= (others => '0') when rd_addr2 = "00000" else 
                wr_data         when (wr_en = '1' and rd_addr2 = wr_addr) else 
                out_data2;

end architecture rtl;