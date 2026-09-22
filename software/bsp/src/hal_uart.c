#include "hal_uart.h"

void uart_init(uart_regs_t* uart, uint32_t sys_clk_hz, uint32_t baud_rate) {
    uart->BAUD = sys_clk_hz / baud_rate; 
}

void uart_putc(uart_regs_t* uart, char c) {
    // Bit 0 v UART_STATUS hlásí připravenost vysílače (1 = Ready, 0 = Busy)
    while ((uart->STATUS & 0x01) == 0); // Čekáme, dokud HW nedokončí odesílání předchozího znaku
    uart->DATA = c; 
}

void uart_puts(uart_regs_t* uart, const char* str) {
    while (*str) {
        uart_putc(uart, *str++);
    }
}

bool uart_data_available(uart_regs_t* uart) {
    // Bit 1 v UART_STATUS je '1', pokud je ve FIFO alespoň jeden přijatý znak
    return (uart->STATUS & 0x02) != 0;
}

char uart_getc(uart_regs_t* uart) {
    // Blokující čekání - nepustí procesor dál, dokud něco nepřijde
    while (!uart_data_available(uart));
    // Přečtením z 0x40001000 se znak hardwarově vyjme z FIFO a případně smaže IRQ
    return (char)uart->DATA; 
}