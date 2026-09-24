library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
    generic (
        SYS_CLK_FREQ : integer := 35000000;
        BAUD_RATE    : integer := 115200
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;

        -- ==========================================================
        -- Sběrnicové rozhraní (MMIO)
        -- ==========================================================
        cs        : in  std_logic;
        wr_en     : in  std_logic;
        addr      : in  std_logic_vector(1 downto 0); -- "00" = DATA, "01" = STATUS, "10" = BAUD
        wr_data   : in  std_logic_vector(31 downto 0);
        rd_data   : out std_logic_vector(31 downto 0);
        
        -- ==========================================================
        -- Přerušení a Fyzické Piny
        -- ==========================================================
        irq_out   : out std_logic;
        rx_pin    : in  std_logic;
        tx_pin    : out std_logic
    );
end entity uart;

architecture rtl of uart is
    -- Vnitřní propojovací signály
    signal r_baud_div : std_logic_vector(15 downto 0);
    
    signal tx_start   : std_logic;
    signal tx_ready   : std_logic;
    
    signal rx_valid   : std_logic;
    signal rx_data    : std_logic_vector(7 downto 0);
    
    signal fifo_empty : std_logic;
    signal fifo_full  : std_logic;
    signal fifo_rd    : std_logic;
    signal fifo_dout  : std_logic_vector(7 downto 0);
    
    -- Registry pro uzamčení dat
    signal is_reading      : std_logic := '0';
    signal latched_rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal pop_active      : std_logic := '0';

begin

    -- ========================================================================
    -- 1. INSTANTIACE PODMODULŮ
    -- ========================================================================
    u_tx: entity work.uart_tx
        port map (
            clk      => clk,
            rst      => rst,
            tx_start => rx_valid, -- BYPASS: Odesílej, jakmile RX zachytí znak
            tx_data  => rx_data,  -- BYPASS: Znak přímo z RX
            --tx_start => tx_start,
            --tx_data  => wr_data(7 downto 0),
            baud_div => r_baud_div,
            tx_pin   => tx_pin,
            tx_ready => tx_ready
        );

    u_rx: entity work.uart_rx
        port map (
            clk      => clk,
            rst      => rst,
            baud_div => r_baud_div,
            rx_data  => rx_data,
            rx_valid => rx_valid,
            rx_pin   => rx_pin
        );

    u_fifo: entity work.uart_fifo
        generic map ( ADDR_WIDTH => 9 ) -- 512 Bytů
        port map (
            clk      => clk,
            rst      => rst,
            wr_en    => rx_valid,  -- Zapisuje modul RX
            wr_data  => rx_data,
            rd_en    => fifo_rd,   -- Čte procesor
            rd_data  => fifo_dout,
            empty    => fifo_empty,
            full     => fifo_full
        );

    -- ========================================================================
    -- 2. SBĚRNICOVÁ LOGIKA (Zápis z procesoru)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Výchozí dělička: 35 MHz / 115200 = 303
                r_baud_div <= std_logic_vector(to_unsigned(SYS_CLK_FREQ / BAUD_RATE, 16));
            else
                if cs = '1' and wr_en = '1' then
                    if addr = "10" then
                        r_baud_div <= wr_data(15 downto 0);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Kombinační start pro vysílač (Startuje přesně ve chvíli zápisu do registru 0x00)
    --tx_start <= '1' when (cs = '1' and wr_en = '1' and addr = "00") else '0';

    -- ========================================================================
    -- 3. SBĚRNICOVÁ LOGIKA (Bezpečné čtení a explicitní smazání přes zápis)
    -- ========================================================================
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fifo_rd    <= '0';
                pop_active <= '0';
            else
                -- Zápis jakékoliv hodnoty na adresu 0x01 (STATUS) bezpečně smaže znak z FIFO
                if cs = '1' and wr_en = '1' and addr = "01" then
                    if pop_active = '0' then
                        fifo_rd    <= '1'; 
                        pop_active <= '1'; -- Zámek proti vícetaktovému zápisu
                    else
                        fifo_rd    <= '0';
                    end if;
                else
                    fifo_rd    <= '0';
                    pop_active <= '0';
                end if;
            end if;
        end if;
    end process;

    process(addr, fifo_dout, tx_ready, fifo_empty, fifo_full, r_baud_div)
        variable status_reg : std_logic_vector(31 downto 0);
    begin
        status_reg := (others => '0');
        status_reg(0) := tx_ready;
        status_reg(1) := not fifo_empty;
        status_reg(2) := fifo_full;
        
        rd_data <= (others => '0');
        case addr is
            when "00" => rd_data(7 downto 0) <= fifo_dout; -- Nyní pouze bezpečně nahlížíme
            when "01" => rd_data <= status_reg;
            when "10" => rd_data(15 downto 0) <= r_baud_div;
            when others => null;
        end case;
    end process;

    -- ========================================================================
    -- 4. PŘERUŠENÍ
    -- ========================================================================
    -- Vyvolá Trap 11 pokaždé, když je ve FIFO aspoň jeden znak.
    -- Smaže se samo tím, že procesor vyčte z adresy 0x00 všechna data.
    irq_out <= not fifo_empty;

end architecture rtl;