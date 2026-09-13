.section .init
.global _start

_start:
    /* Nastavení Stack Pointeru (sp) na konec naší 8KB RAM (2048 slov * 4 = 8192) */
    li sp, 8192
    call main
    
end_loop:
    j end_loop
    