# ==============================================================================
# NASTAVENÍ PROJEKTU
# ==============================================================================
# Výchozí aplikace (zkompiluje se, pokud nezadáš make APP=...)
APP ?= demo_io
# Výchozí COM port pro nahrávání (lze přepsat přes make flash PORT=COMx)
PORT ?= COM12

# Nástroje (z tvého xPack GCC a Build Tools)
CC = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy

# Konfigurace HW a kompilátoru
CFLAGS = -march=rv32im_zicsr_zbb_zbs -mabi=ilp32 -O2 -ffreestanding -nostdlib
INCLUDES = -I./bsp/inc
# Odkazujeme na tvůj přejmenovaný linkovací skript
LDFLAGS = -T bsp/link.ld -Wl,-Map=build/$(APP)/$(APP).map

# ==============================================================================
# CESTY A SOUBORY
# ==============================================================================
BUILD_DIR = build/$(APP)

# Zdrojové kódy: Konkrétní aplikace + všechny HAL drivery + startovací kód
SRCS = apps/$(APP).c $(wildcard bsp/src/*.c) bsp/crt0.s

# Výstupní soubory budou bezpečně uloženy v izolované složce projektu
ELF = $(BUILD_DIR)/$(APP).elf
BIN = $(BUILD_DIR)/$(APP).bin

# ==============================================================================
# PRAVIDLA KOMPILACE
# ==============================================================================
.PHONY: all clean flash directories

all: directories $(BIN)

# Vytvoření složky projektu v rámci build/
directories:
	@mkdir -p $(BUILD_DIR)

# Sloučení všech zdrojáků do jedné ELF binárky
$(ELF): $(SRCS)
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) $^ -o $@

# Extrakce čistého binárního souboru pro nahrávač
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@
	@echo "=========================================================="
	@echo " [SUCCESS] Aplikace '$(APP)' byla zkompilovana!"
	@echo " Vystup: $(BIN)"
	@echo "=========================================================="

# Automatické nahrání do FPGA
flash: all
	python tools/flash.py $(PORT) $(BIN)

# Úklid
clean:
	rm -rf build/*