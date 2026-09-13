import sys
import struct

with open("program.bin", "rb") as f:
    data = f.read()

with open("program.hex", "w") as f:
    for i in range(0, len(data), 4):
        chunk = data[i:i+4]
        chunk += b'\x00' * (4 - len(chunk))
        
        # struct.unpack("<I") bezpečně převede 4 bajty na little-endian unsigned integer
        val = struct.unpack("<I", chunk)[0]
        
        # .format() bezpečně funguje i na starých verzích Pythonu
        f.write("{:08x}\n".format(val))