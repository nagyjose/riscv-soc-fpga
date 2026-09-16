#define UART_DATA   *((volatile unsigned int *)0x40001000)
#define UART_STATUS *((volatile unsigned int *)0x40001004)
#define UART_BAUD   *((volatile unsigned int *)0x40001008)

// Ukazatel na začátek naší hlavní RAM (zde bude ležet uživatelská aplikace)
#define APP_START_ADDR 0x20000000

// Funkce pro čtení znaku z UARTu s timeoutem
// Vrací 1 při úspěchu, 0 při timeoutu (např. nic nepřichází)
int uart_getc_timeout(char *c) {
    // Timeout cyklus - zhruba 1 vteřina čekání při 100 MHz
    for (volatile int i = 0; i < 5000000; i++) {
        if (UART_STATUS & 0x02) { // FIFO není prázdné
            *c = (char)UART_DATA;
            return 1;
        }
    }
    return 0; 
}

void main() {
    UART_BAUD = 868; // Nastavíme 115200 (předpoklad: 100MHz / 115200)

    char c;
    
    // 1. Čekáme na "Magické slovo" od Python skriptu (např. znak 'B')
    // Pokud nic nepřijde, timeout vyprší a bootloader přeskočí programování.
    if (uart_getc_timeout(&c)) {
        if (c == 'B') {
            
            // 2. Skript se ozval! Vyčteme velikost programu v Bytech
            int app_size = 0;
            app_size |= (UART_DATA << 0);
            app_size |= (UART_DATA << 8);
            app_size |= (UART_DATA << 16);
            app_size |= (UART_DATA << 24);

            // 3. Programovací smyčka
            volatile unsigned char *ram_pointer = (volatile unsigned char *)APP_START_ADDR;
            
            for (int i = 0; i < app_size; i++) {
                // Zde už neřešíme timeout, Python skript chrlí data
                while ((UART_STATUS & 0x02) == 0); 
                *ram_pointer = (unsigned char)UART_DATA;
                ram_pointer++;
            }
            // Můžeme poslat znak potvrzení 'K', že je vše uloženo
            UART_DATA = 'K'; 
        }
    }

    // ========================================================
    // MAGIE SOFTWARU: SKOK DO APLIKACE V RAM!
    // ========================================================
    // Vytvoříme si ukazatel na funkci nasměrovaný na 0x20000000
    void (*app_jump)(void) = (void (*)(void))APP_START_ADDR;
    
    // Zavoláme RAM (Procesor naplní PC hodnotou 0x20000000)
    app_jump(); 

    // Sem by program nikdy neměl dojít
    while(1);
}