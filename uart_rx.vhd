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
    signal clk_div  : unsigned(15 downto 0);
    
    -- Čítače a registry
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
    -- 2. HLAVNÍ PŘIJÍMACÍ AUTOMAT
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= IDLE;
                rx_valid <= '0';
                rx_data  <= (others => '0');
                clk_div  <= (others => '0');
                bit_idx  <= 0;
            else
                rx_valid <= '0';
                
                case state is
                    when IDLE =>
                        bit_idx <= 0;
                        if rx_sync2 = '0' then
                            -- Posuneme se přesně do poloviny Start bitu (baud_div / 2)
                            clk_div <= unsigned("0" & baud_div(15 downto 1)); 
                            state   <= START_BIT;
                        end if;
                        
                    when START_BIT =>
                        if clk_div = 0 then
                            if rx_sync2 = '0' then
                                -- Jsme uprostřed, nabijeme čítač na celý jeden bit
                                clk_div <= unsigned(baud_div) - 1;
                                state   <= DATA_BITS;
                            else
                                state <= IDLE; -- Šum, vracíme se
                            end if;
                        else
                            clk_div <= clk_div - 1;
                        end if;
                        
                    when DATA_BITS =>
                        if clk_div = 0 then
                            shift_reg(bit_idx) <= rx_sync2;
                            clk_div <= unsigned(baud_div) - 1;
                            
                            if bit_idx = 7 then
                                state <= STOP_BIT;
                            else
                                bit_idx <= bit_idx + 1;
                            end if;
                        else
                            clk_div <= clk_div - 1;
                        end if;
                        
                    when STOP_BIT =>
                        if clk_div = 0 then
                            rx_data  <= shift_reg;
                            rx_valid <= '1';
                            state    <= IDLE;
                        else
                            clk_div <= clk_div - 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;