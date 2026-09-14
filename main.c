#define MAGIC_ADDR     *((volatile unsigned int *)0xFFFFFFFC)
#define GPIO_DATA      *((volatile unsigned int *)0x40000000)
#define GPIO_DIR       *((volatile unsigned int *)0x40000004)
#define GPIO_IRQ_MASK  *((volatile unsigned int *)0x40000008)
#define GPIO_IRQ_PEND  *((volatile unsigned int *)0x40000010)

// Nové registry pro časovač!
#define MTIME          *((volatile unsigned int *)0x80000000)
#define MTIMECMP       *((volatile unsigned int *)0x80000004)

volatile int blink_state = 0;
volatile int target_reached = 0;

__attribute__((interrupt("machine"))) void trap_handler(void) {
    unsigned int cause;
    // Přečteme registr mcause, abychom zjistili důvod přerušení
    __asm__ volatile ("csrr %0, mcause" : "=r"(cause));

    if (cause == 0x8000000B) { 
        // VZBUDILO NÁS TLAČÍTKO Z GPIO
        GPIO_IRQ_PEND = 0x01; // Smazat příznak z GPIO
        target_reached = 1;   // Signál k ukončení programu
    } 
    else if (cause == 0x80000007) {
        // VZBUDIL NÁS MTIME ČASOVAČ
        blink_state = !blink_state; // Překlápíme stav
        GPIO_DATA = blink_state ? 0xAAAAA : 0x55555; // Ukážeme to na LEDkách
        
        // KLÍČOVÝ KROK: Naplánujeme další probuzení!
        // Pro simulaci dáme 5 us. V realitě by to bylo např. 500000 pro půl sekundy.
        MTIMECMP = MTIME + 5; 
    }
}

void pass() { MAGIC_ADDR = 1; while(1); }

int main() {
    __asm__ volatile ("csrw mtvec, %0" :: "r"((unsigned int)trap_handler));

    GPIO_DIR = 0xFFFFE; // Pin 0 vstup, ostatní výstupy
    GPIO_IRQ_MASK = 0x01; // Povolit přerušení od tlačítka
    
    // Nastavíme první budík za 5 mikrosekund od teď
    MTIMECMP = MTIME + 5; 

    // Povolit přerušení globálně
    __asm__ volatile ("csrw mstatus, %0" :: "r"(0x08));

    // TADY JE TA SÍLA: 
    // Namísto zasekávání ve "for" smyčkách může nyní hlavní program
    // dělat cokoliv užitečného. Hardware sám zajistí pravidelné blikání!
    while (target_reached == 0) {
        // ... procesor by mohl počítat Pí, číst senzory, nebo jít spát (WFI)
        // My zatím jen čekáme, až nás z této smyčky vysvobodí stisk tlačítka.
    }

    pass();
    return 0;
}