#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_irq.h"
#include "hal_gpio.h"
#include "hal_uart.h"

// ============================================================================
// UŽIVATELSKÉ CALLBACKY PRO PŘERUŠENÍ
// ============================================================================

// Zavolá se automaticky hardvérem, když přijde jakýkoliv znak přes RX pin
void my_uart_callback(void) {
    // 1. Přečtením znaku se z HW FIFO odstraní a IRQ se samo vymaže
    char c = uart_getc(HW_UART); 
    
    // 2. Pošleme ho zpět v hranatých závorkách (Echo)
    uart_putc(HW_UART, '[');
    uart_putc(HW_UART, c);
    uart_putc(HW_UART, ']');
    
    // 3. Při každém stisku klávesy překlopíme stav výstupního pinu 1 (LED)
    gpio_toggle_pin(HW_GPIO, 1);
}

// Zavolá se automaticky, když se na GPIO objeví hrana (stisk tlačítka)
void my_gpio_callback(void) {
    // Zjistíme, který pin přerušení vyvolal
    uint32_t pending = gpio_irq_get_pending(HW_GPIO);
    
    // Bylo to naše tlačítko na Pinu 0?
    if (pending & (1 << 0)) {
        uart_puts(HW_UART, "\r\n[IRQ] Tlacitko na Pinu 0 bylo stisknuto!\r\n");
        
        // Zásadní krok: Smažeme příznak přerušení, jinak se tu zacyklíme!
        gpio_irq_clear(HW_GPIO, 0);
    }
}

// ============================================================================
// HLAVNÍ PROGRAM
// ============================================================================

int main(void) {
    // 1. Inicializace hardwaru
    uart_init(HW_UART, 35000000, 115200);
    
    // Pin 0 bude VSTUP (tlačítko), Pin 1 bude VÝSTUP (LED)
    gpio_set_dir(HW_GPIO, 0, GPIO_DIR_IN);
    gpio_set_dir(HW_GPIO, 1, GPIO_DIR_OUT);
    
    // 2. Registrace našich C funkcí do centrálního IRQ dispečeru
    irq_init();
    irq_register_uart(my_uart_callback);
    irq_register_gpio(my_gpio_callback);

    // 3. Nastavení hardwarového přerušení pro Pin 0 (Reakce na sestupnou hranu)
    gpio_irq_enable(HW_GPIO, 0, GPIO_EDGE_FALLING);

    // 4. Zapnutí globálních přerušení v RISC-V jádře
    cpu_irq_enable();

    // 5. Uvítací zpráva
    uart_puts(HW_UART, "\r\n=================================\r\n");
    uart_puts(HW_UART, " SDK Demo 1: GPIO & UART (IRQ)\r\n");
    uart_puts(HW_UART, "=================================\r\n");
    uart_puts(HW_UART, "Napis neco na klavesnici, nebo stiskni HW tlacitko.\r\n");

    // 6. Nekonečná smyčka
    // Procesor se zde může nudit, veškerá práce se děje asynchronně v callbacích!
    while (1) {
        // Tady by mohl běžet nějaký složitý výpočet...
    }
    
    return 0;
}