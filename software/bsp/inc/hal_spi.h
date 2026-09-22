#ifndef HAL_SPI_H
#define HAL_SPI_H

#include <stdint.h>
#include "soc_map.h" // Obsahuje definici spi_regs_t a HW_SPI

// ============================================================================
// INICIALIZACE SPI
// ============================================================================

// Inicializuje SPI sběrnici na požadovanou rychlost
void spi_init(spi_regs_t* spi, uint32_t sys_clk_hz, uint32_t spi_freq_hz);

// ============================================================================
// PŘENOS DAT
// ============================================================================

// Odešle 1 byte a současně přijme 1 byte (plně duplexní SPI přenos)
uint8_t spi_transfer(spi_regs_t* spi, uint8_t data);

// Blokově odešle pole dat (přijatá data zahazuje)
void spi_write_buffer(spi_regs_t* spi, const uint8_t* tx_data, uint32_t len);

// Blokově přijme pole dat (odesílá "dummy" bajty pro generování hodin)
void spi_read_buffer(spi_regs_t* spi, uint8_t* rx_data, uint32_t len, uint8_t dummy_byte);

#endif // HAL_SPI_H