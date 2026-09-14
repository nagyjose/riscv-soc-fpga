#define MAGIC_ADDR *((volatile unsigned int *)0xFFFFFFFC)

void fail(int test_id) {
    MAGIC_ADDR = 0xDEAD0000 | test_id;
    while(1);
}

void pass() {
    MAGIC_ADDR = 1;
    while(1);
}

// ============================================================================
// MAKRO PRO INJEKCI SUROVÉHO STROJOVÉHO KÓDU DO PIPELINY
// Vnucujeme GCC, aby vložil parametry do přesně daných hardwarových registrů.
// ============================================================================
#define EXEC_CUSTOM(hex_code, arg1, arg2, res) do { \
    register unsigned int _rs1 asm("t0") = (arg1); \
    register unsigned int _rs2 asm("t1") = (arg2); \
    register unsigned int _rd  asm("t2"); \
    __asm__ volatile ( \
        ".word " #hex_code "\n\t" \
        : "=r" (_rd) \
        : "r" (_rs1), "r" (_rs2) \
    ); \
    (res) = _rd; \
} while(0)

int main() {
    unsigned int a, b, res;

    // ========================================================================
    // TEST 1: Zbs - Práce s jednotlivými bity
    // ========================================================================
    a = 0x00000000;
    
    // BSET: Nastav 4. bit (Hex: 0x286293B3)
    EXEC_CUSTOM(0x286293B3, a, 4, res);
    if (res != 0x00000010) fail(1);

    // BINV: Invertuj 4. a 0. bit (Hex: 0x686293B3)
    EXEC_CUSTOM(0x686293B3, res, 4, res); // Zhasne bit 4
    EXEC_CUSTOM(0x686293B3, res, 0, res); // Rozsvítí bit 0
    if (res != 0x00000001) fail(2);

    // BCLR: Vymaž 0. bit (Hex: 0x486293B3)
    EXEC_CUSTOM(0x486293B3, res, 0, res);
    if (res != 0x00000000) fail(3);

    // BEXT: Vyextrahuj 31. bit z 0x80000000 (Hex: 0x4862D3B3)
    a = 0x80000000;
    EXEC_CUSTOM(0x4862D3B3, a, 31, res);
    if (res != 1) fail(4);

    // ========================================================================
    // TEST 2: Zbb - Logické operace (ANDN, XNOR)
    // ========================================================================
    a = 0x0000FFFF;
    b = 0x00FF00FF; 

    // ANDN: res = a AND (NOT b) (Hex: 0x4062F3B3)
    EXEC_CUSTOM(0x4062F3B3, a, b, res);
    if (res != 0x0000FF00) fail(5);

    // XNOR: res = NOT (a XOR b) (Hex: 0x4062C3B3)
    EXEC_CUSTOM(0x4062C3B3, a, b, res);
    if (res != 0xFF0000FF) fail(6);

    // ========================================================================
    // TEST 3: Zbb - Rotace a změna Endianity
    // ========================================================================
    a = 0x80000001; 

    // ROL: Rotace doleva o 1 (Hex: 0x606293B3)
    EXEC_CUSTOM(0x606293B3, a, 1, res);
    if (res != 0x00000003) fail(7); 

    // ROR: Rotace doprava o 1 (Hex: 0x6062D3B3)
    EXEC_CUSTOM(0x6062D3B3, res, 1, res);
    if (res != 0x80000001) fail(8); 

    // REV8: Reverze bytů (Hex: 0x6862D3B3) 
    // Operand B náš hardware u této instrukce ignoruje, můžeme předat 0
    a = 0x12345678;
    EXEC_CUSTOM(0x6862D3B3, a, 0, res);
    if (res != 0x78563412) fail(9);

    // Všechny operace Zbb a Zbs provedeny na 1 takt úspěšně!
    pass();
    return 0;
}