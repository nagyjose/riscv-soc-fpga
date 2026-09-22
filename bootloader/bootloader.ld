MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 1K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 10K
}
SECTIONS
{
    .text : {
        *(.init)
        *(.text*)
        *(.rodata*)
    } > ROM
    /* Data bootloaderu (pokud nějaká jsou) jdou do RAM */
    .data : { *(.data*) } > RAM
    .bss :  { *(.bss*)  } > RAM
}