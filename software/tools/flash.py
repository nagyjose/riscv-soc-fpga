import serial
import time
import struct
import sys
import os

if len(sys.argv) < 3:
    print("Pouziti: python tools/flash.py <port> <soubor.bin>")
    sys.exit(1)

PORT = sys.argv[1]
BIN_FILE = sys.argv[2]
BAUD = 115200

try:
    with open(BIN_FILE, "rb") as f:
        app_data = f.read()
except FileNotFoundError:
    print(f"Chyba: Soubor {BIN_FILE} nebyl nalezen.")
    sys.exit(1)

print(f"[*] Oteviram port {PORT} na {BAUD} bd...")
try:
    ser = serial.Serial(PORT, BAUD, timeout=2)
except serial.SerialException as e:
    print(f"[!] Nelze otevrit port {PORT}: {e}")
    sys.exit(1)

# 1. Hardwarový reset procesoru přes DTR pin
print("[*] Resetuji procesor...")
ser.dtr = True  
time.sleep(0.1)
ser.dtr = False 
time.sleep(0.1)

# 2. Žádost o bootloader - magický znak 'B'
print("[*] Odesilam 'B' (Zadost o boot)...")
ser.write(b'B')

# 3. Odeslání velikosti programu (4 byty)
size_bytes = struct.pack('<I', len(app_data))
ser.write(size_bytes)
print(f"[*] Odesilam velikost: {len(app_data)} bytu")

# 4. Odeslání samotné aplikace
print("[*] Odesilam binarni data...")
ser.write(app_data)

# 5. Čekání na potvrzení od bootloaderu
print("[*] Cekam na potvrzeni od bootloaderu...")
response = ser.read(1)
if response == b'K':
    print(f"\n[SUCCESS] Aplikace {os.path.basename(BIN_FILE)} uspesne nahrana a spustena!")
else:
    print(f"\n[ERROR] Bootloader neodpovedel spravne (prijato: {response})")

ser.close()