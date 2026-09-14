#define MAGIC_ADDR     *((volatile unsigned int *)0xFFFFFFFC)
#define GPIO_DATA      *((volatile unsigned int *)0x40000000)
#define GPIO_DIR       *((volatile unsigned int *)0x40000004)
#define GPIO_IRQ_MASK  *((volatile unsigned int *)0x40000008)
#define GPIO_IRQ_EDGE  *((volatile unsigned int *)0x4000000C)
#define GPIO_IRQ_PEND  *((volatile unsigned int *)0x40000010)

// Globální proměnná (volatile, aby ji optimalizátor nevymazal!)
volatile int button_pressed = 0;

// Hardwarový Trap Handler (ISR)
__attribute__((interrupt("machine"))) void trap_handler(void) {
    // 1. Smažeme požadavek na přerušení metodou Write-1-to-Clear na nultý bit
    GPIO_IRQ_PEND = 0x01;
    
    // 2. Dáme hlavnímu programu vědět, že to zafungovalo
    button_pressed = 1;
}

void pass() { MAGIC_ADDR = 1; while(1); }

int main() {
    // 1. Nastavíme adresu naší obslužné rutiny do systémového registru MTVEC
    __asm__ volatile ("csrw mtvec, %0" :: "r"((unsigned int)trap_handler));

    // 2. Nastavíme Pin 0 jako VSTUP (0), ostatní piny jako VÝSTUP (1)
    GPIO_DIR = 0xFFFFE; 

    // 3. Konfigurace přerušení pro Pin 0
    GPIO_IRQ_EDGE = 0x00000; // 0 = Reakce na náběžnou hranu
    GPIO_IRQ_MASK = 0x00001; // Odmaskování (povolení) přerušení z tohoto pinu

    // 4. Globální povolení přerušení (Zápis '1' do bitu 3 v MSTATUS)
    __asm__ volatile ("csrw mstatus, %0" :: "r"(0x08));

    // 5. Procesor "spí" a dělá zbytečnou práci, dokud nepřijde impuls zvenčí
    while (button_pressed == 0) {
        GPIO_DATA = 0xAAAAA; // Signál, že čekáme...
    }

    // 6. Pokud jsme se dostali sem, interrupt nás úspěšně vytrhl ze smyčky!
    pass();
    return 0;
}