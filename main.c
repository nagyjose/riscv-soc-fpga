#define GPIO_DATA *((volatile unsigned int *)0x40000000)
#define GPIO_DIR  *((volatile unsigned int *)0x40000004)

int main() {
    // Nastavíme všech 8 pinů jako výstupní
    GPIO_DIR = 0xFF; 

    while (1) {
        // Rozsvítíme sudé piny (binárně 10101010)
        GPIO_DATA = 0xAA; 
        
        // Jednoduchá zdržovací smyčka
        for (volatile int i = 0; i < 50000; i++); 

        // Rozsvítíme liché piny (binárně 01010101)
        GPIO_DATA = 0x55; 

        // Zdržovací smyčka
        for (volatile int i = 0; i < 50000; i++); 
    }
    return 0;
}