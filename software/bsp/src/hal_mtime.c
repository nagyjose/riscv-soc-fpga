#include "hal_mtime.h"

// ============================================================================
// ČTENÍ ČASU A PLÁNOVÁNÍ PŘERUŠENÍ
// ============================================================================

uint32_t mtime_get_time(mtime_regs_t* mtime) {
    return mtime->TIME;
}

void mtime_set_compare(mtime_regs_t* mtime, uint32_t absolute_time_us) {
    mtime->TIMECMP = absolute_time_us;
}

void mtime_set_compare_relative(mtime_regs_t* mtime, uint32_t delta_us) {
    mtime->TIMECMP = mtime->TIME + delta_us;
}

void mtime_irq_disable(mtime_regs_t* mtime) {
    // Nastavením na maximální 32bitovou hodnotu odložíme IRQ do nekonečna
    mtime->TIMECMP = 0xFFFFFFFF;
}

// ============================================================================
// BLOKUJÍCÍ ČEKÁNÍ (Delay)
// ============================================================================

void mtime_delay_us(mtime_regs_t* mtime, uint32_t us) {
    // Zaznamenáme si startovní čas
    uint32_t start_time = mtime->TIME;
    
    // Rozdíl (MTIME_REG - start_time) se díky vlastnostem unsigned matematiky 
    // spočítá správně i přes přetečení (tzv. roll-over) čítače.
    while ((mtime->TIME - start_time) < us) {
        // Volitelně můžeme do nekonečné smyčky přidat instrukci WFI (Wait For Interrupt),
        // pokud bychom chtěli uspat jádro a šetřit energii, ale pro standardní delay 
        // stačí aktivní čekání.
    }
}

void mtime_delay_ms(mtime_regs_t* mtime, uint32_t ms) {
    // 1 milisekunda = 1000 mikrosekund
    mtime_delay_us(mtime, ms * 1000);
}