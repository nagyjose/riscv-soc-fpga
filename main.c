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
// MAGIE .insn DIREKTIVY
// Syntaxe: .insn r opcode, funct3, funct7, rd, rs1, rs2
// Opcode pro naše ALU operace je 0x33 (0110011 v bináru).
// %0, %1, %2 jsou dynamické registry, které si GCC samo bezpečně vybere!
// ============================================================================
#define BSET(rd, rs1, rs2) __asm__ volatile (".insn r 0x33, 1, 0x14, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))
#define BINV(rd, rs1, rs2) __asm__ volatile (".insn r 0x33, 1, 0x34, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))
#define BCLR(rd, rs1, rs2) __asm__ volatile (".insn r 0x33, 1, 0x24, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))
#define BEXT(rd, rs1, rs2) __asm__ volatile (".insn r 0x33, 5, 0x24, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

#define ANDN(rd, rs1, rs2) __asm__ volatile (".insn r 0x33, 7, 0x20, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))
#define XNOR(rd, rs1, rs2) __asm__ volatile (".insn r 0x33, 4, 0x20, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

#define ROL(rd, rs1, rs2)  __asm__ volatile (".insn r 0x33, 1, 0x30, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))
#define ROR(rd, rs1, rs2)  __asm__ volatile (".insn r 0x33, 5, 0x30, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

// REV8 ignoruje druhý operand, pošleme tam přes kompilátor konstantu 0
#define REV8(rd, rs1)      __asm__ volatile (".insn r 0x33, 5, 0x34, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(0))

int main() {
    unsigned int a, b, res;

    // ========================================================================
    // TEST 1: Zbs - Práce s jednotlivými bity
    // ========================================================================
    a = 0x00000000;
    
    BSET(res, a, 4);
    if (res != 0x00000010) fail(1);

    BINV(res, res, 4); // Zhasne bit 4
    BINV(res, res, 0); // Rozsvítí bit 0
    if (res != 0x00000001) fail(2);

    BCLR(res, res, 0);
    if (res != 0x00000000) fail(3);

    a = 0x80000000;
    BEXT(res, a, 31);
    if (res != 1) fail(4);

    // ========================================================================
    // TEST 2: Zbb - Logické operace (ANDN, XNOR)
    // ========================================================================
    a = 0x0000FFFF;
    b = 0x00FF00FF; 

    __asm__ volatile ("nop");
    ANDN(res, a, b);
    if (res != 0x0000FF00) fail(5);

    XNOR(res, a, b);
    if (res != 0xFF0000FF) fail(6);

    // ========================================================================
    // TEST 3: Zbb - Rotace a změna Endianity
    // ========================================================================
    a = 0x80000001; 
    
    ROL(res, a, 1);
    if (res != 0x00000003) fail(7); 

    ROR(res, res, 1);
    if (res != 0x80000001) fail(8); 

    a = 0x12345678;
    REV8(res, a);
    if (res != 0x78563412) fail(9);

    pass();
    return 0;
}