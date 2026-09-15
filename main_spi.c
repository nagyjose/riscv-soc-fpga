#define MAGIC_ADDR     *((volatile unsigned int *)0xFFFFFFFC)

// GPIO Registry
#define GPIO_DATA      *((volatile unsigned int *)0x40000000)
#define GPIO_DIR       *((volatile unsigned int *)0x40000004)
#define GPIO_IRQ_MASK  *((volatile unsigned int *)0x40000008)
#define GPIO_IRQ_PEND  *((volatile unsigned int *)0x40000010)

// MTIME Registry
#define MTIME          *((volatile unsigned int *)0x80000000)
#define MTIMECMP       *((volatile unsigned int *)0x80000004)

// UART Registry
#define UART_DATA      *((volatile unsigned int *)0x40001000)
#define UART_STATUS    *((volatile unsigned int *)0x40001004)
#define UART_BAUD      *((volatile unsigned int *)0x40001008)

// SPI Registry (0x40002000)
#define SPI_DATA      *((volatile unsigned int *)0x40002000)
#define SPI_STATUS    *((volatile unsigned int *)0x40002004)
#define SPI_BAUD      *((volatile unsigned int *)0x40002008)

volatile int blink_state = 0;
volatile int target_reached = 0;

// ====================================================================
// POMOCNÉ FUNKCE PRO UART
// ====================================================================
void uart_putchar(char c) {
    // Čekáme, dokud hardwarový TX automat není připraven (Bit 0 musí být 1)
    while ((UART_STATUS & 0x01) == 0);
    UART_DATA = c; // Zapíšeme na adresu 0x00, čímž hardware zahájí odesílání
}

void print(const char *str) {
    while (*str) {
        uart_putchar(*str++);
    }
}

// ====================================================================
// POMOCNÉ FUNKCE PRO SPI
// ====================================================================
unsigned char spi_transfer(unsigned char data) {
    // 1. Zapíšeme data do registru (čímž HW automaticky zahájí přenos)
    SPI_DATA = data;
    
    // 2. Čekáme, dokud je sběrnice zaneprázdněná (Bit 0 v STATUS registru svítí)
    while (SPI_STATUS & 0x01) {
        // Zde čekáme, až HW odtiká 8 hodinových pulzů
    }
    
    // 3. Přečteme výsledek z toho samého registru
    return (unsigned char)SPI_DATA;
}

// ====================================================================
// TRAP HANDLER - CENTRÁLNÍ MOZEK PŘERUŠENÍ
// ====================================================================
__attribute__((interrupt("machine"))) void trap_handler(void) {
    unsigned int cause;
    __asm__ volatile ("csrr %0, mcause" : "=r"(cause));

    // A) SDÍLENÉ EXTERNÍ PŘERUŠENÍ (Kód 11)
    if (cause == 0x8000000B) { 
        
        // 1. Vyvolal to UART? (Má něco ve svém FIFO?)
        if (UART_STATUS & 0x02) { 
            // Přečteme znak (tím se z HW FIFO odstraní a IRQ samo spadne, pokud bylo poslední)
            volatile char received = UART_DATA; 
            
            // Provedeme ECHO: Pošleme znak rovnou zpátky ven do terminálu
            uart_putchar('[');
            uart_putchar(received);
            uart_putchar(']');
        }
        
        // 2. Nebo to vyvolalo GPIO Tlačítko?
        if (GPIO_IRQ_PEND & 0x01) {
            GPIO_IRQ_PEND = 0x01; // Smazat příznak
            target_reached = 1;   // Ukončit program
        }
    } 
    // B) ČASOVAČ (Kód 7)
    else if (cause == 0x80000007) {
        blink_state = !blink_state;
        GPIO_DATA = blink_state ? 0xAAAAA : 0x55555;
        MTIMECMP = MTIME + 5000; // Naplánovat další tik pro rychlou simulaci
    }
}

void pass() { MAGIC_ADDR = 1; while(1); }

// ====================================================================
// HLAVNÍ PROGRAM
// ====================================================================
int main() {
    __asm__ volatile ("csrw mtvec, %0" :: "r"((unsigned int)trap_handler));

    GPIO_DIR = 0xFFFFE;
    GPIO_IRQ_MASK = 0x01;

    GPIO_IRQ_PEND = 0xFFFFFFFF;
    
    // OPRAVA 1: Baud rate musí být min. 160 pro správný chod RX oversamplingu!
    // 160 taktů = 1.6 us na jeden bit
    UART_BAUD = 160;       

    // OPRAVA 2: Uklidníme časovač (z 20 ns na 50 mikrosekund), ať nás teď neruší
    MTIMECMP = MTIME + 5000; 

    __asm__ volatile ("csrw mstatus, %0" :: "r"(0x08));

    // Konfigurace SPI rychlosti (např. 1 MHz při 100MHz CPU = dělička 50 pro půlperiodu)
    SPI_BAUD = 50;

    // Test SPI Loopbacku - pošleme znak 'S' (0x53)
    unsigned char odpoved = spi_transfer('S');

    // Můžeme si výsledek rovnou vypsat přes UART, abychom to viděli i tam!
    print("SPI Loopback test: Poslal jsem 'S', vratilo se: [");
    uart_putchar(odpoved);
    print("]\n");

    while (target_reached == 0) { }

    pass();
    return 0;
}