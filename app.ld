MEMORY
{
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 11K
}
SECTIONS
{
    .text : {
        *(.init)
        *(.text*)
        *(.rodata*)
    } > RAM
    .data : { *(.data*) } > RAM
    .bss :  { *(.bss*)  } > RAM
}