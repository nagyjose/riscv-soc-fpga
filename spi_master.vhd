library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    generic (
        SYS_CLK_FREQ : integer := 35000000;
        SPI_FREQ     : integer := 1000000
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;

        -- ==========================================================
        -- Sběrnicové rozhraní (MMIO)
        -- ==========================================================
        cs        : in  std_logic;
        wr_en     : in  std_logic;
        addr      : in  std_logic_vector(1 downto 0); -- "00"=DATA, "01"=STATUS, "10"=BAUD
        wr_data   : in  std_logic_vector(31 downto 0);
        rd_data   : out std_logic_vector(31 downto 0);

        -- ==========================================================
        -- Fyzické piny SPI sběrnice
        -- ==========================================================
        spi_sck   : out std_logic;
        spi_mosi  : out std_logic;
        spi_miso  : in  std_logic
    );
end entity spi_master;

architecture rtl of spi_master is
    type state_t is (IDLE, SCK_HIGH, SCK_LOW);
    signal state : state_t;

    signal r_baud_half : unsigned(15 downto 0);
    signal clk_cnt     : unsigned(15 downto 0);
    signal bit_cnt     : integer range 0 to 7;

    signal shift_reg   : std_logic_vector(7 downto 0);
    signal rx_bit      : std_logic;
    signal busy        : std_logic;
begin

    -- ========================================================================
    -- HLAVNÍ STAVOVÝ AUTOMAT (Generátor hodin a posuvný registr)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= IDLE;
                spi_sck     <= '0';
                spi_mosi    <= '0';
                busy        <= '0';
					 -- Automatický výpočet poloviční periody pro SCK
                r_baud_half <= to_unsigned(SYS_CLK_FREQ / (2 * SPI_FREQ), 16);
                shift_reg   <= (others => '0');
                clk_cnt     <= (others => '0');
                bit_cnt     <= 0;
                rx_bit      <= '0';
            else
                -- Zápis konfigurace do registru BAUD (0x08)
                if cs = '1' and wr_en = '1' and addr = "10" then
                    r_baud_half <= unsigned(wr_data(15 downto 0));
                end if;

                case state is
                    when IDLE =>
                        spi_sck <= '0';
                        busy    <= '0';
                        
                        -- Zápis do DATA (0x00) odstartuje přenos
                        if cs = '1' and wr_en = '1' and addr = "00" then
                            shift_reg <= wr_data(7 downto 0);
                            spi_mosi  <= wr_data(7); -- MSB jde ven jako první
                            busy      <= '1';
                            clk_cnt   <= (others => '0');
                            bit_cnt   <= 0;
                            state     <= SCK_HIGH;
                        end if;

                    when SCK_HIGH =>
                        -- Čekáme poloviční periodu, náběžná hrana SCK -> Vzorkujeme MISO
                        if clk_cnt = r_baud_half - 1 then
                            spi_sck <= '1';
                            rx_bit  <= spi_miso; -- Uložíme si přečtený bit
                            clk_cnt <= (others => '0');
                            state   <= SCK_LOW;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when SCK_LOW =>
                        -- Sestupná hrana SCK -> Zapíšeme bit a posuneme MOSI
                        if clk_cnt = r_baud_half - 1 then
                            spi_sck   <= '0';
                            -- Posun doleva a připojení nového bitu na LSB pozici
                            shift_reg <= shift_reg(6 downto 0) & rx_bit; 
                            clk_cnt   <= (others => '0');

                            if bit_cnt = 7 then
                                state <= IDLE; -- 8 bitů odesláno
                            else
                                spi_mosi <= shift_reg(6); -- Vystavení nového bitu
                                bit_cnt  <= bit_cnt + 1;
                                state    <= SCK_HIGH;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- SBĚRNICOVÝ MULTIPLEXER (Čtení registrů do CPU)
    -- ========================================================================
    process(addr, shift_reg, busy, r_baud_half)
    begin
        rd_data <= (others => '0');
        case addr is
            when "00" => rd_data(7 downto 0)  <= shift_reg;
            when "01" => rd_data(0)           <= busy;
            when "10" => rd_data(15 downto 0) <= std_logic_vector(r_baud_half);
            when others => null;
        end case;
    end process;

end architecture rtl;