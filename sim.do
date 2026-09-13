# Smazání a vytvoření čisté knihovny
vlib work

# 1. NEJPRVE BALÍČKY (Zde jsou definice, které ostatní potřebují)
vcom pkg_riscv.vhd

# 2. ZÁKLADNÍ MODULY (Nezávislé bloky)
vcom alu.vhd
vcom imm_gen.vhd
vcom reg_file.vhd
vcom control_unit.vhd
vcom hazard_unit.vhd
vcom branch_unit.vhd
vcom store_formatter.vhd
vcom load_formatter.vhd
vcom dual_port_ram.vhd

# 3. DATOVÁ CESTA A TOP-LEVEL (Spojují předchozí moduly dohromady)
vcom datapath.vhd
vcom riscv_core.vhd

# 4. SIMULAČNÍ PAMĚTI
vcom inst_rom.vhd
vcom data_ram.vhd

# 5. TESTBENCH (Úplně nakonec)
vcom tb_riscv_core.vhd

# Spuštění simulace, nahrávání signálů a bezpečné ukončení
vsim -c tb_riscv_core
vcd file wave.vcd
vcd add -r /tb_riscv_core/*

# Co má ModelSim udělat, když ho testbench zastaví
onbreak {quit -f}

# Necháme to běžet, dokud testbench sám neřekne "Konec!"
run -all
quit -f