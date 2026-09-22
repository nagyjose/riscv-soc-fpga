#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_irq.h"
#include "hal_uart.h"
#include "hal_gpio.h"
#include "hal_mtime.h"
#include "hal_pwm.h"
#include "hal_stepper.h"

// ============================================================================
// GLOBÁLNÍ STAVY PRO CALLBACKY
// ============================================================================
volatile uint32_t uptime_seconds = 0;
volatile uint16_t duty_val = 10;
volatile int16_t  duty_step = 5;
volatile uint8_t  motor_dir = STEP_DIR_FWD;

// ============================================================================
// 1. CALLBACK: SYSTÉMOVÝ ČASOVAČ (MTIME) - Volá se každou 1 vteřinu
// ============================================================================
void my_mtime_cb(void) {
    uptime_seconds++;
    
    uart_puts(HW_UART, "[MTIME] Uptime: ");
    // Rychlý trik pro výpis malého čísla (do 9) bez složitého sprintf
    uart_putc(HW_UART, '0' + (uptime_seconds % 10)); 
    uart_puts(HW_UART, " s\r\n");

    // Naplánujeme další tik přesně za 1 000 000 mikrosekund
    mtime_set_compare_relative(HW_MTIME, 1000000);
}

// ============================================================================
// 2. CALLBACK: UART RX - Volá se při každém přijatém znaku
// ============================================================================
void my_uart_cb(void) {
    char c = uart_getc(HW_UART); // Smaže HW FIFO příznak
    uart_putc(HW_UART, '[');
    uart_putc(HW_UART, c);
    uart_putc(HW_UART, ']');
}

// ============================================================================
// 3. CALLBACK: GPIO TLAČÍTKO - Volá se při sestupné hraně na Pinu 0
// ============================================================================
void my_gpio_cb(void) {
    if (gpio_irq_get_pending(HW_GPIO) & (1 << 0)) {
        gpio_irq_clear(HW_GPIO, 0); // Zásadní: smazat W1C příznak

        // Obrátíme směr motoru
        motor_dir = (motor_dir == STEP_DIR_FWD) ? STEP_DIR_BWD : STEP_DIR_FWD;
        stepper_run(HW_STEPPER, 0, motor_dir);
        
        uart_puts(HW_UART, "\r\n[GPIO] Smer motoru obracen!\r\n");
    }
}

// ============================================================================
// 4. CALLBACK: PWM TIMER 1 - Volá se 10 000x za vteřinu (10 kHz)
// ============================================================================
void my_pwm_cb(void) {
    duty_val += duty_step;
    if (duty_val >= 990 || duty_val <= 10) {
        duty_step = -duty_step; 
    }
    pwm_set_duty(HW_TIMER1, duty_val);
}

// ============================================================================
// HLAVNÍ PROGRAM
// ============================================================================
int main(void) {
    // 1. INICIALIZACE PERIFERIÍ
    uart_init(HW_UART, 35000000, 115200);
    gpio_set_dir(HW_GPIO, 0, GPIO_DIR_IN); // Tlačítko
    pwm_init(HW_TIMER1, 34, 1000);         // 10 kHz pro dýchání
    stepper_set_speed(HW_STEPPER, 0, 150); // Motor 0
    
    // 2. REGISTRACE DO DISPEČERU (hal_irq.c)
    irq_init();
    irq_register_timer(my_mtime_cb);
    irq_register_uart(my_uart_cb);
    irq_register_gpio(my_gpio_cb);
    irq_register_pwm1(my_pwm_cb);

    // 3. NASTAVENÍ HARDWAROVÝCH SPOUŠTÍ
    mtime_set_compare_relative(HW_MTIME, 1000000);      // První tik MTIME
    gpio_irq_enable(HW_GPIO, 0, GPIO_EDGE_FALLING);     // Hrana pro GPIO
    pwm_irq_enable(HW_TIMER1);                          // IRQ pro PWM

    // 4. START ZAŘÍZENÍ
    stepper_run(HW_STEPPER, 0, motor_dir);
    pwm_enable(HW_TIMER1);

    uart_puts(HW_UART, "\r\n======================================\r\n");
    uart_puts(HW_UART, " RISC-V SoC: ULTIMATE IRQ STRESS TEST \r\n");
    uart_puts(HW_UART, "======================================\r\n");
    
    // 5. POVOLENÍ JÁDRA A SPÁNEK
    cpu_irq_enable();

    // Veškerá logika teď běží v Interrupt Service Routines (ISR).
    // Dispečer skáče od motorů přes UART až po PWM s naprostou přesností.
    while (1) {
        // Zde by mohla být instrukce WFI (Wait For Interrupt)
    }

    return 0;
}