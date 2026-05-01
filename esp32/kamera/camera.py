import os
import sys
import serial
import cv2
import time
from datetime import datetime

# Path ke folder ai
AI_PATH = os.path.join(os.path.dirname(__file__), '../../ai')
sys.path.insert(0, AI_PATH)
from classify import classify_image

# ================================
# KONFIGURASI
# ================================
PORT           = '/dev/ttyUSB1'
BAUD           = 115200
CAPTURE_DELAY  = 5      # detik countdown sebelum capture
SAVE_DIR       = "captures"
TIMEOUT_SEC    = 30     # timeout Python side
COOLDOWN_SEC   = 2      # jeda setelah selesai sebelum terima objek baru

os.makedirs(SAVE_DIR, exist_ok=True)

ser = serial.Serial(PORT, BAUD, timeout=0.1)

print("=================================")
print("  Sistem Deteksi Sampah - Ready  ")
print("=================================")
print("Menunggu objek...\n")

# ================================
# STATE & VARIABEL
# ================================
state          = "waiting"
trigger_time   = None
timeout_timer  = None
label_cnn      = None
confidence_cnn = None
hasil_sensor   = None

# ================================
# HELPER
# ================================
def keputusan_akhir(cnn, sensor):
    if cnn == "tidak_diketahui":
        return "REJECT:TIDAK_DIKETAHUI"
    cnn_norm = "KALENG" if cnn == "kaleng" else "PLASTIK"
    if cnn_norm == sensor:
        return f"GERAK:{cnn_norm}"
    else:
        return "REJECT:KONFLIK"

def cek_timeout():
    if timeout_timer and time.time() - timeout_timer > TIMEOUT_SEC:
        print("⚠️ Timeout Python! Reset ke waiting...")
        return True
    return False

def selesai_reset():
    global state, label_cnn, confidence_cnn, hasil_sensor, timeout_timer
    print(f"⏳ Cooldown {COOLDOWN_SEC} detik...")
    time.sleep(COOLDOWN_SEC)
    state          = "waiting"
    label_cnn      = None
    confidence_cnn = None
    hasil_sensor   = None
    timeout_timer  = None
    print("\n✅ Siap! Menunggu objek baru...\n")

# ================================
# MAIN LOOP
# ================================
while True:

    # Baca serial
    line = ""
    if ser.in_waiting:
        line = ser.readline().decode('utf-8').strip()
        if line:
            print(f"[ESP32] {line}")

    # -----------------------------------------------
    if state == "waiting":
        if line == "OBJECT_DETECTED":
            print("\n📦 Objek terdeteksi!")
            print(f"⏳ Countdown {CAPTURE_DELAY} detik...")
            state        = "countdown"
            trigger_time = time.time()

    # -----------------------------------------------
    elif state == "countdown":
        elapsed   = time.time() - trigger_time
        remaining = CAPTURE_DELAY - elapsed

        print(f"\r⏳ Capture dalam: {remaining:.1f}s  ", end="", flush=True)

        if elapsed >= CAPTURE_DELAY:
            print("\n📸 Capturing...")

            # Buka kamera, capture, langsung tutup
            cap = cv2.VideoCapture(1)
            ret, frame = cap.read()
            cap.release()

            if not ret:
                print("❌ Gagal capture! Reset...")
                selesai_reset()
                continue

            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename  = f"{SAVE_DIR}/capture_{timestamp}.jpg"
            cv2.imwrite(filename, frame)
            print(f"✅ Gambar disimpan: {filename}")

            # Klasifikasi CNN
            print("🤖 Mengklasifikasi...")
            label_cnn, confidence_cnn = classify_image(filename)

            # Filter confidence < 70%
            if confidence_cnn < 0.70:
                label_cnn = "tidak_diketahui"

            print(f"🏷️  CNN: {label_cnn} | Confidence: {confidence_cnn:.2%}")

            # Kirim VALIDATE ke ESP32
            print("🔌 Validasi sensor...")
            ser.write(b'VALIDATE\n')
            state         = "validating"
            timeout_timer = time.time()

    # -----------------------------------------------
    elif state == "validating":
        if cek_timeout():
            selesai_reset()
            continue

        if line.startswith("HASIL:"):
            hasil_sensor  = line.split(":")[1]
            print(f"📡 Sensor: {hasil_sensor}")

        if line == "VALIDATION_DONE":
            timeout_timer = None
            perintah      = keputusan_akhir(label_cnn, hasil_sensor)

            print(f"\n--- Keputusan Akhir ---")
            print(f"CNN    : {label_cnn} ({confidence_cnn:.0%})")
            print(f"Sensor : {hasil_sensor}")
            print(f"Aksi   : {perintah}")
            print("-----------------------")

            ser.write(f"{perintah}\n".encode())
            state         = "executing"
            timeout_timer = time.time()

    # -----------------------------------------------
    elif state == "executing":
        if cek_timeout():
            selesai_reset()
            continue

        if line == "SERVO_DONE":
            print("✅ Servo berhasil!")
            selesai_reset()

        elif line == "STATE:REJECT_LOCK":
            print("🔔 REJECT - Buzzer aktif, menunggu objek diambil...")
            state         = "reject_lock"
            timeout_timer = None

    # -----------------------------------------------
    elif state == "reject_lock":
        if line == "OBJECT_CLEARED":
            print("✅ Objek diambil!")
            selesai_reset()

    time.sleep(0.05)

ser.close()