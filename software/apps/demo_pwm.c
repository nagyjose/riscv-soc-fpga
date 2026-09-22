#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_irq.h"
#include "hal_pwm.h"
#include "hal_uart.h"

// Globální proměnné pro "Sweep" (dýchání) LED
volatile uint16_t duty_val = 10;
volatile int16_t  duty_step = 5;

// ============================================================================
// UŽIVATELSKÝ CALLBACK PRO TIMER 1
// ============================================================================
// Volá se po každém dokončení periody Timeru 1 (při 10 kHz to je 10 000x za vteřinu)
void my_pwm1_callback(void) {
    // 1. Změníme hodnotu střídy
    duty_val += duty_step;
    
    // 2. Obrátíme směr, pokud jsme narazili na limit
    if (duty_val >= 990 || duty_val <= 10) {
        duty_step = -duty_step; 
    }
    
    // 3. Pošleme novou střídu do hardwaru
    // Hardware (VHDL komparátor) se postará o fyzickou změnu na pinu bez glitchů
    pwm_set_duty(HW_TIMER1, duty_val);
}

// ============================================================================
// HLAVNÍ PROGRAM
// ============================================================================
int main(void) {
    uart_init(HW_UART, 35000000, 115200);
    irq_init();

    // ---------------------------------------------------------
    // NASTAVENÍ TIMER 1 (Dýchající LED + Přerušení)
    // ---------------------------------------------------------
    // Cílová PWM frekvence: 10 kHz. Systémové hodiny: 35 MHz.
    // Prescaler nastavíme na 34 (dělička 35) -> Čítač tiká na 1 MHz (1 us).
    // Perioda 100 tiků -> 100 us -> 10 000 Hz.
    pwm_init(HW_TIMER1, 34, 1000); 
    pwm_set_duty(HW_TIMER1, duty_val);
    
    // Zaregistrujeme naši C funkci pro sweep efekt
    irq_register_pwm1(my_pwm1_callback);
    
    // Povolíme HW přerušení z tohoto konkrétního časovače
    pwm_irq_enable(HW_TIMER1);

    // ---------------------------------------------------------
    // NASTAVENÍ TIMER 2 (Blikající LED, plně řízeno HW)
    // ---------------------------------------------------------
    // Zkusíme blikání 2x za vteřinu (2 Hz).
    // Prescaler 34 999 (dělička 35 000) -> Čítač tiká na 1000 Hz (1 ms).
    // Perioda 500 tiků -> 500 ms -> 2 Hz.
    pwm_init(HW_TIMER2, 34999, 500);
    
    // Střída 250 = 50 % času svítí, 50 % nesvítí
    pwm_set_duty(HW_TIMER2, 250); 
    
    // Pro Timer 2 schválně NEZAPNEME přerušení. Hardware (pwm_timer.vhd) bude
    // ovládat fyzický výstupní pin úplně sám bez pomoci procesoru.

    // ---------------------------------------------------------
    // START
    // ---------------------------------------------------------
    uart_puts(HW_UART, "\r\n=================================\r\n");
    uart_puts(HW_UART, " SDK Demo 3: HW PWM Timery\r\n");
    uart_puts(HW_UART, "=================================\r\n");
    uart_puts(HW_UART, "Timer 1: 10 kHz (Dychani pres IRQ)\r\n");
    uart_puts(HW_UART, "Timer 2: 2 Hz (Hardware auto-toggle)\r\n");

    cpu_irq_enable(); // Povolit přerušení globálně

    // Spuštění obou časovačů
    pwm_enable(HW_TIMER1);
    pwm_enable(HW_TIMER2);

    while (1) {
        // Hlavní smyčka nedělá absolutně nic.
        // Timer 1 dýchá díky přerušení.
        // Timer 2 bliká díky VHDL komparátoru.
    }
    
    return 0;
}