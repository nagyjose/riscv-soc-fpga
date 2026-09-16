library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscv_core is
    port (
        clk          : in std_logic;
        rst          : in std_logic; -- Fyzické tlačítko
        prog_rst_pin : in std_logic; -- Pin z USB převodníku (RTS/DTR)
        
        -- GPIO piny
        gpio_pins    : inout std_logic_vector(19 downto 0);
        
        -- UART piny
        uart_rx_pin  : in  std_logic;
        uart_tx_pin  : out std_logic;
        
        -- SPI piny (Chip Select se řeší softwarově přes GPIO)
        spi_sck_pin  : out std_logic;
        spi_mosi_pin : out std_logic;
        spi_miso_pin : in  std_logic;
        
        -- PWM Timer výstup
        pwm1_pin_out : out std_logic;
        pwm2_pin_out : out std_logic;
        
        -- Výstup pro Testbench
        tb_success   : out std_logic;
        tb_error_id  : out std_logic_vector(15 downto 0)
    );
end entity riscv_core;

architecture rtl of riscv_core is

    -- Globální reset
    signal system_rst       : std_logic;

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
    signal ram_instr_data   : std_logic_vector(31 downto 0);

    -- Signály pro Boot ROM
    signal rom_instr_data   : std_logic_vector(31 downto 0);
    signal rom_rd_data      : std_logic_vector(31 downto 0);
    signal rom_cs           : std_logic;

    -- Signály pro GPIO periferii
    signal gpio_rd_data     : std_logic_vector(31 downto 0);
    signal gpio_cs          : std_logic;
    signal gpio_irq         : std_logic;
    signal gpio_wr_en       : std_logic;

    -- Signály pro MTIME
    signal timer_rd_data    : std_logic_vector(31 downto 0);
    signal timer_cs         : std_logic;
    signal timer_irq        : std_logic;
    signal timer_wr_en      : std_logic;

    -- Signály pro UART
    signal uart_rd_data     : std_logic_vector(31 downto 0);
    signal uart_cs          : std_logic;
    signal uart_irq         : std_logic;
    signal uart_wr_en       : std_logic;

    -- Signály pro SPI
    signal spi_rd_data      : std_logic_vector(31 downto 0);
    signal spi_cs           : std_logic;
    signal spi_wr_en        : std_logic;

    -- Signály pro HW Timer 1
    signal timer1_rd_data   : std_logic_vector(31 downto 0);
    signal timer1_cs        : std_logic;
    signal timer1_irq       : std_logic;

    -- Signály pro HW Timer 2
    signal timer2_rd_data   : std_logic_vector(31 downto 0);
    signal timer2_cs        : std_logic;
    signal timer2_irq       : std_logic;

    -- Centrální linka pro externí přerušení (Kód 11)
    signal shared_irq_ext   : std_logic;

