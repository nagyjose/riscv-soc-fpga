#include "soc_map.h"
#include "hal_cpu.h"
#include "hal_uart.h"
#include "hal_spi.h"
#include "hal_gpio.h"
#include "hal_mtime.h"

// Definujeme pin 2 jako Chip Select (CS) pro náš fiktivní senzor
#define SENSOR_CS_PIN 2

// ============================================================================
// UKÁZKA 1: OBECNÝ LOOPBACK TEST
// ============================================================================
void test_spi_loopback(void) {
    uart_puts(HW_UART, "\r\n--- 1. SPI Loopback Test ---\r\n");
    uart_puts(HW_UART, "Propoj piny MOSI a MISO dratem!\r\n");
    mtime_delay_ms(HW_MTIME, 2000); // Dáme uživateli čas na propojení

    const char* test_msg = "Ahoj SPI!";
    char rx_buffer[16] = {0};

    // Odesíláme znak po znaku a rovnou chytáme to, co se vrací
    for (int i = 0; test_msg[i] != '\0'; i++) {
        rx_buffer[i] = spi_transfer(HW_SPI, test_msg[i]);
    }

    uart_puts(HW_UART, "Odeslano: ");
    uart_puts(HW_UART, test_msg);
    uart_puts(HW_UART, "\r\nPrijato:  ");
    uart_puts(HW_UART, rx_buffer);
    uart_puts(HW_UART, "\r\n");
}

// ============================================================================
// UKÁZKA 2: ČTENÍ ZE SKUTEČNÉHO SENZORU (např. BME280, akcelerometr atd.)
// ============================================================================
void read_sensor_whoami(void) {
    uart_puts(HW_UART, "\r\n--- 2. Cteni WHO_AM_I registru ---\r\n");

    // Adresa registru, který chceme číst (často se u SPI přidává MSB bit 1 pro čtení)
    uint8_t reg_addr = 0x8F; // Např. registr 0x0F s nastaveným bitem čtení (0x80)
    uint8_t sensor_id = 0;

    // 1. Aktivace senzoru (CS stáhneme k zemi)
    gpio_write_pin(HW_GPIO, SENSOR_CS_PIN, 0);

    // 2. Odeslání adresy registru, který chceme číst
    spi_transfer(HW_SPI, reg_addr);

    // 3. Přečtení odpovědi (odesláním tzv. dummy bytu 0x00 pro generování hodin SCK)
    sensor_id = spi_transfer(HW_SPI, 0x00);

    // 4. Deaktivace senzoru (CS vrátíme do log. 1)
    gpio_write_pin(HW_GPIO, SENSOR_CS_PIN, 1);

    // Výpis zjištěné hodnoty
    uart_puts(HW_UART, "ID Senzoru: 0x");
    
    // Rychlý převod na HEX
    char hex[] = "0123456789ABCDEF";
    uart_putc(HW_UART, hex[(sensor_id >> 4) & 0x0F]);
    uart_putc(HW_UART, hex[sensor_id & 0x0F]);
    uart_puts(HW_UART, "\r\n");
}

// ============================================================================
// HLAVNÍ PROGRAM
// ============================================================================
int main(void) {
    // 1. Inicializace UARTu
    uart_init(HW_UART, 35000000, 115200);

    // 2. Inicializace SPI
    // Cílová frekvence 1 MHz. (Při 35 MHz CPU to ovladač nastaví na děličku 17)
    spi_init(HW_SPI, 35000000, 1000000);

    // 3. Příprava Chip Select pinu
    gpio_set_dir(HW_GPIO, SENSOR_CS_PIN, GPIO_DIR_OUT);
    gpio_write_pin(HW_GPIO, SENSOR_CS_PIN, 1); // CS je v klidu HIGH

    uart_puts(HW_UART, "\r\n=================================\r\n");
    uart_puts(HW_UART, " SDK Demo 4: SPI Master\r\n");
    uart_puts(HW_UART, "=================================\r\n");

    while (1) {
        test_spi_loopback();
        read_sensor_whoami();
        
        uart_puts(HW_UART, "Cekam 5 vterin do dalsiho testu...\r\n");
        mtime_delay_ms(HW_MTIME, 5000);
    }
    
    return 0;
}