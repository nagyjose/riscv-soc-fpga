#include "../inc/soc_map.h"

int main() {
    // Rychlý test UARTu - odešle dva znaky ihned po startu
    UART_DATA = 'O';
    UART_DATA = 'K';

    // Aktivace motoru č. 0 na maximální rychlost (1 ms krok) a směr vpřed
    STEP_SPEED_0_1 = 100;        // Spodních 16 bitů = Rychlost motoru 0
    STEP_GLOBAL_CTRL = 0x0001;   // Bit 0 (Enable M0) = 1, Bit 1 (Směr M0) = 0

    while(1) {
        // Hlavní nekonečná smyčka mikrokontroléru
    }
    return 0;
}