library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entita je prázdná! Testbench nekomunikuje s okolním světem.
entity tb_riscv_core is
end entity tb_riscv_core;

architecture sim of tb_riscv_core is

    -- 1. Signály pro propojování na naší virtuální desce
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1'; -- Začínáme v resetu!
    
    signal gpio_pins    : std_logic_vector(19 downto 0) := (others => 'Z');
    
    signal uart_rx_pin  : std_logic := '1'; -- Sériová linka je v klidu HIGH
    signal uart_tx_pin  : std_logic;
    
    signal spi_sck_pin  : std_logic;
    signal spi_mosi_pin : std_logic;
    signal spi_miso_pin : std_logic := '1';
    
    signal tb_success   : std_logic;
    signal tb_error_id  : std_logic_vector(15 downto 0);
    
    -- Definice periody hodin (10 ns = 100 MHz procesor)
    constant CLK_PERIOD : time := 10 ns;

begin

    -- ========================================================================
    -- 1. INSTANTIACE PROCESORU (Celého SoC)
    -- ========================================================================
    u_dut: entity work.riscv_core
        port map (
            clk         => clk,
            rst         => rst,
            gpio_pins   => gpio_pins,
            uart_rx_pin => uart_rx_pin,
            uart_tx_pin => uart_tx_pin,
            spi_sck_pin  => spi_sck_pin,
            spi_mosi_pin => spi_mosi_pin,
            spi_miso_pin => spi_miso_pin,
            tb_success  => tb_success,
            tb_error_id => tb_error_id
        );

    -- ========================================================================
    -- 2. GENERÁTOR HODIN (Tlukot srdce procesoru)
    -- ========================================================================
    -- Neustále obrací hodnotu clk každých 5 nanosekund
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- ========================================================================
    -- 3. VYHODNOCENÍ DEBUG PORTU
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if tb_success = '1' then
                assert false report LF &
                                    "===============================================" & LF &
                                    "  [ SUCCESS ] SoC Funguje! Dual-Port RAM OK!" & LF &
                                    "===============================================" severity failure;
            elsif unsigned(tb_error_id) /= 0 then
                assert false report LF &
                                    "===============================================" & LF &
                                    "  [ ERROR ] Selhal test cislo: " & integer'image(to_integer(unsigned(tb_error_id))) & LF &
                                    "===============================================" severity failure;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- SIMULACE SPI SLAVE ZAŘÍZENÍ (Hardwarový Loopback)
    -- ========================================================================
    -- Cokoliv procesor pošle na MOSI, to se mu okamžitě vrátí na MISO.
    spi_miso_pin <= spi_mosi_pin;

    -- ========================================================================
    -- 4. HLAVNÍ SIMULAČNÍ SCÉNÁŘ (Pouze startovací sekvence)
    -- ========================================================================
    stimulus: process
    begin
        -- 1. Výchozí stav (Tlačítko uvolněno, linka v klidu)
        gpio_pins(19 downto 1) <= (others => 'Z');
        gpio_pins(0) <= '1';

        -- 2. Fáze: Drž procesor v resetu, aby se vše ustálilo
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        
        -- 3. Počkáme 500 ns, aby měl C kód čas nabootovat a nastavit registry
        wait for 250 us;      
        
        -- ==========================================
        -- TEST PŘIJÍMAČE: Pošleme procesoru znak 'X' (0x58 = 01011000 binárně)
        -- LSB první -> pošleme: Start(0), 0,0,0,1,1,0,1,0, Stop(1)
        -- ==========================================
        -- Rychlost bitu je 1600 ns (protože v C nastavíme UART_BAUD na 160)
        uart_rx_pin <= '0'; wait for 1600 ns; -- Start bit
        uart_rx_pin <= '0'; wait for 1600 ns; -- Bit 0 (LSB)
        uart_rx_pin <= '0'; wait for 1600 ns; -- Bit 1
        uart_rx_pin <= '0'; wait for 1600 ns; -- Bit 2
        uart_rx_pin <= '1'; wait for 1600 ns; -- Bit 3
        uart_rx_pin <= '1'; wait for 1600 ns; -- Bit 4
        uart_rx_pin <= '0'; wait for 1600 ns; -- Bit 5
        uart_rx_pin <= '1'; wait for 1600 ns; -- Bit 6
        uart_rx_pin <= '0'; wait for 1600 ns; -- Bit 7 (MSB)
        uart_rx_pin <= '1'; wait for 1600 ns; -- Stop bit
        
        wait for 50 us;
        
        -- ==========================================
        -- PRVNÍ STISK TLAČÍTKA (Očekáváme IRQ 1)
        -- ==========================================
        gpio_pins(0) <= '0';
        wait for 20 ns;
        gpio_pins(0) <= '1'; -- Hrana nahoru!
        wait for 50 ns;
        gpio_pins(0) <= '0';
        wait for 20 ns;
        gpio_pins(0) <= 'Z'; -- Uvolnění
        
        -- Dáme procesoru čas na obsluhu (trap_handler) a návrat (MRET)
        wait for 800 ns;
        
        -- ==========================================
        -- DRUHÝ STISK TLAČÍTKA (Očekáváme IRQ 2)
        -- ==========================================
        -- Pokud CSR jednotka neobnovila MIE, procesor tento stisk bude ignorovat!
        gpio_pins(0) <= '0';
        wait for 20 ns;
        gpio_pins(0) <= '1'; -- Hrana nahoru!
        wait for 50 ns;
        gpio_pins(0) <= '0';
        wait for 20 ns;
        gpio_pins(0) <= 'Z'; -- Uvolnění
        
        -- Timeout bez diakritiky
        wait for 10 ms; 
        assert false report LF &
                            "==========================================" & LF &
                            "  [TIMEOUT] Simulace bezela moc dlouho!" & LF &
                            "==========================================" severity failure;
    end process;

end architecture sim;