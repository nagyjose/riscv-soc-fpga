#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_irq.h"
#include "hal_uart.h"
#include "hal_gpio.h"
#include "hal_mtime.h"
#include "hal_pwm.h"
#include "hal_stepper.h"
#include "hal_spi.h"

#define SENSOR_CS_PIN 2

// ============================================================================
// GLOBÁLNÍ SDÍLENÉ STAVY (Vlajky pro hlavní smyčku a sdílená data)
// ============================================================================
volatile bool     flag_read_sensor = false; // Vlajka pro SPI
volatile uint8_t  motor_dir = STEP_DIR_FWD;
volatile uint16_t duty_val  = 10;
volatile int16_t  duty_step = 5;

// ============================================================================
// BLESKOVÉ CALLBACKY (Běží na pozadí, nesmí blokovat!)
// ============================================================================
void cb_mtime(void) {
    // Pouze zvedneme vlajku pro hlavní smyčku a naplánujeme další tik za 500 ms
    flag_read_sensor = true;
    mtime_set_compare_relative(HW_MTIME, 500000); 
}

void cb_uart(void) {
    // Okamžité echo
    uart_putc(HW_UART, uart_getc(HW_UART));
}

void cb_gpio(void) {
    if (gpio_irq_get_pending(HW_GPIO) & (1 << 0)) {
        gpio_irq_clear(HW_GPIO, 0); 
        // Okamžitý obrat směru všech motorů
        motor_dir = (motor_dir == STEP_DIR_FWD) ? STEP_DIR_BWD : STEP_DIR_FWD;
        stepper_run(HW_STEPPER, 0, motor_dir);
        stepper_run(HW_STEPPER, 1, motor_dir);
    }
}

void cb_pwm(void) {
    // Hardwarové "dýchání" na pozadí (10 000x za vteřinu)
    duty_val += duty_step;
    if (duty_val >= 990 || duty_val <= 10) duty_step = -duty_step; 
    pwm_set_duty(HW_TIMER1, duty_val);
}

// ============================================================================
// HLAVNÍ PROGRAM
// ============================================================================
int main(void) {
    // 1. INICIALIZACE VŠECH PERIFERIÍ
    uart_init(HW_UART, 35000000, 115200);
    spi_init(HW_SPI, 35000000, 1000000);
    pwm_init(HW_TIMER1, 34, 1000);
    
    gpio_set_dir(HW_GPIO, 0, GPIO_DIR_IN);              // Tlačítko
    gpio_set_dir(HW_GPIO, SENSOR_CS_PIN, GPIO_DIR_OUT); // CS pro SPI
    gpio_write_pin(HW_GPIO, SENSOR_CS_PIN, 1);
    
    stepper_set_speed(HW_STEPPER, 0, 150);
    stepper_set_speed(HW_STEPPER, 1, 150);

    // 2. REGISTRACE PŘERUŠENÍ
    irq_init();
    irq_register_timer(cb_mtime);
    irq_register_uart(cb_uart);
    irq_register_gpio(cb_gpio);
    irq_register_pwm1(cb_pwm);

    // 3. START HARDWARU A POVOLENÍ IRQ
    mtime_set_compare_relative(HW_MTIME, 500000);
    gpio_irq_enable(HW_GPIO, 0, GPIO_EDGE_FALLING);
    pwm_irq_enable(HW_TIMER1);
    
    stepper_run(HW_STEPPER, 0, motor_dir);
    stepper_run(HW_STEPPER, 1, motor_dir);
    pwm_enable(HW_TIMER1);
    
    cpu_irq_enable();
    uart_puts(HW_UART, "\r\n[ SYSTEM START ] Vsechny periferie aktivni.\r\n");

    // 4. HLAVNÍ SMYČKA (Zpracování pomalých událostí)
    while (1) {
        if (flag_read_sensor) {
            flag_read_sensor = false; // Shodíme vlajku
            
            // Bezpečná blokující SPI komunikace mimo přerušení
            gpio_write_pin(HW_GPIO, SENSOR_CS_PIN, 0);
            uint8_t sensor_data = spi_transfer(HW_SPI, 0x00);
            gpio_write_pin(HW_GPIO, SENSOR_CS_PIN, 1);
            
            // Výpis na UART (taktéž mimo přerušení, takže nezdržíme motory ani PWM)
            uart_puts(HW_UART, "Data ze senzoru: ");
            uart_putc(HW_UART, '0' + (sensor_data % 10)); // Zjednodušený výpis
            uart_puts(HW_UART, "\r\n");
        }
        
        // Zbytek času může procesor uspat přes instrukci WFI, 
        // nebo tu může běžet PID regulátor motorů, zpracování GPS atd.
    }
    
    return 0;
}