#define MAGIC_ADDR *((volatile unsigned int *)0xFFFFFFFC)

// Nahlášení chyby (např. 0xDEAD0001)
void fail(int test_id) {
    MAGIC_ADDR = 0xDEAD0000 | test_id;
    while(1);
}

// Nahlášení úspěchu
void pass() {
    MAGIC_ADDR = 1;
    while(1);
}

int main() {
    unsigned int read_val;

    // ========================================================================
    // TEST 1: Zápis a čtení registru MTVEC (Adresa 0x305)
    // ========================================================================
    unsigned int mtvec_test_val = 0x00001000;
    __asm__ volatile (
        "csrw 0x305, %1\n\t"    // Zapiš hodnotu mtvec_test_val do registru 0x305
        "csrr %0, 0x305\n\t"    // Přečti registr 0x305 zpět do read_val
        : "=r" (read_val)
        : "r" (mtvec_test_val)
    );
    if (read_val != mtvec_test_val) fail(1);

    // ========================================================================
    // TEST 2: Zápis a čtení registru MEPC (Adresa 0x341)
    // ========================================================================
    unsigned int mepc_test_val = 0x00002004;
    __asm__ volatile (
        "csrw 0x341, %1\n\t"
        "csrr %0, 0x341\n\t"
        : "=r" (read_val)
        : "r" (mepc_test_val)
    );
    if (read_val != mepc_test_val) fail(2);

    // ========================================================================
    // TEST 3: Bitové operace nad MSTATUS (Adresa 0x300)
    // Testujeme instrukce CSRRS (Set) a CSRRC (Clear) na bitu 3 (MIE)
    // ========================================================================
    
    // A) Nastavení bitu 3 (Hodnota 8) pomocí masky
    __asm__ volatile (
        "li t1, 8\n\t"            // Maska pro bit 3
        "csrrs x0, 0x300, t1\n\t" // Nastav bit (Set). Výsledek čtení zahodíme do x0.
        "csrr %0, 0x300\n\t"      // Přečteme nový stav
        : "=r" (read_val)
        : : "t1"
    );
    if (read_val != 8) fail(3);

    // B) Vynulování bitu 3 pomocí masky
    __asm__ volatile (
        "li t1, 8\n\t"
        "csrrc x0, 0x300, t1\n\t" // Vymaž bit (Clear)
        "csrr %0, 0x300\n\t"
        : "=r" (read_val)
        : : "t1"
    );
    if (read_val != 0) fail(4);

    // ========================================================================
    // TEST 4: Ochrana proti neexistujícím registrům
    // ========================================================================
    __asm__ volatile (
        "li t1, 0xFFFFFFFF\n\t"
        "csrw 0x999, t1\n\t"      // Zápis do neplatné adresy (Měl by se potichu zahodit)
        "csrr %0, 0x999\n\t"      // Čtení z neplatné adresy (Mělo by vrátit 0)
        : "=r" (read_val)
        : : "t1"
    );
    if (read_val != 0) fail(5);

    // Pokud program dojde až sem, CPU umí Zicsr!
    pass();
    
    return 0;
}