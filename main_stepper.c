// Bázová adresa našeho sekvencéru
#define STEP_BASE 0x40005000

// GLOBAL_CTRL: Povolení a směr všech motorů (Bit 0=EN0, Bit 1=DIR0, Bit 2=EN1, Bit 3=DIR1...)
#define STEP_CTRL      *((volatile unsigned int *)(STEP_BASE + 0x00))

// Rychlosti motorů zabalené po dvou (Dolní a Horní půl-slovo)
#define STEP_SPEED_0_1 *((volatile unsigned int *)(STEP_BASE + 0x04))
#define STEP_SPEED_2_3 *((volatile unsigned int *)(STEP_BASE + 0x08))
#define STEP_SPEED_4_5 *((volatile unsigned int *)(STEP_BASE + 0x0C))
#define STEP_SPEED_6_7 *((volatile unsigned int *)(STEP_BASE + 0x10))

// ==============================================================
// Příklad použití v hlavní funkci
// ==============================================================
void start_robot() {
    // 1. Nastavíme rychlost (Hodnota = počet 10us tiků mezi kroky)
    // Motor 0 pojede max. rychlostí (100 = 1 ms = 1000 Hz)
    // Motor 1 pojede poloviční rychlostí (200 = 2 ms = 500 Hz)
    // Zápis do jednoho 32b registru: (Rychlost1 << 16) | (Rychlost0)
    STEP_SPEED_0_1 = (200 << 16) | 100;
    
    // 2. Zapneme oba motory jedním absolutně synchronním příkazem
    // Motor 0: Enable(Bit0)=1, Dir(Bit1)=0 (Vpřed) -> Binárně 01
    // Motor 1: Enable(Bit2)=1, Dir(Bit3)=1 (Vzad)  -> Binárně 11
    // Složeno dohromady: 1101 binárně = 0x0D hex
    STEP_CTRL = 0x0000000D;
}