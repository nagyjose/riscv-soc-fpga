#ifndef SOC_MAP_H
#define SOC_MAP_H

#include <stdint.h>

// ============================================================================
// 1. PAMĚŤOVÝ PROSTOR
// ============================================================================
#define ROM_BASE        0x00000000  // Bootloader (Read-Only z pohledu CPU)
#define RAM_BASE        0x20000000  // Hlavní operační paměť (Začínají zde data i zásobník)

// ============================================================================
// 2. BÁZOVÉ ADRESY PERIFERIÍ (MMIO - Memory Mapped I/O)
// ============================================================================
#define GPIO_BASE       0x40000000
#define UART_BASE       0x40001000
#define SPI_BASE        0x40002000
#define TIMER1_BASE     0x40003000  // HW PWM Timer 1
#define TIMER2_BASE     0x40004000  // HW PWM Timer 2
#define STEPPER_BASE    0x40005000  // Octal Stepper Motor Controller
#define MTIME_BASE      0x80000000  // Systémový časovač (RISC-V standard)

// ============================================================================
// 3. REGISTROVÁ MAPA PERIFERIÍ (Hardwarová abstrakce)
// ============================================================================
// Makro pro snadný přístup k paměti (přetypování adresy na volatile ukazatel)
#define HW_REG(addr)    (*((volatile uint32_t *)(addr)))

// --- GPIO ---
typedef struct {
    volatile uint32_t DATA;     // 0x00: Čtení = IN stav, Zápis = OUT stav
    volatile uint32_t DIR;      // 0x04: Směr (1 = Výstup, 0 = Vstup)
    volatile uint32_t IRQ_MASK; // 0x08: Povolení přerušení
    volatile uint32_t IRQ_EDGE; // 0x0C: Hrana (0 = Náběžná, 1 = Sestupná)
    volatile uint32_t IRQ_PEND; // 0x10: Příznak přerušení (Zápis 1 pro smazání)
} gpio_regs_t;

// --- UART ---
typedef struct {
    volatile uint32_t DATA;     // 0x00: Čtení/Zápis znaku
    volatile uint32_t STATUS;   // 0x04: Bit 0: TX_READY, Bit 1: RX_AVAILABLE
    volatile uint32_t BAUD;     // 0x08: Dělička hodin
} uart_regs_t;

// --- SPI MASTER ---
typedef struct {
    volatile uint32_t DATA;   // 0x00: Zápis = start přenosu, Čtení = přijatá data
    volatile uint32_t STATUS; // 0x04: Bit 0 = SPI_BUSY
    volatile uint32_t BAUD;   // 0x08: Dělička pro poloviční periodu SCK
} spi_regs_t;

// --- HW PWM TIMERY ---
// Struktura přesně kopíruje rozložení registrů ve VHDL (offsety 0x00, 0x04, 0x08, 0x0C)
typedef struct {
    volatile uint32_t CTRL;   // Bit 0: EN, Bit 1: IRQ_EN, Bit 2: PEND
    volatile uint32_t PRESC;  // Předdělička (rychlost tikání)
    volatile uint32_t PERIOD; // Strop čítače (frekvence PWM)
    volatile uint32_t DUTY;   // Šířka pulzu (střída PWM)
} pwm_regs_t;

// --- KROKOVÉ MOTORY (Octal Stepper) ---
typedef struct {
    volatile uint32_t CTRL;     // 0x00: Bity 0,2..14=EN, Bity 1,3..15=DIR
    volatile uint32_t SPEED[4]; // 0x04-0x10: 4x 32bit registr (po dvou 16b rychlostech)
} stepper_regs_t;

// --- MTIME (Systémový časový komparátor) ---
typedef struct {
    volatile uint32_t TIME;    // 0x00: Čtení aktuálního času (v mikrosekundách)
    volatile uint32_t TIMECMP; // 0x04: Zápis času pro vyvolání přerušení
} mtime_regs_t;

// Převedení absolutních adres na ukazatele na naši strukturu
#define HW_GPIO    ((gpio_regs_t*)GPIO_BASE)
#define HW_UART    ((uart_regs_t*)UART_BASE)
#define HW_SPI     ((spi_regs_t*)SPI_BASE)
#define HW_TIMER1  ((pwm_regs_t*)TIMER1_BASE)
#define HW_TIMER2  ((pwm_regs_t*)TIMER2_BASE)
#define HW_STEPPER ((stepper_regs_t*)STEPPER_BASE)
#define HW_MTIME   ((mtime_regs_t*)MTIME_BASE)

#endif // SOC_MAP_H