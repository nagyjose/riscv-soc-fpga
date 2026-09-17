import sys
import time
import struct
import argparse
try:
    import serial
except ImportError:
    print("Chyba: Chybí knihovna pyserial. Nainstaluj ji pomocí 'pip install pyserial'")
    sys.exit(1)

def main():
    # 1. Zpracování parametrů příkazové řádky
    parser = argparse.ArgumentParser(description="RISC-V Bootloader Uploader")
    parser.add_argument("port", help="Sériový port (např. /dev/ttyUSB0 nebo COM3)")
    parser.add_argument("file", help="Zkompilovaný binární program (.bin)")
    args = parser.parse_args()

    # 2. Načtení binárních dat
    try:
        with open(args.file, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        print(f"Chyba: Soubor '{args.file}' nenalezen!")
        sys.exit(1)

    print(f"Otevírám port {args.port} na 115200 baudů...")
    try:
        # Timeout 2 vteřiny pro případ, že FPGA neodpoví
        ser = serial.Serial(args.port, 115200, timeout=2)
    except serial.SerialException as e:
        print(f"Chyba při otevírání portu: {e}")
        sys.exit(1)

    # 3. Hardwarový Reset FPGA (DTR pin)
    print("Provádím hardwarový reset FPGA (DTR pin)...")
    # V pyserial ser.dtr = True obvykle stáhne pin k zemi (LOW / 0V)
    ser.dtr = True
    time.sleep(0.1) # Držíme procesor v resetu 100 ms
    
    # ser.dtr = False pin uvolní (HIGH / 3.3V)
    ser.dtr = False
    time.sleep(0.1) # Dáme bootloaderu 100 ms na probuzení a inicializaci

    # 4. Odeslání hlavičky
    print(f"Odesílám magické slovo 'B' a velikost ({len(data)} Bytů)...")
    ser.write(b'B')
    
    # struct.pack('<I', ...) bezpečně převede integer na 4 byty (Little Endian)
    ser.write(struct.pack('<I', len(data)))

    # 5. Odeslání dat
    print("Odesílám program (může to chvíli trvat)...")
    ser.write(data)
    
    # Počkáme, až operační systém fyzicky vyprázdní odesílací buffer přes USB
    ser.flush() 

    # 6. Vyhodnocení odpovědi
    print("Čekám na potvrzení od procesoru ('K')...")
    response = ser.read(1)

    if response == b'K':
        print("==================================================")
        print("  [ SUCCESS ] Program úspěšně nahrán a spuštěn!")
        print("==================================================")
    else:
        print("==================================================")
        print("  [ ERROR ] Procesor neodpověděl nebo vypršel čas.")
        print("==================================================")
        
    ser.close()

if __name__ == "__main__":
    main()