#include "hal_stepper.h"

// ============================================================================
// NASTAVENÍ RYCHLOSTI
// ============================================================================

void stepper_set_speed(stepper_regs_t* stepper, uint8_t motor_id, uint16_t speed_10us) {
    if (motor_id > 7) return; // Ochrana proti přetečení
    
    // Zjistíme, do kterého 32b registru budeme zapisovat (0 až 3)
    uint8_t reg_idx = motor_id / 2;
    
    // Zjistíme, zda motor sedí v dolních (0) nebo horních (1) 16 bitech registru
    uint8_t is_upper = motor_id % 2;
    
    // Přečteme aktuální stav registru, abychom nepřepsali rychlost sousedního motoru
    uint32_t current_val = stepper->SPEED[reg_idx];
    
    if (is_upper) {
        // Vymažeme horních 16 bitů a vložíme novou rychlost[cite: 25]
        current_val = (current_val & 0x0000FFFF) | ((uint32_t)speed_10us << 16);
    } else {
        // Vymažeme dolních 16 bitů a vložíme novou rychlost[cite: 25]
        current_val = (current_val & 0xFFFF0000) | speed_10us;
    }
    
    // Zápis zpět do hardwaru
    stepper->SPEED[reg_idx] = current_val;
}

// ============================================================================
// INDIVIDUÁLNÍ ŘÍZENÍ (Motor po motoru)
// ============================================================================

void stepper_run(stepper_regs_t* stepper, uint8_t motor_id, uint8_t dir) {
    if (motor_id > 7) return;
    
    // Každý motor má vyhrazené 2 bity: Enable a Dir[cite: 20]
    // Motor 0: bity 0,1. Motor 1: bity 2,3. Motor X: bity X*2, X*2+1
    uint8_t bit_shift = motor_id * 2;
    
    uint32_t ctrl = stepper->CTRL;
    
    // 1. Vymažeme oba staré bity (Enable i Dir) pro tento motor
    ctrl &= ~(3 << bit_shift); 
    
    // 2. Poskládáme nové bity: (1 = Enable) | (dir << 1)
    uint32_t motor_bits = 1 | ((dir & 0x01) << 1);
    
    // 3. Vložíme je na správnou pozici a zapíšeme do HW[cite: 25]
    ctrl |= (motor_bits << bit_shift);
    stepper->CTRL = ctrl;
}

void stepper_stop(stepper_regs_t* stepper, uint8_t motor_id) {
    if (motor_id > 7) return;
    
    // Nulování pouze Enable bitu (bit na pozici motor_id * 2)[cite: 20]
    stepper->CTRL &= ~(1 << (motor_id * 2));
}

// ============================================================================
// SYNCHRONNÍ ŘÍZENÍ
// ============================================================================

void stepper_write_ctrl(stepper_regs_t* stepper, uint32_t ctrl_mask) {
    stepper->CTRL = ctrl_mask;
}

uint32_t stepper_read_ctrl(stepper_regs_t* stepper) {
    return stepper->CTRL;
}