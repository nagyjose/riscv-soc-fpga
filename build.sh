#!/bin/bash
GCC_PATH="./../../riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14/bin"

echo "--- 1. Kompiluji Bootloader ---"
$GCC_PATH/riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -Os -T bootloader.ld crt0.s bootloader.c -o bootloader.elf
$GCC_PATH/riscv64-unknown-elf-objcopy -O binary bootloader.elf bootloader.bin
python3 mif_gen.py bootloader.bin bootloader.mif 256

echo "--- 2. Kompiluji Uživatelskou Aplikaci ---"
$GCC_PATH/riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -O2 -T app.ld crt0.s main.c -o program.elf
$GCC_PATH/riscv64-unknown-elf-objcopy -O binary program.elf program.bin
python3 mif_gen.py program.bin program.mif 2816

echo "Hotovo! Vygenerován bootloader.mif i program.mif."