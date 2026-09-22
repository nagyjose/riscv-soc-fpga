#ifndef HAL_GPIO_H
#define HAL_GPIO_H

#include <stdint.h>
#include <stdbool.h>
#include "soc_map.h"

// Nastavení směru
#define GPIO_DIR_IN       0
#define GPIO_DIR_OUT      1

// Nastavení hrany pro přerušení
#define GPIO_EDGE_RISING  0
#define GPIO_EDGE_FALLING 1

// ============================================================================
// ZÁKLADNÍ I/O OPERACE
// ============================================================================
void gpio_set_dir(gpio_regs_t* gpio, uint8_t pin, uint8_t dir);
void gpio_set_dir_mask(gpio_regs_t* gpio, uint32_t mask, uint8_t dir); // Hromadné nastavení

void gpio_write_pin(gpio_regs_t* gpio, uint8_t pin, bool val);
void gpio_write_port(gpio_regs_t* gpio, uint32_t val);
void gpio_toggle_pin(gpio_regs_t* gpio, uint8_t pin);

bool gpio_read_pin(gpio_regs_t* gpio, uint8_t pin);
uint32_t gpio_read_port(gpio_regs_t* gpio);

// ============================================================================
// OBSLUHA PŘERUŠENÍ
// ============================================================================
void gpio_irq_enable(gpio_regs_t* gpio, uint8_t pin, uint8_t edge);
void gpio_irq_disable(gpio_regs_t* gpio, uint8_t pin);
void gpio_irq_clear(gpio_regs_t* gpio, uint8_t pin);
uint32_t gpio_irq_get_pending(gpio_regs_t* gpio);

#endif // HAL_GPIO_H