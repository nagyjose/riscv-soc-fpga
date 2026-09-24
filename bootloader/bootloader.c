#define UART_DATA   *((volatile unsigned int *)0x40001000)
#define UART_STATUS *((volatile unsigned int *)0x40001004)
#define UART_BAUD   *((volatile unsigned int *)0x40001008)

void main() {
    UART_BAUD = 304; 

    char *msg = "\r\n--- HW ECHO TEST ---\r\nNapis neco:\r\n";
    while (*msg) {
        while ((UART_STATUS & 0x01) == 0); 
        UART_DATA = *msg++;
    }

    while(1) {
        if (UART_STATUS & 0x02) { 
            char c = UART_DATA;   // 1. Bezpečně si přečteme znak (Peek)
            UART_STATUS = 1;      // 2. EXPLICITNĚ HO SMAŽEME Z FIFO! (Pop)
            
            while ((UART_STATUS & 0x01) == 0); 
            UART_DATA = c;        // 3. Pošleme zpět
        }
    }
}