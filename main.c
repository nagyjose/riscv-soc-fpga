void __attribute__((naked, noreturn)) main() {
    __asm__ volatile (
        "li a0, -4\n\t"         
        "li t1, 0x1000\n\t"      

        // ====================================================================
        // 1. TEST SLOVA (SW, LW)
        // ====================================================================
        "li t2, 0x12345678\n\t"
        "sw t2, 0(t1)\n\t"
        "lw t3, 0(t1)\n\t"
        "nop\n\t" "nop\n\t" "nop\n\t"
        "bne t3, t2, fail_lw\n\t"     

        // ====================================================================
        // 2. TEST PŮLSLOVA (SH, LH, LHU)
        // ====================================================================
        "li t2, 0x8ABC\n\t"
        "sh t2, 4(t1)\n\t"
        
        // Znaménkové čtení (LH)
        "lh t3, 4(t1)\n\t"
        // Dynamické sestavení 0xFFFF8ABC pomocí ALU! (Obejmutí kompilátoru)
        "slli t4, t2, 16\n\t"
        "srai t4, t4, 16\n\t" 
        "nop\n\t" "nop\n\t" "nop\n\t"
        "bne t3, t4, fail_lh\n\t"

        // Neznaménkové čtení (LHU)
        "lhu t3, 4(t1)\n\t"
        "nop\n\t" "nop\n\t" "nop\n\t"
        "bne t3, t2, fail_lhu\n\t" // t2 je 0x00008ABC, což přesně chceme

        // ====================================================================
        // 3. TEST BAJTU (SB, LB, LBU)
        // ====================================================================
        "li t2, 0xFE\n\t"
        "sb t2, 8(t1)\n\t"

        // Znaménkové čtení (LB)
        "lb t3, 8(t1)\n\t"
        "slli t4, t2, 24\n\t"
        "srai t4, t4, 24\n\t" // Dynamicky vyrobí 0xFFFFFFFE
        "nop\n\t" "nop\n\t" "nop\n\t"
        "bne t3, t4, fail_lb\n\t"

        // Neznaménkové čtení (LBU)
        "lbu t3, 8(t1)\n\t"
        "nop\n\t" "nop\n\t" "nop\n\t"
        "bne t3, t2, fail_lbu\n\t" // t2 je 0x000000FE

        // ====================================================================
        // VŠECHNY TESTY PROŠLY!
        // ====================================================================
        "li t6, 1\n\t"
        "sw t6, 0(a0)\n\t"
        "1: j 1b\n\t"

        // ====================================================================
        // CHYBOVÉ VÝPISY (Vypíšou DEAD + reálně načtenou hodnotu z paměti)
        // ====================================================================
    "fail_lw:\n\t"  "lui t6, 0xDEAD0\n\t" "slli t3, t3, 16\n\t" "srli t3, t3, 16\n\t" "or t6, t6, t3\n\t" "sw t6, 0(a0)\n\t" "2: j 2b\n\t"
    "fail_lh:\n\t"  "lui t6, 0xDEAD0\n\t" "slli t3, t3, 16\n\t" "srli t3, t3, 16\n\t" "or t6, t6, t3\n\t" "sw t6, 0(a0)\n\t" "3: j 3b\n\t"
    "fail_lhu:\n\t" "lui t6, 0xDEAD0\n\t" "slli t3, t3, 16\n\t" "srli t3, t3, 16\n\t" "or t6, t6, t3\n\t" "sw t6, 0(a0)\n\t" "4: j 4b\n\t"
    "fail_lb:\n\t"  "lui t6, 0xDEAD0\n\t" "slli t3, t3, 16\n\t" "srli t3, t3, 16\n\t" "or t6, t6, t3\n\t" "sw t6, 0(a0)\n\t" "5: j 5b\n\t"
    "fail_lbu:\n\t" "lui t6, 0xDEAD0\n\t" "slli t3, t3, 16\n\t" "srli t3, t3, 16\n\t" "or t6, t6, t3\n\t" "sw t6, 0(a0)\n\t" "6: j 6b\n\t"
    );
}

