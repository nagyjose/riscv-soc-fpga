#define MAGIC_ADDR     *((volatile unsigned int *)0xFFFFFFFC)

// ====================================================================
// REGISTRY
// ====================================================================
#define GPIO_DATA      *((volatile unsigned int *)0x40000000)
#define GPIO_DIR       *((volatile unsigned int *)0x40000004)
#define GPIO_IRQ_MASK  *((volatile unsigned int *)0x40000008)
#define GPIO_IRQ_PEND  *((volatile unsigned int *)0x40000010)

#define MTIME          *((volatile unsigned int *)0x80000000)
#define MTIMECMP       *((volatile unsigned int *)0x80000004)

#define UART_DATA      *((volatile unsigned int *)0x40001000)
#define UART_STATUS    *((volatile unsigned int *)0x40001004)
#define UART_BAUD      *((volatile unsigned int *)0x40001008)

#define TIMER1_CTRL   *((volatile unsigned int *)0x40003000)
#define TIMER1_PRESC  *((volatile unsigned int *)0x40003004)
#define TIMER1_PERIOD *((volatile unsigned int *)0x40003008)
#define TIMER1_DUTY   *((volatile unsigned int *)0x4000300C)

// ====================================================================
// GLOBÁLNÍ PROMĚNNÉ
// ====================================================================
volatile int target_reached = 0;
volatile int duty_val = 10;
volatile int duty_step = 20; // Rychlost změny střídy
volatile int debug_toggle = 0;

// ====================================================================
// BLESKOVÝ TRAP HANDLER (Žádné blokování!)
// ====================================================================
__attribute__((interrupt("machine"))) void trap_handler(void) {
    unsigned int cause;
    __asm__ volatile ("csrr %0, mcause" : "=r"(cause));

    if (cause == 0x8000000B) { 
        
        // 1. Zpracování GPIO (Ukončení simulace)
        if (GPIO_IRQ_PEND & 0x01) {
            GPIO_IRQ_PEND = 0x01;
            target_reached = 1;
        }

        // 2. Zpracování HW Timeru
        if (TIMER1_CTRL & 0x04) {
            TIMER1_CTRL = 0x03; // Smazání příznaku (Zápis '0' na bit 2)

            // A) Test dynamické změny PWM (Sweep efekt)
            duty_val += duty_step;
            if (duty_val >= 190 || duty_val <= 10) {
                duty_step = -duty_step; // Změna směru (nahoru/dolů)
            }
            TIMER1_DUTY = duty_val;

            // B) Hardwarový debug: Překlopení pinu GPIO(1)
            debug_toggle ^= 1;
            if (debug_toggle) {
                GPIO_DATA |= 0x02;  // Nastav bit 1
            } else {
                GPIO_DATA &= ~0x02; // Smaž bit 1
            }
        }
        
        // Pokud přijde něco z UARTu, jen to potichu vyčteme (smazání IRQ), ale nevypisujeme nic!
        if (UART_STATUS & 0x02) { 
            volatile char dummy = UART_DATA; 
        }
    } 
}

void pass() { MAGIC_ADDR = 1; while(1); }

// ====================================================================
// HLAVNÍ PROGRAM
// ====================================================================
int main() {
    __asm__ volatile ("csrw mtvec, %0" :: "r"((unsigned int)trap_handler));

    // Nastavíme piny 1 až 19 jako výstupy, pin 0 jako vstup (tlačítko)
    GPIO_DIR = 0xFFFFE;
    GPIO_IRQ_MASK = 0x01;
    GPIO_IRQ_PEND = 0xFFFFFFFF;
    
    // Uklidníme systémový časovač
    MTIMECMP = MTIME + 500000; 

    // Povolení globálních přerušení
    __asm__ volatile ("csrw mstatus, %0" :: "r"(0x08));

    // ==========================================
    // START HARDWAROVÉHO TIMERU
    // ==========================================
    TIMER1_PRESC  = 10;   // Dělička 10 -> 1 tik = 100 ns
    TIMER1_PERIOD = 200;  // Perioda 200 tiků -> 20 us
    TIMER1_DUTY   = duty_val; // Počáteční střída
    
    // Zapnout Timer a povolit jeho lokální přerušení
    TIMER1_CTRL   = 0x03;

    // Hlavní smyčka nedělá VŮBEC NIC. Vše řídí hardware a blesková přerušení.
    while (target_reached == 0) { }

    pass();
    return 0;
}