#define DEBUG_PORT *((volatile unsigned int *)0xFFFFFFFC)

void main() {
    // Zápisem na tuto adresu vyhodí náš VHDL testbench SUCCESS zprávu!
    DEBUG_PORT = 1; 
    
    // Záchytná smyčka
    while(1);
}