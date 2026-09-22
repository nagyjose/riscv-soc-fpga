#ifndef HAL_IRQ_H
#define HAL_IRQ_H

#include <stdint.h>

// Inicializace systému přerušení (nastaví adresu trap_handleru)
void irq_init(void);

// Typ pro uživatelskou (callback) funkci
typedef void (*irq_callback_t)(void);

// Registrace callbacků pro jednotlivé periferie
void irq_register_timer(irq_callback_t callback);
void irq_register_uart(irq_callback_t callback);
void irq_register_gpio(irq_callback_t callback);

#endif // HAL_IRQ_H