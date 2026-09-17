library ieee;
use ieee.std_logic_1164.all;

-- Knihovna Altera pro přímý přístup k hardwarovým MegaFunkcím (M4K blokům)
library altera_mf;
use altera_mf.altera_mf_components.all;

entity dual_port_ram is
    generic (
        -- Namísto počtu slov předáváme šířku adresy, abychom zamezili přetékání
        -- 10 = 1024 slov (4 KB ROM)
        -- 12 = 4096 slov (16 KB RAM)
        ADDR_WIDTH : integer := 12;   -- Šířka adresní sběrnice (12 bitů = až 4096)
        RAM_WORDS  : integer := 2816; -- Fyzický počet slov (2816 = 22 bloků)
        
        -- Altsyncram umí zpracovat .mif i během simulace v ModelSimu!
        INIT_FILE  : string  := "program.mif" 
    );
    port (
        clk         : in  std_logic;
        
        -- PORT A (Instrukce)
        addr_a      : in  std_logic_vector(31 downto 0);
        wr_data_a   : in  std_logic_vector(31 downto 0);
        byte_ena_a  : in  std_logic_vector(3 downto 0);
        rd_data_a   : out std_logic_vector(31 downto 0);
        
        -- PORT B (Data)
        addr_b      : in  std_logic_vector(31 downto 0);
        wr_data_b   : in  std_logic_vector(31 downto 0);
        byte_ena_b  : in  std_logic_vector(3 downto 0);
        rd_data_b   : out std_logic_vector(31 downto 0)
    );
end entity dual_port_ram;

architecture rtl of dual_port_ram is
    signal wren_a : std_logic;
    signal wren_b : std_logic;
begin

    -- Altsyncram má pro zápis jediný bit (wren). Byte Enables ho doplňují.
    wren_a <= '1' when byte_ena_a /= "0000" else '0';
    wren_b <= '1' when byte_ena_b /= "0000" else '0';

    -- Instanciace fyzického křemíkového bloku
    u_altsyncram : altsyncram
    generic map (
        operation_mode            => "BIDIR_DUAL_PORT",
        ram_block_type            => "M4K",
        init_file                 => INIT_FILE,
        
        numwords_a                => RAM_WORDS,
        numwords_b                => RAM_WORDS,
        
        width_a                   => 32,
        widthad_a                 => ADDR_WIDTH,
        width_byteena_a           => 4,
        outdata_reg_a             => "UNREGISTERED",
        
        width_b                   => 32,
        widthad_b                 => ADDR_WIDTH,
        width_byteena_b           => 4,
        outdata_reg_b             => "UNREGISTERED",
        
        -- Na FPGA Cyclone musí PORT B běžet na stejných hodinách jako PORT A
        address_reg_b             => "CLOCK0",
        indata_reg_b              => "CLOCK0",
        wrcontrol_wraddress_reg_b => "CLOCK0",
        byteena_reg_b             => "CLOCK0"
    )
    port map (
        clock0    => clk,
        
        -- Dynamické oříznutí adresy zamezuje přetečení!
        address_a => addr_a(ADDR_WIDTH + 1 downto 2),
        data_a    => wr_data_a,
        byteena_a => byte_ena_a,
        wren_a    => wren_a,
        q_a       => rd_data_a,
        
        address_b => addr_b(ADDR_WIDTH + 1 downto 2),
        data_b    => wr_data_b,
        byteena_b => byte_ena_b,
        wren_b    => wren_b,
        q_b       => rd_data_b
    );

end architecture rtl;