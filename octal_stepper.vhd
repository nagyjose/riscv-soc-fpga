library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity octal_stepper is
    generic (
        SYS_CLK_FREQ : integer := 35000000 -- Výchozí systémové hodiny
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;

        -- Sběrnicové rozhraní (Pouze Zápis!)
        cs         : in  std_logic;
        wr_en      : in  std_logic;
        addr       : in  std_logic_vector(2 downto 0); -- Až 8 adres (my využijeme 5)
        wr_data    : in  std_logic_vector(31 downto 0);
        
        -- Fyzické piny pro 8 motorů (8 * 4 = 32 pinů)
        motor_pins : out std_logic_vector(31 downto 0)
    );
end entity octal_stepper;

architecture rtl of octal_stepper is

    -- Konstanty pro časovou základnu (10 us Tick = 100 kHz)
    constant PRESCALER_TOP : integer := (SYS_CLK_FREQ / 100000) - 1;

    -- Paměťová mapa a uživatelské registry
    signal r_global_ctrl : std_logic_vector(15 downto 0);
    
    type speed_array_t is array (0 to 7) of unsigned(15 downto 0);
    signal r_speed       : speed_array_t;

    -- Vnitřní čítače a stavy
    signal prescaler_cnt : integer range 0 to PRESCALER_TOP;
    signal tick_10us     : std_logic;

    type timer_array_t is array (0 to 7) of unsigned(15 downto 0);
    signal timer         : timer_array_t;

    type step_idx_array_t is array (0 to 7) of integer range 0 to 7;
    signal step_idx      : step_idx_array_t;

    -- Kruhová paměť pro Half-Step sekvenci ULN2003
    type step_lut_t is array (0 to 7) of std_logic_vector(3 downto 0);
    constant SEQ_HALFSTEP : step_lut_t := (
        "1000", "1100", "0100", "0110", "0010", "0011", "0001", "1001"
    );

begin

    process(clk)
        variable enable : std_logic;
        variable dir    : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_global_ctrl <= (others => '0');
                for i in 0 to 7 loop
                    r_speed(i)  <= to_unsigned(100, 16); -- Default 1 ms
                    timer(i)    <= (others => '0');
                    step_idx(i) <= 0;
                end loop;
                prescaler_cnt <= 0;
                tick_10us     <= '0';
                motor_pins    <= (others => '0');
            else
                -- =========================================================
                -- 1. ZÁPIS ZE SBĚRNICE
                -- =========================================================
                if cs = '1' and wr_en = '1' then
                    case addr is
                        when "000" => 
                            r_global_ctrl <= wr_data(15 downto 0);
                        when "001" => 
                            r_speed(0) <= unsigned(wr_data(15 downto 0));
                            r_speed(1) <= unsigned(wr_data(31 downto 16));
                        when "010" => 
                            r_speed(2) <= unsigned(wr_data(15 downto 0));
                            r_speed(3) <= unsigned(wr_data(31 downto 16));
                        when "011" => 
                            r_speed(4) <= unsigned(wr_data(15 downto 0));
                            r_speed(5) <= unsigned(wr_data(31 downto 16));
                        when "100" => 
                            r_speed(6) <= unsigned(wr_data(15 downto 0));
                            r_speed(7) <= unsigned(wr_data(31 downto 16));
                        when others => null;
                    end case;
                end if;

                -- =========================================================
                -- 2. GENERÁTOR ČASOVÉ ZÁKLADNY (10 us Tick)
                -- =========================================================
                if prescaler_cnt = PRESCALER_TOP then
                    prescaler_cnt <= 0;
                    tick_10us     <= '1';
                else
                    prescaler_cnt <= prescaler_cnt + 1;
                    tick_10us     <= '0';
                end if;

                -- =========================================================
                -- 3. NEZÁVISLÉ STAVOVÉ AUTOMATY PRO 8 MOTORŮ
                -- =========================================================
                for i in 0 to 7 loop
                    -- Extrakce bitů Enable a Směru z globálního registru
                    enable := r_global_ctrl(i * 2);
                    dir    := r_global_ctrl((i * 2) + 1);

                    if enable = '1' then
                        -- Vystavení fyzických pinů (každý motor má své 4 bity ve velkém vektoru)
                        motor_pins((i * 4) + 3 downto (i * 4)) <= SEQ_HALFSTEP(step_idx(i));

                        -- Posun kroku pouze, když odbije společný 10us tick
                        if tick_10us = '1' then
                            if timer(i) = r_speed(i) then
                                timer(i) <= (others => '0');
                                
                                -- Rotace indexu dle směru
                                if dir = '0' then
                                    if step_idx(i) = 7 then step_idx(i) <= 0; else step_idx(i) <= step_idx(i) + 1; end if;
                                else
                                    if step_idx(i) = 0 then step_idx(i) <= 7; else step_idx(i) <= step_idx(i) - 1; end if;
                                end if;
                            else
                                timer(i) <= timer(i) + 1;
                            end if;
                        end if;
                    else
                        -- Motor je vypnutý -> Všechny cívky bez proudu
                        motor_pins((i * 4) + 3 downto (i * 4)) <= "0000";
                        timer(i) <= (others => '0');
                    end if;
                end loop;
            end if;
        end if;
    end process;

end architecture rtl;