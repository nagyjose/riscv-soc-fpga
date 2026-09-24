CC = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy

# Vlajky - držíme stejnou hardwarovou výbavu, aby kód přesně pasoval na procesor
CFLAGS = -march=rv32im_zicsr_zbb_zbs -mabi=ilp32 -O0 -ffreestanding -nostdlib

all: ../bootloader.mif

bootloader.elf: bootloader.c crt0.s
	$(CC) $(CFLAGS) -T bootloader.ld $^ -o $@

bootloader.bin: bootloader.elf
	$(OBJCOPY) -O binary $< $@

# Z binárky uděláme .mif o hloubce 256 slov a uložíme o úroveň výš
../bootloader.mif: bootloader.bin
	python mif_gen.py bootloader.bin ../bootloader.mif 256

clean:
	rm -f *.elf *.bin