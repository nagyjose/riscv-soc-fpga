#ifndef HAL_PWM_H
#define HAL_PWM_H

#include <stdint.h>
#include <stdbool.h>
#include "soc_map.h" // Obsahuje definici pwm_regs_t a HW_TIMER1 / HW_TIMER2

// ============================================================================
// INICIALIZACE A ŘÍZENÍ PWM
// ============================================================================

// Inicializuje časovač: nastaví děličku a periodu (strop čítače)
void pwm_init(pwm_regs_t* timer, uint16_t prescaler, uint16_t period);

// Nastaví novou střídu (duty cycle) – musí být menší nebo rovna periodě
void pwm_set_duty(pwm_regs_t* timer, uint16_t duty);

// Zapne / Vypne časovač
void pwm_enable(pwm_regs_t* timer);
void pwm_disable(pwm_regs_t* timer);

// ============================================================================
// OBSLUHA PŘERUŠENÍ
// ============================================================================

// Povolí generování vnějšího přerušení od tohoto časovače
void pwm_irq_enable(pwm_regs_t* timer);
void pwm_irq_disable(pwm_regs_t* timer);

// Zjistí, zda časovač dosáhl konce periody a čeká na obsluhu
bool pwm_irq_is_pending(pwm_regs_t* timer);

// Smaže příznak přerušení
void pwm_irq_clear(pwm_regs_t* timer);

#endif // HAL_PWM_H