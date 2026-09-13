#!/bin/bash

# Cesta ke staženému SiFive kompilátoru
GCC_PATH="./../../riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14/bin"

echo "1. Kompiluji C kód a startup..."
$GCC_PATH/riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T linker.ld crt0.s main.c -o program.elf

echo "2. Extrahuji surová binární data..."
$GCC_PATH/riscv64-unknown-elf-objcopy -O binary program.elf program.bin

echo "3. Generuji program.hex pro ModelSim (VHDL TextIO)..."
python3 hex_gen.py

echo "4. Generuji program.mif pro Quartus (BRAM Init)..."
python3 mif_gen.py

echo "Hotovo! Vše je připraveno."