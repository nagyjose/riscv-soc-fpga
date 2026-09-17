vlib work
vcom alu.vhd 
vcom tb_alu.vhd
vsim -c tb_alu
onbreak {quit -f}
run -all
quit -f