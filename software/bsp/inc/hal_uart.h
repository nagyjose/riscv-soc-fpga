#ifndef HAL_UART_H
#define HAL_UART_H

#include <stdint.h>
#include <stdbool.h>
#include "soc_map.h"

// Inicializace rychlosti UARTu (nastaví děličku na základě frekvence CPU)
void uart_init(uart_regs_t* uart, uint32_t sys_clk_hz, uint32_t baud_rate);

// Vysílání
void uart_putc(uart_regs_t* uart, char c);
void uart_puts(uart_regs_t* uart, const char* str);

// Příjem
bool uart_data_available(uart_regs_t* uart);
char uart_getc(uart_regs_t* uart);

#endif // HAL_UART_H