#define MAGIC_ADDR     *((volatile unsigned int *)0xFFFFFFFC)
#define GPIO_DATA      *((volatile unsigned int *)0x40000000)
#define GPIO_DIR       *((volatile unsigned int *)0x40000004)
#define GPIO_IRQ_MASK  *((volatile unsigned int *)0x40000008)
#define GPIO_IRQ_EDGE  *((volatile unsigned int *)0x4000000C)
#define GPIO_IRQ_PEND  *((volatile unsigned int *)0x40000010)

// Počítadlo přerušení
volatile int irq_count = 0;

__attribute__((interrupt("machine"))) void trap_handler(void) {
    // 1. Smažeme Pending bit od pinu 0 (Write-1-to-Clear)
    GPIO_IRQ_PEND = 0x01;
    
    // 2. Zvýšíme počítadlo
    irq_count++;
}

void pass() { MAGIC_ADDR = 1; while(1); }

int main() {
    __asm__ volatile ("csrw mtvec, %0" :: "r"((unsigned int)trap_handler));

    // Nastavíme Pin 0 jako VSTUP (0), Piny 1-19 jako VÝSTUP (1)
    // Binárně: 1111 1111 1111 1111 1110 -> 0xFFFFE
    GPIO_DIR = 0xFFFFE; 

    // Konfigurace přerušení pro Pin 0
    GPIO_IRQ_EDGE = 0x00; 
    GPIO_IRQ_MASK = 0x01; 

    // Povolení přerušení v jádře (MIE bit)
    __asm__ volatile ("csrw mstatus, %0" :: "r"(0x08));

    // Čekáme na 2 nezávislá přerušení!
    while (irq_count < 2) {
        // Zápis 20bitového střídavého vzoru na výstupy: 1010 1010 1010 1010 1010
        GPIO_DATA = 0xAAAAA; 
    }

    // Pokud jsme se dostali sem, MRET úspěšně obnovil přerušení a my chytili oba stisky!
    pass();
    return 0;
}