// #define MAGIC_ADDR *((volatile unsigned int *)0xFFFFFFFC)

// // Funkce pro nahlášení chyby (do terminálu vypíše přesně, který test selhal)
// void fail(int test_id) {
//     MAGIC_ADDR = 0xDEAD0000 | test_id; // Zápis např. 0xDEAD0003 pro test 3
//     while(1);
// }

// // Funkce pro nahlášení absolutního vítězství
// void pass() {
//     MAGIC_ADDR = 1;
//     while(1);
// }

// int main() {
//     int result;

//     // ========================================================================
//     // TEST 1: ALU & R-Type/I-Type (Matematika a posuny)
//     // Otestuje sčítání záporných čísel, logické operátory a aritmetický posun
//     // ========================================================================
//     __asm__ volatile (
//         "li t1, -8\n\t"       // t1 = -8 (binárně 111...111000)
//         "srai t1, t1, 1\n\t"  // Aritmetický posun vpravo (musí zachovat znaménko -> -4)
//         "xori t1, t1, 2\n\t"  // -4 XOR 2 = -2
//         "addi %0, t1, 0"      // Uložení výsledku do proměnné 'result'
//         : "=r" (result) : : "t1"
//     );
//     if (result != -2) fail(1);

//     // ========================================================================
//     // TEST 2: Forwarding Zkratky (RAW Data Hazard)
//     // EX-to-EX a MEM-to-EX zkratka pro Operand A i B
//     // ========================================================================
//     __asm__ volatile (
//         "li t1, 10\n\t"
//         "li t2, 20\n\t"
//         "add t3, t1, t2\n\t"  // t3 = 30
//         "sub %0, t3, t1"      // Hazard! t3 ještě není v registru zapsané, ale už se čte.
//                               // Hazard Unit musí zapnout forward_a = "10" (EX-to-EX).
//         : "=r" (result) : : "t1", "t2", "t3"
//     );
//     if (result != 20) fail(2);

//     // ========================================================================
//     // TEST 3: Load-Use Hazard (Zamrznutí Pipeline / Stalling)
//     // Otestuje záchrannou brzdu (signál lw_stall), když data z RAM nestíhají
//     // ========================================================================
//     volatile int ram_data = 100; 
//     __asm__ volatile (
//         "lw t2, 0(%1)\n\t"    // Fáze EX jen počítá adresu, data z RAM přijdou až v MEM!
//         "addi %0, t2, 5"      // Kritický hazard! Okamžité použití t2. 
//                               // Hazard unit musí vyhodnotit Load-Use a na 1 takt zmrazit PC a IF/ID.
//         : "=r" (result) 
//         : "r" (&ram_data)     // Předáme assebleru adresu proměnné z RAM
//         : "t2"
//     );
//     if (result != 105) fail(3);

//     // ========================================================================
//     // TEST 4: Řídicí hazardy (Skoky a promazání špatných instrukcí - Flushing)
//     // Otestuje instrukce Branch, JAL a promazání pipeline (flush_if_id)
//     // ========================================================================
//     __asm__ volatile (
//         "li %0, 0\n\t"        // result = 0
//         "li t1, 1\n\t"
//         "beq t1, x0, 1f\n\t"  // Podmínka neplatí (1 != 0), neskáče se!
//         "addi %0, %0, 10\n\t" // Provádí se (result = 10)
//         "j 2f\n\t"            // Nepodmíněný skok (JAL) na návěstí '2'.
//                               // Následující instrukce nateče do pipeline a musí být smazána (Flush)!
//         "1:\n\t"
//         "addi %0, %0, 100\n\t"// Toto nesmí procesor NIKDY vykonat!
//         "2:\n\t"
//         : "+r" (result) : : "t1"
//     );
//     if (result != 10) fail(4);

