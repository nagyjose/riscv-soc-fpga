#ifndef HAL_MTIME_H
#define HAL_MTIME_H

#include <stdint.h>
#include "soc_map.h"

// ============================================================================
// ČTENÍ ČASU A PLÁNOVÁNÍ PŘERUŠENÍ
// ============================================================================

// Vrátí aktuální čas od startu procesoru v mikrosekundách (us)
uint32_t mtime_get_time(mtime_regs_t* mtime);

// Nastaví absolutní čas, kdy má procesor vyvolat přerušení (Trap 7)
void mtime_set_compare(mtime_regs_t* mtime, uint32_t absolute_time_us);

// Plánuje přerušení za x mikrosekund od této chvíle (ideální pro callbacky)
void mtime_set_compare_relative(mtime_regs_t* mtime, uint32_t delta_us);

// Zastaví generování přerušení (nastaví komparátor na maximum)
void mtime_irq_disable(mtime_regs_t* mtime);

// ============================================================================
// BLOKUJÍCÍ ČEKÁNÍ (Delay)
// ============================================================================

// Zastaví vykonávání programu na zadaný počet mikrosekund
void mtime_delay_us(mtime_regs_t* mtime, uint32_t us);

// Zastaví vykonávání programu na zadaný počet milisekund
void mtime_delay_ms(mtime_regs_t* mtime, uint32_t ms);

#endif // HAL_MTIME_H