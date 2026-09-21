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
    signal prog_rst_pin : std_logic := '1'; -- Z programátoru reset zatím nepřichází
    
    signal gpio_pins    : std_logic_vector(19 downto 0) := (others => 'Z');
    
    signal uart_rx_pin  : std_logic := '1'; -- Sériová linka je v klidu HIGH
    signal uart_tx_pin  : std_logic;
    
    signal spi_sck_pin  : std_logic;
    signal spi_mosi_pin : std_logic;
    signal spi_miso_pin : std_logic := '1';
    
    signal pwm1_pin_out : std_logic;
    signal pwm2_pin_out : std_logic;
    
    signal stepper_pins : std_logic_vector(31 downto 0);
    
    -- signal tb_success   : std_logic;
    -- signal tb_error_id  : std_logic_vector(15 downto 0);
    signal sim_done     : boolean := false;
    
    -- Definice periody hodin (10 ns = 100 MHz procesor)
    constant CLK_PERIOD       : time := 10 ns;
    constant UART_BAUD_PERIOD : time := 8680 ns; -- 100MHz / 115200 baudů

begin

    -- ========================================================================
    -- 1. INSTANTIACE PROCESORU (Celého SoC)
    -- ========================================================================
    u_dut: entity work.riscv_core
        port map (
            clk          => clk,
            rst          => rst,
            prog_rst_pin => prog_rst_pin,
            gpio_pins    => gpio_pins,
            uart_rx_pin  => uart_rx_pin,
            uart_tx_pin  => uart_tx_pin,
            spi_sck_pin  => spi_sck_pin,
            spi_mosi_pin => spi_mosi_pin,
            spi_miso_pin => spi_miso_pin,
            pwm1_pin_out => pwm1_pin_out,
            pwm2_pin_out => pwm2_pin_out,
            stepper_pins => stepper_pins
            -- tb_success   => tb_success,
            -- tb_error_id  => tb_error_id
        );

    -- ========================================================================
    -- 2. GENERÁTOR HODIN (Tlukot srdce procesoru)
    -- ========================================================================
    -- Neustále obrací hodnotu clk každých 5 nanosekund
    clk_process: process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait; -- Definitivní konec
    end process;

    -- ========================================================================
    -- 3. CENTRÁLNÍ MONITOR (Řeší Úspěch i Timeout z jednoho místa!)
    -- ========================================================================
    monitor: process
    begin
        -- Čeká na úspěch z Debug Portu, ale maximálně 10 milisekund
        -- wait until tb_success = '1' for 10 ms;
        
        -- if tb_success = '1' then
        --     report LF & "==========================================" & LF &
        --                 "  [ SUCCESS ] Bootloader skocil do RAM!" & LF &
        --                 "==========================================" severity note;
        -- else
        --     report LF & "==========================================" & LF &
        --                 "  [ TIMEOUT ] Aplikace nedobehla vcas!" & LF &
        --                 "==========================================" severity note;
        -- end if;
        
        wait for 1 ms; 
        
        report LF & "==========================================" & LF &
                    "  [ DOKONCENO ] Cas simulace vyprsel." & LF &
                    "==========================================" severity note;
        
        -- Zde je JEDINÝ zdroj (driver), který ovlivňuje sim_done
        sim_done <= true; 
        wait;
    end process;

    -- ========================================================================
    -- 4. SIMULACE SPI SLAVE ZAŘÍZENÍ (Hardwarový Loopback)
    -- ========================================================================
    -- Cokoliv procesor pošle na MOSI, to se mu okamžitě vrátí na MISO.
    spi_miso_pin <= spi_mosi_pin;

    -- ========================================================================
    -- 5. HLAVNÍ SIMULAČNÍ SCÉNÁŘ (Pouze startovací sekvence)
    -- ========================================================================
    stimulus: process
        -- VHDL Procedura chovající se jako odesílací skript na PC
        procedure send_byte (
            constant data_in : in std_logic_vector(7 downto 0)
        ) is
        begin
            uart_rx_pin <= '0'; -- Start bit
            wait for UART_BAUD_PERIOD;
            for i in 0 to 7 loop
                uart_rx_pin <= data_in(i);
                wait for UART_BAUD_PERIOD;
            end loop;
            uart_rx_pin <= '1'; -- Stop bit
            wait for UART_BAUD_PERIOD;
        end procedure;
    
    begin
        -- 1. Fáze: Uvolníme fyzické tlačítko
        rst <= '0';
        
        -- 2. Fáze: HARDWAROVÝ RESET Z PC (Python stáhne DTR pin)
        prog_rst_pin <= '0';
        wait for 100 ns;
        prog_rst_pin <= '1'; 
        -- Zde se procesor probouzí na adrese 0x00000000 (Bootloader)
        
        -- Dáme C kódu bootloaderu čas na nastavení registrů (Stack a Baud rate)
        wait for 20 us;
        
        -- ========================================================
        -- 3. Fáze: ODESÍLÁNÍ PROGRAMU PŘES UART
        -- ========================================================
        -- A) Magické slovo 'B' (0x42)
        send_byte(x"42");
        
        -- B) Velikost v bytech posílaná LSB first. Posíláme nulu (0x00000000).
        -- Bootloader přeskočí přijímání a hned skočí do RAM!
        send_byte(x"00");
        send_byte(x"00");
        send_byte(x"00");
        send_byte(x"00");
        
        -- Teď by měl Bootloader poslat 'K' (0x4B) a skočit do `main.c`.
        -- `main.c` zapíše na Debug Port a vyvolá SUCCESS!
        
        -- Proces končí, o zbytek a ukončení simulace se postará centrální monitor
        wait;
    end process;

end architecture sim;