//     // ========================================================================
//     // TEST 5: Všech 10 R-Type ALU instrukcí (Přísně bez pseudoinstrukcí)
//     // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
//     // ========================================================================
//     __asm__ volatile (
//         // Příprava dat (t1 = 12, t2 = 5)
//         "lui t1, 0\n\t"
//         "addi t1, t1, 12\n\t"
//         "lui t2, 0\n\t"
//         "addi t2, t2, 5\n\t"
        
//         // Samotný test R-Type operací
//         "add  t3, t1, t2\n\t"   // 12 + 5 = 17
//         "sub  t4, t1, t2\n\t"   // 12 - 5 = 7
//         "and  t5, t1, t2\n\t"   // 12 & 5 = 4
//         "or   t6, t1, t2\n\t"   // 12 | 5 = 13
//         "xor  t1, t3, t4\n\t"   // 17 ^ 7 = 22
        
//         // Posuny (Shift)
//         "sll  t2, t4, t5\n\t"   // 7 << 4 = 112
//         "srl  t3, t2, t5\n\t"   // 112 >> 4 = 7
        
//         // Porovnávání (Set Less Than)
//         "slt  t4, t1, t2\n\t"   // Je 22 < 112? Ano -> 1
        
//         // Akumulace (Checksum = 22 + 112 + 7 + 1 = 142)
//         "add  %0, x0, t1\n\t"   // %0 = 22
//         "add  %0, %0, t2\n\t"   // 22 + 112 = 134
//         "add  %0, %0, t3\n\t"   // 134 + 7 = 141
//         "add  %0, %0, t4\n\t"   // 141 + 1 = 142
//         : "=r" (result) 
//         : : "t1", "t2", "t3", "t4", "t5", "t6"
//     );
//     if (result != 142) fail(5);

//     // ========================================================================
//     // TEST 6: B-Type větvení (BEQ, BNE, BLT, BGE, BLTU, BGEU)
//     // Záměrně skáčeme dopředu i dozadu
//     // ========================================================================
//     __asm__ volatile (
//         "lui %0, 0\n\t"          // result = 0
//         "addi t1, x0, -5\n\t"    // t1 = -5
//         "addi t2, x0, 10\n\t"    // t2 = 10
        
//         // Znaménkové vs. Neznaménkové porovnání (Klíčový test ALU!)
//         "blt  t1, t2, 1f\n\t"    // -5 < 10 (Znaménkově PRAVDA) -> Skočí na 1
//         "addi %0, x0, 999\n\t"   // Tohle se nesmí stát!
        
//         "1:\n\t"
//         "bgeu t1, t2, 2f\n\t"    // -5 jako neznaménkové je obrovské číslo! Je >= 10 (PRAVDA) -> Skočí na 2
//         "addi %0, x0, 999\n\t"   // Nesmí se stát!
        
//         "2:\n\t"
//         "addi %0, x0, 42\n\t"    // Výsledek úspěchu
//         : "=r" (result) 
//         : : "t1", "t2"
//     );
//     if (result != 42) fail(6);

//     // ========================================================================
//     // TEST 73: Izolace LH (Na fyzické adrese)
//     // ========================================================================
//     int read_val;
//     __asm__ volatile (
//         "li t1, 0x89ABCDEF\n\t"
//         "li t2, 0x10\n\t"          // Fyzická adresa 16 v RAM (bezpečně uvnitř)
        
//         "sw t1, 0(t2)\n\t"
//         "lh %0, 0(t2)\n\t"
//         : "=r" (read_val)
//         : 
//         : "t1", "t2"
//     );
    
//     if (read_val != (int)0xFFFFCDEF) {
//         if (read_val == 0x0000CDEF) fail(730);
//         else fail(read_val & 0xFFFF);
//     }

//     // ========================================================================
//     // TEST 8: Store instrukce (Na fyzické adrese)
//     // ========================================================================
//     unsigned int verify_sw, verify_sh, verify_sb;
//     __asm__ volatile (
//         "li t1, 0x11223344\n\t"
//         "li t2, -1\n\t"
//         "li t3, 170\n\t"
//         "li t4, 0x14\n\t"          // Fyzická adresa 20 v RAM
        
