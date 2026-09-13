import sys
import struct

with open("program.bin", "rb") as f:
    data = f.read()

# Zarovnání dat, aby byla dělitelná 4 (celá 32bitová slova)
while len(data) % 4 != 0:
    data += b'\x00'

WORDS = 2048 # Velikost naší paměti

with open("program.mif", "w") as f:
    f.write("DEPTH = {};\n".format(WORDS))
    f.write("WIDTH = 32;\n")
    f.write("ADDRESS_RADIX = HEX;\n")
    f.write("DATA_RADIX = HEX;\n")
    f.write("CONTENT BEGIN\n")
    
    address = 0
    for i in range(0, len(data), 4):
        chunk = data[i:i+4]
        val = struct.unpack("<I", chunk)[0]
        # Formát MIF: Adresa : Hodnota;
        f.write("{:X} : {:08X};\n".format(address, val))
        address += 1
        
    # Zbytek paměti natvrdo vyplníme nulami
    if address < WORDS:
        f.write("[{:X}..{:X}] : 00000000;\n".format(address, WORDS-1))
        
    f.write("END;\n")