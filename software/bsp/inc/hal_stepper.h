#ifndef HAL_STEPPER_H
#define HAL_STEPPER_H

#include <stdint.h>
#include "soc_map.h"

// Směry otáčení
#define STEP_DIR_FWD 0
#define STEP_DIR_BWD 1

// ============================================================================
// NASTAVENÍ RYCHLOSTI
// ============================================================================

// Nastaví rychlost pro konkrétní motor (0 až 7). 
// Rychlost udává počet 10us tiků mezi jednotlivými kroky.
// (Např. speed = 100 znamená 1 ms mezi kroky = 1000 Hz)
void stepper_set_speed(stepper_regs_t* stepper, uint8_t motor_id, uint16_t speed_10us);

// ============================================================================
// INDIVIDUÁLNÍ ŘÍZENÍ (Motor po motoru)
// ============================================================================

// Zapne motor a nastaví jeho směr
void stepper_run(stepper_regs_t* stepper, uint8_t motor_id, uint8_t dir);

// Vypne motor (cívky budou bez proudu)
void stepper_stop(stepper_regs_t* stepper, uint8_t motor_id);

// ============================================================================
// SYNCHRONNÍ ŘÍZENÍ (Pro CNC / Robotiku)
// ============================================================================

// Přímý zápis do řídicího registru. Umožní spustit/zastavit/změnit směr 
// libovolné kombinaci z 8 motorů v jediném taktu procesoru.
void stepper_write_ctrl(stepper_regs_t* stepper, uint32_t ctrl_mask);

// Přečtení aktuálního stavu všech motorů
uint32_t stepper_read_ctrl(stepper_regs_t* stepper);

#endif // HAL_STEPPER_H