//         "sw t1, 0(t4)\n\t"
//         "lw %0, 0(t4)\n\t"
        
//         "sh t2, 0(t4)\n\t"
//         "lw %1, 0(t4)\n\t"
        
//         "sb t3, 2(t4)\n\t"
//         "lw %2, 0(t4)\n\t"
        
//         : "=&r" (verify_sw), "=&r" (verify_sh), "=&r" (verify_sb)
//         : 
//         : "t1", "t2", "t3", "t4"
//     );
    
//     if (verify_sw != 0x11223344) fail(81);
//     if (verify_sh != 0x1122FFFF) fail(82);
//     if (verify_sb != 0x11AAFFFF) fail(83);
    
//     // __asm__ volatile (
//     //     "lb   t1, 0(%2)\n\t"       // t1 = -17 (0xFFFFFFEF)
//     //     "lbu  t2, 0(%2)\n\t"       // t2 = 239 (0x000000EF)
//     //     "lh   t3, 0(%2)\n\t"       // t3 = -12817 (0xFFFFCDEF)
//     //     "lhu  t4, 0(%2)\n\t"       // t4 = 52719 (0x0000CDEF)
//     //     "lw   %1, 0(%2)\n\t"       // Načtení celého slova (jde rovnou do %1)
        
//     //     // Sečteme všechny menší loady do jednoho kontrolního součtu
//     //     "add  %0, x0, t1\n\t"
//     //     "add  %0, %0, t2\n\t"
//     //     "add  %0, %0, t3\n\t"
//     //     "add  %0, %0, t4\n\t"
//     //     : "=r" (res_load), "=r" (res_lw)
//     //     : "r" (&load_data)
//     //     : "t1", "t2", "t3", "t4"
//     // );
    
//     // // Matematika: -17 + 239 - 12817 + 52719 = 40124
//     // if (res_load != 40124) fail(70); 
//     // if (res_lw != (int)0x89ABCDEF) fail(75);

//     // // ========================================================================
//     // // TEST 8: Store instrukce (SB, SH, SW)
//     // // Testujeme správné maskování bajtů v paměti RAM a offsety
//     // // ========================================================================
//     // volatile unsigned int store_data = 0;
//     // unsigned int verify_sw, verify_sh, verify_sb;
    
//     // __asm__ volatile (
//     //     Příprava dat v registrech pomocí čistých I/U instrukcí
//     //     "lui t1, 0x11223\n\t"
//     //     "addi t1, t1, 0x344\n\t"  // t1 = 0x11223344
//     //     "addi t2, x0, -1\n\t"     // t2 = 0xFFFFFFFF
//     //     "addi t3, x0, 170\n\t"    // t3 = 0xAA (170)
        
//     //     1. Zápis celého slova (SW) a jeho kontrola
//     //     "sw t1, 0(%3)\n\t"
//     //     "lw %0, 0(%3)\n\t"
        
//     //     2. Zápis poloviny slova (SH) na offset 0
//     //     Přepíše pouze spodní dva bajty na FF FF. 
//     //     RAM by nyní měla obsahovat: 0x1122FFFF
//     //     "sh t2, 0(%3)\n\t"
//     //     "lw %1, 0(%3)\n\t"
        
//     //     3. Zápis jednoho bajtu (SB) na posunutý offset 2
//     //     Přepíše konkrétně bajt číslo 2 (z 0x22 na 0xAA).
//     //     RAM by nyní měla obsahovat: 0x11AAFFFF
//     //     "sb t3, 2(%3)\n\t"
//     //     "lw %2, 0(%3)\n\t"
        
//     //     : "=&r" (verify_sw), "=&r" (verify_sh), "=&r" (verify_sb)
//     //     : "r" (&store_data)
//     //     : "t1", "t2", "t3"
//     // );
    
//     // if (verify_sw != 0x11223344) fail(8);
//     // if (verify_sh != 0x1122FFFF) fail(8);
//     // if (verify_sb != 0x11AAFFFF) fail(8);

