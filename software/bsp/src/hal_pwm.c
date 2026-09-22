#include "hal_pwm.h"

// Definice bitů pro řídicí registr (CTRL)
#define PWM_CTRL_EN_BIT       (1 << 0)
#define PWM_CTRL_IRQ_EN_BIT   (1 << 1)
#define PWM_CTRL_PEND_BIT     (1 << 2)

// ============================================================================
// INICIALIZACE A ŘÍZENÍ PWM
// ============================================================================

void pwm_init(pwm_regs_t* timer, uint16_t prescaler, uint16_t period) {
    // 1. Zastavíme časovač před rekonfigurací
    pwm_disable(timer);
    
    // 2. Zapíšeme hodnoty do hardwarových registrů
    timer->PRESC  = prescaler;
    timer->PERIOD = period;
    timer->DUTY   = 0; // Výchozí stav (vypnuto / 0% střída)
}

void pwm_set_duty(pwm_regs_t* timer, uint16_t duty) {
    timer->DUTY = duty; // Hardwarový registr je dynamický, projevuje se okamžitě
}

void pwm_enable(pwm_regs_t* timer) {
    timer->CTRL |= PWM_CTRL_EN_BIT;
}

void pwm_disable(pwm_regs_t* timer) {
    timer->CTRL &= ~PWM_CTRL_EN_BIT;
}

// ============================================================================
// OBSLUHA PŘERUŠENÍ
// ============================================================================

void pwm_irq_enable(pwm_regs_t* timer) {
    timer->CTRL |= PWM_CTRL_IRQ_EN_BIT;
}

void pwm_irq_disable(pwm_regs_t* timer) {
    timer->CTRL &= ~PWM_CTRL_IRQ_EN_BIT;
}

bool pwm_irq_is_pending(pwm_regs_t* timer) {
    // Vrátí true, pokud je Bit 2 nastaven hardwarovým přetečením
    return (timer->CTRL & PWM_CTRL_PEND_BIT) != 0;
}

void pwm_irq_clear(pwm_regs_t* timer) {
    // Podle pwm_timer.vhd musíme na bit 2 zapsat '0', abychom smazali příznak.
    // Ostatní bity (Enable, IRQ_En) musíme zachovat v původním stavu.
    timer->CTRL &= ~PWM_CTRL_PEND_BIT;
}