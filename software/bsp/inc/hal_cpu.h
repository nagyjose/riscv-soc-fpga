#ifndef HAL_CPU_H
#define HAL_CPU_H

#include <stdint.h>

// ============================================================================
// ČTENÍ A ZÁPIS DO CSR REGISTRŮ (Zicsr rozšíření)
// ============================================================================

// Přečte hodnotu z libovolného CSR registru
#define READ_CSR(reg) ({ \
    uint32_t val; \
    __asm__ volatile ("csrr %0, " #reg : "=r" (val)); \
    val; \
})

// Zapíše hodnotu do libovolného CSR registru
#define WRITE_CSR(reg, val) ({ \
    __asm__ volatile ("csrw " #reg ", %0" :: "rK" (val)); \
})

// Nastaví konkrétní bity v CSR registru (pomocí masky)
#define SET_CSR(reg, bit_mask) ({ \
    __asm__ volatile ("csrs " #reg ", %0" :: "rK" (bit_mask)); \
})

// Vymaže konkrétní bity v CSR registru (pomocí masky)
#define CLEAR_CSR(reg, bit_mask) ({ \
    __asm__ volatile ("csrc " #reg ", %0" :: "rK" (bit_mask)); \
})

// ============================================================================
// GLOBÁLNÍ ŘÍZENÍ PŘERUŠENÍ (MSTATUS)
// ============================================================================
#define MSTATUS_MIE_BIT (1 << 3)

static inline void cpu_irq_enable(void) {
    SET_CSR(mstatus, MSTATUS_MIE_BIT);
}

static inline void cpu_irq_disable(void) {
    CLEAR_CSR(mstatus, MSTATUS_MIE_BIT);
}

#endif // HAL_CPU_H