.section .init
.global _start

_start:
    /* Načteme adresu konce paměti pro zásobník přímo z linker skriptu (_estack) */
    la sp, _estack
    call main
    
end_loop:
    j end_loop
    