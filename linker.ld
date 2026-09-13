MEMORY
{
    /* Nyní máme jednotnou RAM pro kód i data o velikosti 8 KB */
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS
{
    .text : {
        *(.init)
        *(.text*)
    } > RAM
    
    .data : {
        *(.data*)
        *(.sdata*)
    } > RAM
    
    .bss : {
        *(.bss*)
        *(.sbss*)
    } > RAM
}