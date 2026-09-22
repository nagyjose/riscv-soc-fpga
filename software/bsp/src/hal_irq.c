#include "soc_map.h"
#include "hal_irq.h"
#include "hal_cpu.h"
#include "hal_uart.h"
#include "hal_gpio.h"
#include "hal_pwm.h"

// Hardwarové příznaky přerušení z periferií (dle tvého VHDL/C kódu)
#define UART_RX_READY    (1 << 1) // Bit 1 v UART_STATUS
#define TIMER1_IRQ_PEND  (1 << 2) // Bit 2 v TIMER1_CTRL
#define GPIO_IRQ_BIT     (1 << 0) // Bit 0 v GPIO_IRQ_PEND

// Kódy v registru mcause
#define MCAUSE_EXT_IRQ   0x8000000B
#define MCAUSE_TIMER_IRQ 0x80000007

// Ukazatele na uživatelské funkce (Callbacks)
static irq_callback_t cb_mtime = 0;
static irq_callback_t cb_uart  = 0;
static irq_callback_t cb_gpio  = 0;

// Registrační funkce
void irq_register_timer(irq_callback_t callback) { cb_mtime = callback; }
void irq_register_uart(irq_callback_t callback)  { cb_uart = callback; }
void irq_register_gpio(irq_callback_t callback)  { cb_gpio = callback; }

// ============================================================================
// CENTRÁLNÍ DISPEČER (Spouští hardware automaticky)
// ============================================================================
__attribute__((interrupt("machine"))) void trap_handler(void) {
    uint32_t cause = READ_CSR(mcause);

    // A) Sdílené externí přerušení (Periferie)
    if (cause == MCAUSE_EXT_IRQ) {
        
        // 1. Zvonek od UARTu?
        // (Zda IRQ vzniklo, zjišťujeme přímo z registru UART_STATUS)
        if (HW_REG32(UART_BASE + 0x04) & UART_RX_READY) {
            if (cb_uart) cb_uart(); // Zavoláme uživatelský kód
            // (Vyčtení dat a smazání IRQ musí udělat callback pomocí hal_uart_getc!)
        }
        
        // 2. Zvonek od Tlačítka (GPIO)?
        if (HW_REG32(GPIO_BASE + 0x10) & GPIO_IRQ_BIT) {
            if (cb_gpio) cb_gpio();
            // (Smazání W1C příznaku musí udělat callback přes HAL GPIO!)
        }

        // 3. Zvonek od HW PWM Timeru?
        // Zvonek od TIMER1?
        if (pwm_irq_is_pending(HW_TIMER1)) {
            if (cb_timer1) cb_timer1(); // Uživatelská funkce
            pwm_irq_clear(HW_TIMER1);   // Bezpečné smazání příznaku
        }

        // Zvonek od TIMER2?
        if (pwm_irq_is_pending(HW_TIMER2)) {
            if (cb_timer2) cb_timer2();
            pwm_irq_clear(HW_TIMER2);
        }
    } 
    // B) Systémový časovač MTIME
    else if (cause == MCAUSE_TIMER_IRQ) {
        if (cb_mtime) cb_mtime();
        // (Posunutí času pro další IRQ musí udělat callback!)
    }
}

void irq_init(void) {
    // Řekneme procesoru, kde leží náš centrální dispečer
    WRITE_CSR(mtvec, (uint32_t)trap_handler);
}