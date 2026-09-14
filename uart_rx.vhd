library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Sběrnicové rozhraní uvnitř UART modulu
        baud_div : in  std_logic_vector(15 downto 0); -- Např. hodnota 868
        rx_data  : out std_logic_vector(7 downto 0);  -- Složený byte
        rx_valid : out std_logic;                     -- Impulz 1 takt (Zápis do FIFO)
        
        -- Fyzický vstupní pin
        rx_pin   : in  std_logic
    );
end entity uart_rx;

architecture rtl of uart_rx is
    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_t;
    
    -- Ochrana proti metastabilitě
    signal rx_sync1 : std_logic;
    signal rx_sync2 : std_logic;
    
    -- Dělička pro 16x oversampling
    signal clk_div  : unsigned(11 downto 0);
    signal tick_16x : std_logic;
    
    -- Čítače a registry
    signal tick_cnt : integer range 0 to 15;
    signal bit_idx  : integer range 0 to 7;
    signal shift_reg: std_logic_vector(7 downto 0);
    
begin
    -- ========================================================================
    -- 1. SYNCHRONIZÁTOR VSTUPU
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_sync1 <= '1';
                rx_sync2 <= '1';
            else
                rx_sync1 <= rx_pin;
                rx_sync2 <= rx_sync1;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- 2. GENERÁTOR 16x OVERSAMPLING TIKŮ
    -- ========================================================================
    process(clk)
        variable baud_16x_target : unsigned(11 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                clk_div  <= (others => '0');
                tick_16x <= '0';
            else
                -- Cílová hodnota = baud_div / 16
                baud_16x_target := unsigned(baud_div(15 downto 4));
                
                if clk_div >= baud_16x_target - 1 then
                    clk_div  <= (others => '0');
                    tick_16x <= '1';
                else
                    clk_div  <= clk_div + 1;
                    tick_16x <= '0';
                end if;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- 3. HLAVNÍ PŘIJÍMACÍ AUTOMAT
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= IDLE;
                rx_valid <= '0';
                rx_data  <= (others => '0');
                tick_cnt <= 0;
                bit_idx  <= 0;
            else
                -- Výchozí stav pulzního signálu (zvedne se jen na 1 takt)
                rx_valid <= '0';
                
                case state is
                    when IDLE =>
                        tick_cnt <= 0;
                        bit_idx  <= 0;
                        -- Čekáme na sestupnou hranu (začátek Start bitu)
                        if rx_sync2 = '0' then
                            state <= START_BIT;
                        end if;
                        
                    when START_BIT =>
                        if tick_16x = '1' then
                            if tick_cnt = 7 then -- Jsme přesně uprostřed Start bitu!
                                if rx_sync2 = '0' then
                                    tick_cnt <= 0;
                                    state    <= DATA_BITS;
                                else
                                    -- Falešný poplach (šum), vracíme se zpět
                                    state <= IDLE;
                                end if;
                            else
                                tick_cnt <= tick_cnt + 1;
                            end if;
                        end if;
                        
                    when DATA_BITS =>
                        if tick_16x = '1' then
                            if tick_cnt = 15 then -- Přeskočili jsme o celý jeden bit
                                tick_cnt <= 0;
                                -- LSB přijde jako první, nasouváme z vrchu dolů
                                shift_reg(bit_idx) <= rx_sync2;
                                
                                if bit_idx = 7 then
                                    state <= STOP_BIT;
                                else
                                    bit_idx <= bit_idx + 1;
                                end if;
                            else
                                tick_cnt <= tick_cnt + 1;
                            end if;
                        end if;
                        
                    when STOP_BIT =>
                        if tick_16x = '1' then
                            if tick_cnt = 15 then -- Jsme uprostřed Stop bitu
                                -- Zapíšeme výsledek na výstup a vystřelíme valid pulz
                                rx_data  <= shift_reg;
                                rx_valid <= '1';
                                state    <= IDLE;
                            else
                                tick_cnt <= tick_cnt + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;