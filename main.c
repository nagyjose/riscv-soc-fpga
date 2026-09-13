#define MAGIC_ADDR *((volatile unsigned int *)0xFFFFFFFC)

void fail(int test_id) {
    MAGIC_ADDR = 0xDEAD0000 | test_id;
    while(1);
}

void pass() {
    MAGIC_ADDR = 1;
    while(1);
}

int main() {
    int a, b, res;
    unsigned int ua, ub, ures;

    // ========================================================================
    // TEST 1: Běžné násobení (MUL)
    // ========================================================================
    a = 21; b = 2;
    __asm__ volatile ("mul %0, %1, %2" : "=r"(res) : "r"(a), "r"(b));
    if (res != 42) fail(1);

    // ========================================================================
    // TEST 2: Znaménkové násobení s přetečením (MULH)
    // ========================================================================
    // 2 000 000 000 * 3 = 6 000 000 000. Do 32 bitů se vejde max ~2.14 mld.
    // 6 000 000 000 v hex je 0x00000001_65A0BC00. Horní polovina je přesně 1.
    a = 2000000000; b = 3;
    __asm__ volatile ("mulh %0, %1, %2" : "=r"(res) : "r"(a), "r"(b));
    if (res != 1) fail(2);

    // ========================================================================
    // TEST 3: Znaménkové dělení a modulo (DIV, REM)
    // ========================================================================
    a = -20; b = 3;
    __asm__ volatile ("div %0, %1, %2" : "=r"(res) : "r"(a), "r"(b));
    if (res != -6) fail(3);

    __asm__ volatile ("rem %0, %1, %2" : "=r"(res) : "r"(a), "r"(b));
    if (res != -2) fail(4); // Zbytek musí mít stejné znaménko jako dělenec

    // ========================================================================
    // TEST 4: Neznaménkové dělení (DIVU)
    // ========================================================================
    ua = 4000000000U; ub = 2U;
    __asm__ volatile ("divu %0, %1, %2" : "=r"(ures) : "r"(ua), "r"(ub));
    if (ures != 2000000000U) fail(5);

    // ========================================================================
    // TEST 5: Architektonická past RISC-V - Dělení nulou
    // ========================================================================
    a = 42; b = 0;
    // RISC-V nevyhazuje výjimku, ale nařizuje podíl nastavit na -1 (všechny bity na 1)
    __asm__ volatile ("div %0, %1, %2" : "=r"(res) : "r"(a), "r"(b));
    if (res != -1) fail(6); 

    // Zbytek po dělení nulou musí být původní dělenec
    __asm__ volatile ("rem %0, %1, %2" : "=r"(res) : "r"(a), "r"(b));
    if (res != 42) fail(7); 

    // Pokud CPU (a naše stall logika) vše přežije bez ztráty taktu, zahlásíme úspěch
    pass();
    return 0;
}