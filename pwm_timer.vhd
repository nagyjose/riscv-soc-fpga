library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_timer is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;

        -- ==========================================================
        -- Sběrnicové rozhraní (MMIO)
        -- ==========================================================
        cs        : in  std_logic;
        wr_en     : in  std_logic;
        addr      : in  std_logic_vector(1 downto 0); -- "00"=CTRL, "01"=PRESCALER, "10"=PERIOD, "11"=DUTY
        wr_data   : in  std_logic_vector(31 downto 0);
        rd_data   : out std_logic_vector(31 downto 0);

        -- ==========================================================
        -- Výstupy periferie
        -- ==========================================================
        irq_out   : out std_logic;
        pwm_pin   : out std_logic
    );
end entity pwm_timer;

architecture rtl of pwm_timer is
    -- Hardwarové registry (viditelné pro procesor)
    signal r_enable    : std_logic;
    signal r_irq_en    : std_logic;
    signal r_irq_pend  : std_logic;
    signal r_prescaler : unsigned(15 downto 0);
    signal r_period    : unsigned(15 downto 0);
    signal r_duty      : unsigned(15 downto 0);

    -- Vnitřní čítače
    signal prescaler_cnt : unsigned(15 downto 0);
    signal timer_cnt     : unsigned(15 downto 0);
begin

    -- ========================================================================
    -- HLAVNÍ LOGIKA ČASOVAČE A ZÁPIS REGISTRŮ
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_enable      <= '0';
                r_irq_en      <= '0';
                r_irq_pend    <= '0';
                r_prescaler   <= (others => '0');
                r_period      <= (others => '1'); -- Výchozí stav 65535
                r_duty        <= (others => '0');
                prescaler_cnt <= (others => '0');
                timer_cnt     <= (others => '0');
            else
                -- 1. ZÁPIS ZE SBĚRNICE
                if cs = '1' and wr_en = '1' then
                    case addr is
                        when "00" =>
                            r_enable   <= wr_data(0);
                            r_irq_en   <= wr_data(1);
                            r_irq_pend <= wr_data(2); -- Céčko sem zapíše '0' pro smazání příznaku
                        when "01" =>
                            r_prescaler <= unsigned(wr_data(15 downto 0));
                        when "10" =>
                            r_period    <= unsigned(wr_data(15 downto 0));
                        when "11" =>
                            r_duty      <= unsigned(wr_data(15 downto 0));
                        when others => null;
                    end case;
                end if;

                -- 2. LOGIKA ČÍTÁNÍ
                if r_enable = '1' then
                    -- Krok 1: Předdělička
                    if prescaler_cnt >= r_prescaler then
                        prescaler_cnt <= (others => '0');
                        
                        -- Krok 2: Hlavní čítač
                        if timer_cnt >= r_period then
                            timer_cnt  <= (others => '0');
                            r_irq_pend <= '1'; -- HW událost: Nastalo přetečení (Konec periody)
                        else
                            timer_cnt  <= timer_cnt + 1;
                        end if;
                    else
                        prescaler_cnt <= prescaler_cnt + 1;
                    end if;
                else
                    -- Pokud je timer vypnutý, vyresetujeme čítače, ať příště startuje od nuly
                    prescaler_cnt <= (others => '0');
                    timer_cnt     <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- KOMPARÁTOR (Generování PWM a IRQ)
    -- ========================================================================
    -- Fyzický pin je v '1', pokud běžíme a čítač je menší než nastavená střída
    pwm_pin <= '1' when (timer_cnt < r_duty and r_enable = '1') else '0';

    -- Signál přerušení vystřelí ven, jen pokud je událost (pend) a je to povoleno (en)
    irq_out <= r_irq_pend and r_irq_en;

    -- ========================================================================
    -- ČTENÍ REGISTRŮ DO PROCESORU
    -- ========================================================================
    process(addr, r_enable, r_irq_en, r_irq_pend, r_prescaler, r_period, r_duty)
        variable ctrl_reg : std_logic_vector(31 downto 0);
    begin
        rd_data <= (others => '0');
        
        -- Složení stavového registru z bitů
        ctrl_reg := (others => '0');
        ctrl_reg(0) := r_enable;
        ctrl_reg(1) := r_irq_en;
        ctrl_reg(2) := r_irq_pend;

        case addr is
            when "00" => rd_data <= ctrl_reg;
            when "01" => rd_data(15 downto 0) <= std_logic_vector(r_prescaler);
            when "10" => rd_data(15 downto 0) <= std_logic_vector(r_period);
            when "11" => rd_data(15 downto 0) <= std_logic_vector(r_duty);
            when others => null;
        end case;
    end process;

end architecture rtl;