//     // ========================================================================
//     // TEST 9: I-Type ALU operace s bezprostřední hodnotou
//     // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
//     // ========================================================================
//     int res_itype;
//     __asm__ volatile (
//         "addi t1, x0, -10\n\t"    // t1 = -10 (0xFFFFFFF6)
        
//         // Porovnávání (Signed vs Unsigned)
//         "slti t2, t1, -5\n\t"     // -10 < -5 -> Pravda (t2 = 1)
//         "sltiu t3, t1, 10\n\t"    // Unsigned -10 (obrovské číslo) < 10 -> Nepravda (t3 = 0)
        
//         // Logické operace
//         "xori t4, t2, 15\n\t"     // 1 ^ 15 = 14
//         "ori  t5, t4, 16\n\t"     // 14 | 16 = 30
//         "andi t6, t5, 26\n\t"     // 30 (11110) & 26 (11010) = 26
        
//         // Bitové posuny
//         "slli t1, t6, 2\n\t"      // 26 << 2 = 104
//         "srli t2, t1, 1\n\t"      // 104 >> 1 = 52
//         "srai t3, t1, 2\n\t"      // 104 >> 2 = 26 
        
//         // Kaskádový Checksum
//         "add  %0, x0, t1\n\t"     // 104
//         "add  %0, %0, t2\n\t"     // 104 + 52 = 156
//         "add  %0, %0, t3\n\t"     // 156 + 26 = 182
//         : "=r" (res_itype)
//         : : "t1", "t2", "t3", "t4", "t5", "t6"
//     );
//     if (res_itype != 182) fail(9);

//     // ========================================================================
//     // TEST 10: Manipulace s PC (AUIPC, JAL, JALR)
//     // Nejtěžší zkouška pro datovou cestu - kontrola ukládání návratových adres
//     // ========================================================================
//     int res_auipc, res_jal, res_jalr;
//     __asm__ volatile (
//         // 1. AUIPC Test (Načte aktuální PC do registru)
//         "auipc t1, 0\n\t"        // t1 = aktuální PC (této instrukce)
//         "auipc t2, 0\n\t"        // t2 = aktuální PC (o 4 bajty dále)
//         "sub %0, t2, t1\n\t"     // Rozdíl musí být přesně 4!
        
//         // 2. JAL Test (Jump and Link - relativní skok)
//         "jal t3, 1f\n\t"         // Skok na návěstí '1'. Do t3 uloží adresu vrácení (PC po JAL)
//         "addi %1, x0, 999\n\t"   // Sem se procesor nesmí dostat (JAL ho přeskočí)
//         "1:\n\t"
//         "auipc t4, 0\n\t"        // Získáme adresu tohoto návěstí
//         "sub %1, t4, t3\n\t"     // Rozdíl návratové adresy a adresy po skoku musí být přesně 4!
        
//         // 3. JALR Test (Jump and Link Register - absolutní skok přes registr)
//         "auipc t5, 0\n\t"        // t5 = PC této instrukce
//         "addi t5, t5, 16\n\t"    // Manuálně spočítáme adresu návěstí '3' (o 4 instrukce dále)
//         "jalr t6, t5, 0\n\t"     // Skok na t5. Do t6 uloží adresu vrácení (návěstí '2')
//         "2:\n\t"
//         "addi %2, x0, 999\n\t"   // Sem se procesor nesmí dostat
//         "3:\n\t"
//         "auipc t1, 0\n\t"        // Získáme adresu tohoto návěstí
//         "sub %2, t1, t6\n\t"     // Rozdíl aktuální adresy a adresy v t6 musí být přesně 4!
        
//         : "=r" (res_auipc), "=r" (res_jal), "=r" (res_jalr)
//         : : "t1", "t2", "t3", "t4", "t5", "t6"
//     );
    
//     if (res_auipc != 4) fail(10);
//     if (res_jal != 4) fail(10);
//     if (res_jalr != 4) fail(10);

//     // Pokud program úspěšně prošel všemi překážkami, nahlásí absolutní vítězství!
//     pass();
    
//     return 0;
// }