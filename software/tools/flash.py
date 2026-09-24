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

# ==============================================================================
# 0. Načtení souboru
# ==============================================================================
try:
    with open(BIN_FILE, "rb") as f:
        app_data = f.read()
except FileNotFoundError:
    print(f"Chyba: Soubor {BIN_FILE} nebyl nalezen.")
    sys.exit(1)

# ==============================================================================
# 1. Bezpečné otevření portu
# ==============================================================================
print(f"[*] Oteviram port {PORT} na {BAUD} bd...")
try:
    # Přidán write_timeout! Pokud port neexistuje nebo je zaseknutý, skript spadne s chybou.
    ser = serial.Serial(PORT, BAUD, timeout=2.0, write_timeout=2.0)
except serial.SerialException as e:
    print(f"[!] Nelze otevrit port {PORT}.")
    print(f"    Je spravne napsany a neni blokovan jinym programem (napr. Putty)?")
    print(f"    Detail chyby: {e}")
    sys.exit(1)

# ==============================================================================
# 2. Reset procesoru
# ==============================================================================
print("[*] Provadim hardwarovy reset pres DTR (pokud je zapojen)...")
try:
    ser.dtr = True  
    time.sleep(0.1)
    ser.dtr = False 
    time.sleep(0.1)
except Exception:
    pass

print("\n=======================================================")
print(" POKUD PREVODNIK NEMA DTR PIN (napr. HW-597):")
print(" 1. Kratce stisknete a PUSTTE tlacitko RESET na FPGA.")
print(" 2. Az pote stisknete klavesu ENTER zde v terminalu.")
print("=======================================================\n")

# Skript se zde zastaví a čeká. 
# Díky tomu má bootloader na FPGA čas nastartovat a čekat na znak 'B'.
input("Cekam na stisk ENTER pro zahajeni prenosu...")

try:
    # Těsně před odesláním vyčistíme přijímací buffer od případného šumu z resetu
    ser.reset_input_buffer()
except Exception:
    pass

# ==============================================================================
# 3. Odesílání dat do Bootloaderu
# ==============================================================================
try:
    # Žádost o bootloader - magický znak 'B'[cite: 4]
    print("[*] Odesilam 'B' (Zadost o boot)...")
    ser.write(b'B')
    ser.flush() # Vynutí fyzické odeslání z OS do USB čipu

    # Odeslání velikosti programu (4 byty)[cite: 4]
    size_bytes = struct.pack('<I', len(app_data))
    print(f"[*] Odesilam velikost: {len(app_data)} bytu...")
    ser.write(size_bytes)
    ser.flush()

    # Odeslání samotné aplikace[cite: 4]
    print("[*] Odesilam binarni data aplikace...")
    ser.write(app_data)
    ser.flush()

except serial.SerialTimeoutException:
    print("\n[!] CHYBA: Vyprsel casovy limit pro zapis (Write Timeout)!")
    print("           Prenos zamrznul. Zkontrolujte fyzicke pripojeni USB prevodniku.")
    ser.close()
    sys.exit(1)
except Exception as e:
    print(f"\n[!] NEOCEKAVANA CHYBA pri zapisu na port: {e}")
    ser.close()
    sys.exit(1)

# ==============================================================================
# 4. Čekání na potvrzení (Odolné vůči šumu)
# ==============================================================================
print("[*] Cekam na potvrzeni od bootloaderu...")
try:
    ser.timeout = 0.5 
    success = False
    start_time = time.time()
    
    # Python bude max. 5 vteřin číst po jednom znaku a hledat 'K'
    while (time.time() - start_time) < 5.0:
        char = ser.read(1)
        if char == b'K':
            success = True
            break
        elif char != b'':
            # Ignorujeme smetí před potvrzením (např. \xc1)
            pass 

    if success:
        print(f"\n[SUCCESS] Aplikace '{os.path.basename(BIN_FILE)}' byla uspesne nahrana a spustena!")
    else:
        print("\n[!] CHYBA: Vyprsel casovy limit pro cteni (Timeout)!")
        print("           Bootloader neodpovedel znakem 'K'.")
        
except Exception as e:
    print(f"\n[!] CHYBA pri cteni odpovedi z portu: {e}")

finally:
    ser.close()