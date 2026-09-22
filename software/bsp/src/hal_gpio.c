#include "hal_gpio.h"

// ============================================================================
// ZÁKLADNÍ I/O OPERACE
// ============================================================================

void gpio_set_dir(gpio_regs_t* gpio, uint8_t pin, uint8_t dir) {
    if (dir == GPIO_DIR_OUT) gpio->DIR |= (1 << pin);
    else                     gpio->DIR &= ~(1 << pin);
}

void gpio_set_dir_mask(gpio_regs_t* gpio, uint32_t mask, uint8_t dir) {
    if (dir == GPIO_DIR_OUT) gpio->DIR |= mask;
    else                     gpio->DIR &= ~mask;
}

void gpio_write_pin(gpio_regs_t* gpio, uint8_t pin, bool val) {
    if (val) gpio->DATA |= (1 << pin);
    else     gpio->DATA &= ~(1 << pin);
}

void gpio_write_port(gpio_regs_t* gpio, uint32_t val) {
    // Zapíše stav celého 32bitového portu najednou
    gpio->DATA = val;
}

void gpio_toggle_pin(gpio_regs_t* gpio, uint8_t pin) {
    // RISC-V kompilátor s využitím rozšíření Zbb tohle přeloží do velmi efektivní instrukce
    gpio->DATA ^= (1 << pin);
}

bool gpio_read_pin(gpio_regs_t* gpio, uint8_t pin) {
    return (gpio->DATA & (1 << pin)) != 0;
}

uint32_t gpio_read_port(gpio_regs_t* gpio) {
    return gpio->DATA;
}

// ============================================================================
// OBSLUHA PŘERUŠENÍ
// ============================================================================

void gpio_irq_enable(gpio_regs_t* gpio, uint8_t pin, uint8_t edge) {
    // 1. Nastavíme požadovanou hranu
    if (edge == GPIO_EDGE_FALLING) gpio->IRQ_EDGE |= (1 << pin);
    else                           gpio->IRQ_EDGE &= ~(1 << pin);
    
    // 2. Pro jistotu smažeme starý visící příznak
    gpio_irq_clear(gpio, pin);
    
    // 3. Povolíme přerušení v masce
    gpio->IRQ_MASK |= (1 << pin);
}

void gpio_irq_disable(gpio_regs_t* gpio, uint8_t pin) {
    gpio->IRQ_MASK &= ~(1 << pin);
}

void gpio_irq_clear(gpio_regs_t* gpio, uint8_t pin) {
    // Díky Write-1-to-Clear logice ve VHDL stačí odeslat masku s jedničkou na daném pinu
    gpio->IRQ_PEND = (1 << pin);
}

uint32_t gpio_irq_get_pending(gpio_regs_t* gpio) {
    // Vrátí 32bitovou mapu pinů, které vyvolaly přerušení (a mají ho povolené)
    return gpio->IRQ_PEND & gpio->IRQ_MASK;
}