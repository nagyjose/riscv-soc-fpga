#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_irq.h"
#include "hal_uart.h"

// Tuto funkci zavolá dispečer KDYKOLIV přijde znak na UART
void my_uart_rx_callback(void) {
    // 1. Přečteme znak (čímž se hardwarově smaže IRQ)
    char c = uart_getc(); 
    
    // 2. Pošleme ho zpět (Echo)
    uart_putc('[');
    uart_putc(c);
    uart_putc(']');
}

int main(void) {
    // 1. Inicializace
    uart_init(35000000, 115200);
    irq_init();

    // 2. Registrace naší funkce k UART přerušení
    irq_register_uart(my_uart_rx_callback);

    // 3. Povolení přerušení na úrovni jádra
    cpu_irq_enable();

    uart_puts("SDK IRQ Demo startuje! Zmackni klavesu...\r\n");

    // 4. Hlavní smyčka může spát nebo dělat jinou práci
    while(1) {
        // Zde může běžet např. výpočet nebo řízení krokových motorů
    }
    
    return 0;
}