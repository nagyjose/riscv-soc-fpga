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
    -- 4. HLAVNÍ SIMULAČNÍ SCÉNÁŘ (Pouze startovací sekvence)
    -- ========================================================================
    stimulus: process
    begin
        -- 1. Fáze: Drž procesor v resetu, aby se vše ustálilo
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        
        -- 2. Počkáme 500 ns, aby měl C kód čas nabootovat a nastavit registry
        wait for 500 ns;      
        
        -- 3. SIMULACE TLAČÍTKA NA PINU 0
        -- Vytvoříme čistou náběžnou hranu z nuly na jedničku
        gpio_pins(0) <= '0';
        wait for 20 ns;
        
        gpio_pins(0) <= '1'; -- <<< TADY DOCHÁZÍ K PŘERUŠENÍ!
        wait for 50 ns;
        
        gpio_pins(0) <= '0';
        wait for 20 ns;
        
        -- Tlačítko pouštíme a pin opět "odpojujeme" od testbenche
        gpio_pins(0) <= 'Z';
        
        -- Timeout bez diakritiky
        wait for 10 ms; 
        assert false report LF &
                            "==========================================" & LF &
                            "  [TIMEOUT] Simulace bezela moc dlouho!" & LF &
                            "==========================================" severity failure;
    end process;

end architecture sim;