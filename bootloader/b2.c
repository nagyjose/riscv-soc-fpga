#define UART_DATA   *((volatile unsigned int *)0x40001000)
#define UART_STATUS *((volatile unsigned int *)0x40001004)
#define UART_BAUD   *((volatile unsigned int *)0x40001008)

#define APP_START_ADDR 0x20000000

unsigned char uart_getc() {
    while ((UART_STATUS & 0x02) == 0); 
    return (unsigned char)UART_DATA;
}

void main() {
    UART_BAUD = 304; 

    // 1. Vyčistíme přijímací buffer FPGA od šumu způsobeného hardwarovým resetem
    while (UART_STATUS & 0x02) {
        volatile char dummy = UART_DATA;
    }

    // 2. Zpráva života pro kontrolu
    char *msg = "\r\nBOOT_READY\r\n";
    while (*msg) {
        while ((UART_STATUS & 0x01) == 0); 
        UART_DATA = *msg++;
    }

    // 3. Čekání na magické 'B' s ignorováním ostatních znaků
    int got_b = 0;
    for (volatile int i = 0; i < 50000000; i++) {
        if (UART_STATUS & 0x02) {       // Přišel znak!
            if ((char)UART_DATA == 'B') { 
                got_b = 1;              // Je to B!
                break;                  // Ukončit čekání
            }
            // Pokud to nebylo 'B', smyčka jede dál a znak se zahodí.
        }
    }

    // 4. Samotné programování
    if (got_b) {
        int app_size = 0;
        app_size |= (uart_getc() << 0);
        app_size |= (uart_getc() << 8);
        app_size |= (uart_getc() << 16);
        app_size |= (uart_getc() << 24);

        volatile unsigned char *ram_pointer = (volatile unsigned char *)APP_START_ADDR;
        
        for (int i = 0; i < app_size; i++) {
            *ram_pointer = uart_getc();
            ram_pointer++;
        }
        
        // Odeslání potvrzení
        while ((UART_STATUS & 0x01) == 0); 
        UART_DATA = 'K'; 
    }

    // ========================================================
    // SKOK DO APLIKACE V RAM
    // ========================================================
    void (*app_jump)(void) = (void (*)(void))APP_START_ADDR;
    app_jump(); 

    while(1);
}