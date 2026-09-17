import sys
import struct

if len(sys.argv) != 4:
    print("Pouziti: python3 mif_gen.py <vstup.bin> <vystup.mif> <hloubka_ve_slovech>")
    sys.exit(1)

in_file = sys.argv[1]
out_file = sys.argv[2]
WORDS = int(sys.argv[3])

with open(in_file, "rb") as f:
    data = f.read()

while len(data) % 4 != 0:
    data += b'\x00'

with open(out_file, "w") as f:
    f.write("DEPTH = {};\n".format(WORDS))
    f.write("WIDTH = 32;\n")
    f.write("ADDRESS_RADIX = HEX;\n")
    f.write("DATA_RADIX = HEX;\n")
    f.write("CONTENT BEGIN\n")
    
    address = 0
    for i in range(0, len(data), 4):
        chunk = data[i:i+4]
        val = struct.unpack("<I", chunk)[0]
        f.write("{:X} : {:08X};\n".format(address, val))
        address += 1
        
    if address < WORDS:
        f.write("[{:X}..{:X}] : 00000000;\n".format(address, WORDS-1))
        
    f.write("END;\n")