begin

    -- Jádro se resetuje buď tlačítkem (v '1') nebo programátorem (v '0')
    system_rst <= rst or (not prog_rst_pin);

    -- ========================================================================
    -- MULTIPLEXER PRO INSTRUKČNÍ SBĚRNICI (Fáze IF)
    -- ========================================================================
    -- Pokud PC ukazuje na 0x0000XXXX, čti instrukce z Boot ROM.
    -- Jinak čti instrukce z hlavní RAM.
    cpu_instr_data <= rom_instr_data when cpu_instr_addr(31 downto 28) = x"0" else
                      ram_instr_data;

    -- ========================================================================
    -- 1. ADRESNÍ DEKODÉR (Sběrnicová výhybka, Nyní obsahuje i Debug Port)
    -- ========================================================================
    process(cpu_mem_addr, cpu_mem_byte_ena, cpu_mem_wr_data, 
            ram_rd_data, gpio_rd_data, timer_rd_data,
            uart_rd_data, spi_rd_data, timer1_rd_data,
            timer2_rd_data)
    begin
        -- Výchozí stavy (Zabraňují nechtěnému zápisu)
        ram_byte_ena    <= "0000";
        gpio_cs         <= '0';
        timer_cs        <= '0';
        uart_cs         <= '0';
        spi_cs          <= '0';
        timer1_cs       <= '0';
        timer2_cs       <= '0';
        rom_cs          <= '0';
        ram_cs          <= '0';
        cpu_mem_rd_data <= (others => '0');
        tb_success      <= '0';
        tb_error_id     <= (others => '0');

        -- 1) NOVÉ: Boot ROM (0x00000000 až 0x00000FFF) - např. 4 KB
        if cpu_mem_addr(31 downto 12) = x"00000" then
            rom_cs <= '1';
            cpu_mem_rd_data <= rom_rd_data;

        -- A) Pokud adresa začíná 0x2000XXXX -> Směruj do RAM
        elsif cpu_mem_addr(31 downto 28) = x"2000" then
            ram_byte_ena    <= cpu_mem_byte_ena; -- Povol zápis do RAM
            cpu_mem_rd_data <= ram_rd_data;      -- Čti z RAM

        -- B) Pokud je adresa 0xFFFFFFFC -> Směruj do Debug Portu
        elsif cpu_mem_addr = x"FFFFFFFC" and cpu_mem_byte_ena /= "0000" then
            if cpu_mem_wr_data = x"00000001" then
                tb_success <= '1';
            elsif cpu_mem_wr_data(31 downto 16) = x"DEAD" then
                tb_error_id <= cpu_mem_wr_data(15 downto 0);
            end if;

        -- C) GPIO Port (0x40000000)
        elsif cpu_mem_addr(31 downto 12) = x"40000" then
            gpio_cs <= '1';
            cpu_mem_rd_data <= gpio_rd_data;

        -- D) UART Port (0x40001000)
        elsif cpu_mem_addr(31 downto 12) = x"40001" then
            uart_cs <= '1';
            cpu_mem_rd_data <= uart_rd_data;

        -- E) SPI Port (0x40002000)
        elsif cpu_mem_addr(31 downto 12) = x"40002" then
            spi_cs <= '1';
            cpu_mem_rd_data <= spi_rd_data;

        -- F) HW Timer 1 (0x40003000)
        elsif cpu_mem_addr(31 downto 12) = x"40003" then
            timer1_cs <= '1';
            cpu_mem_rd_data <= timer1_rd_data;

        -- G) HW Timer 2 (0x40004000)
        elsif cpu_mem_addr(31 downto 12) = x"40004" then
            timer2_cs <= '1';
            cpu_mem_rd_data <= timer2_rd_data;

        -- H) Systémový časovač MTIME (0x8000XXXX)
        elsif cpu_mem_addr(31 downto 28) = x"8" then
            timer_cs <= '1';
            cpu_mem_rd_data <= timer_rd_data;

        -- Zde v budoucnu přidáme "elsif cpu_mem_addr(31 downto 28) = x"4" pro GPIO!
        end if;
    end process;

    -- ========================================================================
    -- 2. INSTANTIACE JÁDRA PROCESORU
    -- ========================================================================
    u_cpu_datapath: entity work.datapath
        port map (
            clk          => clk,
            rst          => system_rst,
            instr_addr   => cpu_instr_addr,
            instr_data   => cpu_instr_data,
            mem_addr     => cpu_mem_addr,
            mem_wr_data  => cpu_mem_wr_data,
            mem_rd_data  => cpu_mem_rd_data,
            mem_byte_ena => cpu_mem_byte_ena,
            irq_ext_in   => shared_irq_ext,
            irq_timer_in => timer_irq
        );
    
    -- Logický součet (GPIO, UART, nebo HW Timer)
    shared_irq_ext <= gpio_irq or uart_irq or timer1_irq or timer2_irq;

    -- ========================================================================
    -- 3. BOOT ROM (Paměť č. 1 na adrese 0x00000000 z .mif boot souboru)
    -- ========================================================================
    u_boot_rom: entity work.dual_port_ram
        generic map (
            RAM_SIZE_WORDS => 1024, -- 4 KB ROM
            INIT_FILE      => "bootloader.hex" -- Zde bude zavaděč
        )
        port map (
            clk         => clk,
            
            -- PORT A (Tahání instrukcí pro procesor)
            addr_a      => cpu_instr_addr,
            wr_data_a   => (others => '0'),
            byte_ena_a  => "0000", -- ZÁPIS TVRDĚ ZAKÁZÁN
            rd_data_a   => rom_instr_data,
            
            -- PORT B (Datová sběrnice - přístup CPU k datům)
            addr_b      => cpu_mem_addr,
            wr_data_b   => (others => '0'),
            byte_ena_b  => "0000", -- ZÁPIS TVRDĚ ZAKÁZÁN
            rd_data_b   => rom_rd_data
        );

    -- ========================================================================
    -- 4. HLAVNÍ RAM (Paměť č. 2 na adrese 0x20000000 - sdílená paměť)
    -- ========================================================================
    u_memory: entity work.dual_port_ram
        generic map (
            RAM_SIZE_WORDS => 4096, -- 16 KB RAM
            INIT_FILE      => "programm.hex"
        )
        port map (
            clk         => clk,
            
            -- PORT A (Tahání instrukcí pro procesor)
            addr_a      => cpu_instr_addr,
            wr_data_a   => (others => '0'),
            byte_ena_a  => "0000", -- Zápis instrukcí není dovolen
            rd_data_a   => ram_instr_data,
            
            -- PORT B (Datová sběrnice - přístup CPU k datům vč. zápisu)
            addr_b      => cpu_mem_addr,
            wr_data_b   => cpu_mem_wr_data,
            byte_ena_b  => ram_byte_ena, -- Řízeno tvým dekodérem pro 0x2000
            rd_data_b   => ram_rd_data
        );

    -- ========================================================================
    -- 5. INSTANTIACE GPIO PERIFERIE (Omezená na 20 pinů)
    -- ========================================================================
    gpio_wr_en <= '1' when cpu_mem_byte_ena /= "0000" else '0';
    
    u_gpio: entity work.gpio
        generic map (
            PINS => 20 -- Úspora LE
        )
        port map (
            clk       => clk,
            rst       => system_rst,
            cs        => gpio_cs,
            wr_en     => gpio_wr_en,
            addr      => cpu_mem_addr(4 downto 2),
            wr_data   => cpu_mem_wr_data,
            rd_data   => gpio_rd_data,
            irq_out   => gpio_irq,
            gpio_pins => gpio_pins
        );

    -- ========================================================================
    -- 6. INSTANTIACE MTIME ČASOVAČ
    -- ========================================================================
    timer_wr_en <= '1' when cpu_mem_byte_ena /= "0000" else '0';
    
    u_mtime: entity work.mtime
        generic map (
            SYS_CLK_FREQ => 100000000, -- 100 MHz
            TIMER_FREQ   => 1000000    -- 1 MHz (1 tik = 1 us)
        )
        port map (
            clk       => clk,
            rst       => system_rst,
            cs        => timer_cs,
            wr_en     => timer_wr_en,
            addr      => cpu_mem_addr(2),
            wr_data   => cpu_mem_wr_data,
            rd_data   => timer_rd_data,
            timer_irq => timer_irq
        );

    -- ========================================================================
    -- 7. INSTANTIACE UART
    -- ========================================================================
    uart_wr_en <= '1' when cpu_mem_byte_ena /= "0000" else '0';
    
    u_uart: entity work.uart
        port map (
            clk       => clk,
            rst       => system_rst,
            cs        => uart_cs,
            wr_en     => uart_wr_en,
            -- Pro adresy 0x00, 0x04, 0x08 bereme bity 3 a 2
            addr      => cpu_mem_addr(3 downto 2), 
            wr_data   => cpu_mem_wr_data,
            rd_data   => uart_rd_data,
            irq_out   => uart_irq,
            rx_pin    => uart_rx_pin,
            tx_pin    => uart_tx_pin
        );

    -- ========================================================================
    -- 8. INSTANTIACE SPI MASTERA
    -- ========================================================================
    spi_wr_en <= '1' when cpu_mem_byte_ena /= "0000" else '0';
    
    u_spi: entity work.spi_master
        port map (
            clk       => clk,
            rst       => system_rst,
            cs        => spi_cs,
            wr_en     => spi_wr_en,
            addr      => cpu_mem_addr(3 downto 2),
            wr_data   => cpu_mem_wr_data,
            rd_data   => spi_rd_data,
            spi_sck   => spi_sck_pin,
            spi_mosi  => spi_mosi_pin,
            spi_miso  => spi_miso_pin
        );

    -- ========================================================================
    -- 9. INSTANTIACE HW TIMERU 1
    -- ========================================================================
    u_timer1: entity work.pwm_timer
        port map (
            clk       => clk,
            rst       => system_rst,
            cs        => timer1_cs,
            -- Opět využíváme univerzální signál zápisu z nadřazené logiky
            wr_en     => spi_wr_en, 
            addr      => cpu_mem_addr(3 downto 2),
            wr_data   => cpu_mem_wr_data,
            rd_data   => timer1_rd_data,
            irq_out   => timer1_irq,
            pwm_pin   => pwm1_pin_out
        );

    -- ========================================================================
    -- 10. INSTANTIACE HW TIMERU 2
    -- ========================================================================
    u_timer2: entity work.pwm_timer
        port map (
            clk       => clk,
            rst       => system_rst,
            cs        => timer2_cs,
            -- Opět využíváme univerzální signál zápisu z nadřazené logiky
            wr_en     => spi_wr_en, 
            addr      => cpu_mem_addr(3 downto 2),
            wr_data   => cpu_mem_wr_data,
            rd_data   => timer2_rd_data,
            irq_out   => timer2_irq,
            pwm_pin   => pwm2_pin_out
        );

end architecture rtl;