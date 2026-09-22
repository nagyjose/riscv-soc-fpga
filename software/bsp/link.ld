MEMORY {
    /* Hlavní paměť podle tvého VHDL adresního dekodéru */
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 10K
}

SECTIONS {
    .text : {
        *(.init)      /* Startovací kód musí být na začátku */
        *(.text*)     /* Kód funkcí */
        *(.rodata*)   /* Konstanty a textové řetězce */
    } > RAM

    .data : {
        *(.data*)     /* Inicializované globální proměnné */
    } > RAM

    .bss : {
        *(.bss*)      /* Nulované globální proměnné */
    } > RAM

    /* Ukazatel na konec paměti pro zásobník (Stack) */
    _estack = ORIGIN(RAM) + LENGTH(RAM);
}