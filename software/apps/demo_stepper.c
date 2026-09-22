#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_uart.h"
#include "hal_stepper.h"
#include "hal_mtime.h"

// ============================================================================
// UKÁZKA 1: NEZÁVISLÉ ŘÍZENÍ MOTORŮ
// ============================================================================
void demo_independent_control(void) {
    uart_puts(HW_UART, "\r\n--- 1. Nezávislé řízení (M0 a M1) ---\r\n");
    
    // Nastavení rychlosti. Hodnota udává počet 10us tiků mezi kroky.
    // M0: 100 tiků = 1 ms = rychlý chod (1000 Hz)
    // M1: 200 tiků = 2 ms = poloviční rychlost (500 Hz)
    stepper_set_speed(HW_STEPPER, 0, 100);
    stepper_set_speed(HW_STEPPER, 1, 200);

    uart_puts(HW_UART, "Startuji M0 vpred a M1 vzad...\r\n");
    
    // Rozjezd obou motorů opačným směrem
    stepper_run(HW_STEPPER, 0, STEP_DIR_FWD);
    stepper_run(HW_STEPPER, 1, STEP_DIR_BWD);

    // Necháme je jet 3 vteřiny
    mtime_delay_ms(HW_MTIME, 3000);

    // Zastavení
    stepper_stop(HW_STEPPER, 0);
    stepper_stop(HW_STEPPER, 1);
    uart_puts(HW_UART, "Zastaveno.\r\n");
}

// ============================================================================
// UKÁZKA 2: SYNCHRONNÍ ROBOTICKÝ START (Všech 8 motorů)
// ============================================================================
void demo_synchronous_control(void) {
    uart_puts(HW_UART, "\r\n--- 2. Hromadný synchronní start (M0 až M7) ---\r\n");

    // Nastavíme všem stejnou rychlost (např. 150 = 1.5 ms krok)
    for(int i = 0; i < 8; i++) {
        stepper_set_speed(HW_STEPPER, i, 150);
    }

    uart_puts(HW_UART, "Spoustim vsech 8 motoru soucasne!\r\n");

    // Chceme motory spustit tak, aby sudé jely vpřed a liché vzad.
    // M0 (Vpřed) = EN:1, DIR:0 -> binárně 01
    // M1 (Vzad)  = EN:1, DIR:1 -> binárně 11
    // Kombinace M1 a M0 = 1101 (hexadecimálně 0xD)
    // Pro 8 motorů to bude 4x za sebou: 0xDDDD
    
    // Zapíšeme přímo do CTRL registru - hardware spustí všech 8 motorů 
    // v absolutně přesném taktu procesoru, bez jediné mikrosekundy zpoždění mezi nimi!
    stepper_write_ctrl(HW_STEPPER, 0xDDDD);
    
    mtime_delay_ms(HW_MTIME, 3000);

    // Zastavení všech 8 motorů najednou zapsáním samých nul
    stepper_write_ctrl(HW_STEPPER, 0x0000);
    uart_puts(HW_UART, "Vsechny motory zastaveny.\r\n");
}

// ============================================================================
// HLAVNÍ PROGRAM
// ============================================================================
int main(void) {
    // Inicializace
    uart_init(HW_UART, 35000000, 115200);
    
    uart_puts(HW_UART, "\r\n=================================\r\n");
    uart_puts(HW_UART, " SDK Demo 5: Octal Stepper\r\n");
    uart_puts(HW_UART, "=================================\r\n");

    while (1) {
        demo_independent_control();
        mtime_delay_ms(HW_MTIME, 2000); // Pauza mezi testy
        
        demo_synchronous_control();
        mtime_delay_ms(HW_MTIME, 4000); // Delší pauza před opakováním
    }
    
    return 0;
}