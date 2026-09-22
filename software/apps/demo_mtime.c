#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_irq.h"
#include "hal_mtime.h"
#include "hal_gpio.h"
#include "hal_uart.h"

// ============================================================================
// UŽIVATELSKÝ CALLBACK PRO SYSTÉMOVÝ ČASOVAČ (MTIME)
// ============================================================================

// Tento callback běží plně asynchronně na pozadí, když "zazvoní budík"
void my_timer_callback(void) {
    // 1. Změníme stav LEDky na Pinu 1
    gpio_toggle_pin(HW_GPIO, 1);

    // 2. KLÍČOVÝ KROK: Naplánujeme další zvonění za 100 000 mikrosekund (100 ms)
    mtime_set_compare_relative(HW_MTIME, 100000); 
}

// ============================================================================
// HLAVNÍ PROGRAM
// ============================================================================

int main(void) {
    // 1. Inicializace hardwaru
    uart_init(HW_UART, 35000000, 115200);
    
    // Piny 1 a 2 budou výstupy (pro dvě různé LEDky)
    gpio_set_dir(HW_GPIO, 1, GPIO_DIR_OUT);
    gpio_set_dir(HW_GPIO, 2, GPIO_DIR_OUT);

    // 2. Registrace callbacku a spuštění přerušení
    irq_init();
    irq_register_timer(my_timer_callback);

    // Nastavíme první asynchronní tik za 100 ms od této chvíle
    mtime_set_compare_relative(HW_MTIME, 100000);

    // Zapneme přerušení v jádře
    cpu_irq_enable();

    // 3. Uvítací zpráva
    uart_puts(HW_UART, "\r\n====================================\r\n");
    uart_puts(HW_UART, " SDK Demo 2: MTIME (Budik i Delay)\r\n");
    uart_puts(HW_UART, "====================================\r\n");
    uart_puts(HW_UART, "LED na pinu 1 blika asynchronne (IRQ) kazdych 100 ms.\r\n");
    uart_puts(HW_UART, "Hlavni smycka blika LED na pinu 2 kazdych 1000 ms.\r\n");

    // 4. Hlavní smyčka
    while (1) {
        // Hlavní program používá hloupé blokující čekání.
        // Díky hardwarovému přerušení to ale rychlému blikání na pinu 1 vůbec nevadí!
        
        gpio_write_pin(HW_GPIO, 2, 1);
        uart_puts(HW_UART, "Tik...\r\n");
        mtime_delay_ms(HW_MTIME, 1000); // Zablokuje hlavní program na 1 sekundu
        
        gpio_write_pin(HW_GPIO, 2, 0);
        uart_puts(HW_UART, "Tak...\r\n");
        mtime_delay_ms(HW_MTIME, 1000); // Zablokuje hlavní program na 1 sekundu
    }
    
    return 0;
}