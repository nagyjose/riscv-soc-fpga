#!/bin/bash

# 1. Přidání ModelSimu do cesty (abychom nemuseli psát tu dlouhou složku)
export PATH=$PATH:/home/fpga_user/altera/13.0sp1/modelsim_ase/linuxaloem

echo "=========================================="
echo "🚀   Spouštím kompilaci a simulaci..."
echo "=========================================="

# 2. Spuštění ModelSimu na pozadí s naším .do skriptem
vsim -c -do sim.do

# 3. Kontrola, zda simulace nespadla (zda nevznikl error ve VHDL)
if [ $? -eq 0 ]; then
    echo "================================================="
    echo "✅   Simulace dokončena! Otevírám GTKWave..."
    echo "================================================="
    
    # 4. Spuštění GTKWave s naším souborem na pozadí (znak &)
    gtkwave wave.vcd &
else
    echo "======================================================"
    echo "❌   CHYBA: Simulace selhala. Zkontroluj log výše."
    echo "======================================================"
fi