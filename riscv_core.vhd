library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscv_core is
    port (
        clk : in std_logic;
        rst : in std_logic;
        -- Zde v budoucnu přibudou piny pro FPGA (např. gpio_out, uart_tx)
        
        -- NAŠE PRVNÍ PERIFERIE: Výstup pro Testbench
        tb_success   : out std_logic;
        tb_error_id  : out std_logic_vector(15 downto 0)
    );
end entity riscv_core;

architecture rtl of riscv_core is

    -- Vnitřní propojovací signály CPU (Sběrnice)
    signal cpu_instr_addr   : std_logic_vector(31 downto 0);
    signal cpu_instr_data   : std_logic_vector(31 downto 0);
    
    signal cpu_mem_addr     : std_logic_vector(31 downto 0);
    signal cpu_mem_wr_data  : std_logic_vector(31 downto 0);
    signal cpu_mem_rd_data  : std_logic_vector(31 downto 0);
    signal cpu_mem_byte_ena : std_logic_vector(3 downto 0);

    -- Signály pro RAM
    signal ram_rd_data      : std_logic_vector(31 downto 0);
    signal ram_byte_ena     : std_logic_vector(3 downto 0);

begin

    -- ========================================================================
    -- 1. ADRESNÍ DEKODÉR (Sběrnicová výhybka, Nyní obsahuje i Debug Port)
    -- ========================================================================
    process(cpu_mem_addr, cpu_mem_byte_ena, cpu_mem_wr_data, ram_rd_data)
    begin
        -- Výchozí stavy (Zabraňují nechtěnému zápisu)
        ram_byte_ena    <= "0000";
        cpu_mem_rd_data <= (others => '0');
        tb_success      <= '0';
        tb_error_id     <= (others => '0');
        
        -- A) Pokud adresa začíná nulami (0x0000XXXX) -> Směruj do RAM
        if cpu_mem_addr(31 downto 28) = x"0" then
            ram_byte_ena    <= cpu_mem_byte_ena; -- Povol zápis do RAM
            cpu_mem_rd_data <= ram_rd_data;      -- Čti z RAM

        -- B) Pokud je adresa 0xFFFFFFFC -> Směruj do Debug Portu
        elsif cpu_mem_addr = x"FFFFFFFC" and cpu_mem_byte_ena /= "0000" then
            if cpu_mem_wr_data = x"00000001" then
                tb_success <= '1';
            elsif cpu_mem_wr_data(31 downto 16) = x"DEAD" then
                tb_error_id <= cpu_mem_wr_data(15 downto 0);
            end if;
            
        -- Zde v budoucnu přidáme "elsif cpu_mem_addr(31 downto 28) = x"4" pro GPIO!
        end if;
    end process;

    -- ========================================================================
    -- 2. INSTANTIACE JÁDRA PROCESORU
    -- ========================================================================
    u_cpu_datapath: entity work.datapath
        port map (
            clk          => clk,
            rst          => rst,
            instr_addr   => cpu_instr_addr,
            instr_data   => cpu_instr_data,
            mem_addr     => cpu_mem_addr,
            mem_wr_data  => cpu_mem_wr_data,
            mem_rd_data  => cpu_mem_rd_data,
            mem_byte_ena => cpu_mem_byte_ena
        );

    -- ========================================================================
    -- 3. INSTANTIACE SDÍLENÉ DUAL-PORT PAMĚTI
    -- ========================================================================
    u_memory: entity work.dual_port_ram
        port map (
            clk         => clk,
            
            -- PORT A (Instrukce CPU: Mrtvý zápis)
            addr_a      => cpu_instr_addr,
            wr_data_a   => (others => '0'), -- Oklamání Quartusu
            byte_ena_a  => "0000",          -- Oklamání Quartusu (zakázán zápis)
            rd_data_a   => cpu_instr_data,
            
            -- PORT B (Data CPU)
            addr_b      => cpu_mem_addr,
            wr_data_b   => cpu_mem_wr_data,
            byte_ena_b  => ram_byte_ena,
            rd_data_b   => ram_rd_data
        );

end architecture rtl;