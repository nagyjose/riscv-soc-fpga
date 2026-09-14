library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Sběrnicové rozhraní uvnitř UART modulu
        tx_start : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        baud_div : in  std_logic_vector(15 downto 0); -- Např. hodnota 868
        
        -- Fyzický pin a stav pro procesor
        tx_pin   : out std_logic;
        tx_ready : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is
    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_t;
    
    signal clk_div   : unsigned(15 downto 0);
    signal bit_idx   : integer range 0 to 7;
    signal shift_reg : std_logic_vector(7 downto 0);
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= IDLE;
                tx_pin   <= '1'; -- Klidový stav sériové linky je HIGH
                tx_ready <= '1';
                clk_div  <= (others => '0');
                bit_idx  <= 0;
            else
                case state is
                    when IDLE =>
                        tx_ready <= '1';
                        tx_pin   <= '1';
                        -- Čekáme na příkaz k odeslání od procesoru
                        if tx_start = '1' then
                            shift_reg <= tx_data;
                            tx_ready  <= '0';
                            clk_div   <= (others => '0');
                            state     <= START_BIT;
                        end if;
                        
                    when START_BIT =>
                        tx_pin <= '0'; -- Start bit (LOW)
                        if clk_div = unsigned(baud_div) - 1 then
                            clk_div <= (others => '0');
                            bit_idx <= 0;
                            state   <= DATA_BITS;
                        else
                            clk_div <= clk_div + 1;
                        end if;
                        
                    when DATA_BITS =>
                        tx_pin <= shift_reg(bit_idx); -- LSB odesíláme jako první
                        if clk_div = unsigned(baud_div) - 1 then
                            clk_div <= (others => '0');
                            if bit_idx = 7 then
                                state <= STOP_BIT;
                            else
                                bit_idx <= bit_idx + 1;
                            end if;
                        else
                            clk_div <= clk_div + 1;
                        end if;
                        
                    when STOP_BIT =>
                        tx_pin <= '1'; -- Stop bit (HIGH)
                        if clk_div = unsigned(baud_div) - 1 then
                            state <= IDLE;
                        else
                            clk_div <= clk_div + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;