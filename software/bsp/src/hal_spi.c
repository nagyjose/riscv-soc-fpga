#include "hal_spi.h"

// ============================================================================
// INICIALIZACE SPI
// ============================================================================

void spi_init(spi_regs_t* spi, uint32_t sys_clk_hz, uint32_t spi_freq_hz) {
    // VHDL generátor hodin vyžaduje hodnotu pro POLOVIČNÍ periodu
    // Výpočet: r_baud_half = SYS_CLK_FREQ / (2 * SPI_FREQ)
    spi->BAUD = sys_clk_hz / (2 * spi_freq_hz);
}

// ============================================================================
// PŘENOS DAT
// ============================================================================

uint8_t spi_transfer(spi_regs_t* spi, uint8_t data) {
    // 1. Zápis do registru DATA odstartuje hardwarový automat
    spi->DATA = data;
    
    // 2. Čekáme, dokud je sběrnice zaneprázdněná (Bit 0 v registru STATUS = 1)
    while (spi->STATUS & 0x01) {
        // Blokující smyčka čeká na odtikání 8 hodinových pulzů
    }
    
    // 3. Po skončení leží výsledek opět v registru DATA
    return (uint8_t)spi->DATA;
}

void spi_write_buffer(spi_regs_t* spi, const uint8_t* tx_data, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) {
        spi_transfer(spi, tx_data[i]); // Vrácená data ignorujeme
    }
}

void spi_read_buffer(spi_regs_t* spi, uint8_t* rx_data, uint32_t len, uint8_t dummy_byte) {
    for (uint32_t i = 0; i < len; i++) {
        // Pro vyčtení senzoru musíme neustále odesílat fiktivní data (dummy), 
        // abychom vygenerovali hodiny pro čtení (SCK)
        rx_data[i] = spi_transfer(spi, dummy_byte);
    }
}