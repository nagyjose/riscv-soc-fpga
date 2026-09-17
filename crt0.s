.section .init
.global _start

_start:
    /* Konec RAM = 0x20000000 + 11 KB (0x2C00) */
    li sp, 0x20002C00
    call main
    
end_loop:
    j end_loop
    