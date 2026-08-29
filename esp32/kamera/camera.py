import os
import sys
import cv2
import numpy as np
import time
import threading
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore

# ================================
# INIT FIREBASE
# ================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
cred = credentials.Certificate(os.path.join(BASE_DIR, "serviceAccountKey.json"))
firebase_admin.initialize_app(cred)
db = firestore.client()

# ================================
# PATH AI
# ================================
AI_PATH = os.path.join(BASE_DIR, '../../ai')
sys.path.insert(0, AI_PATH)
from classify import classify_image

# ================================
# KONFIGURASI
# ================================
CAPTURE_DELAY = 5
SAVE_DIR      = os.path.join(BASE_DIR, "captures")
TIMEOUT_SEC   = 30
COOLDOWN_SEC  = 2
CAMERA_INDEX  = 2  # sesuaikan dengan index kamera kamu

os.makedirs(SAVE_DIR, exist_ok=True)

# [FIX] Pisahkan referensi dokumen:
# - system_ref → device/system  (status untuk dashboard Flutter)
# - esp32_ref  → device/esp32   (komunikasi dua arah dengan ESP32)
system_ref = db.collection("device").document("system")
esp32_ref  = db.collection("device").document("esp32")

# ================================
# SHARED STATE (thread-safe)
# ================================
latest_status = {"status": "", "command": ""}
state_lock    = threading.Lock()

def on_esp32_snapshot(doc_snapshot, changes, read_time):
    for doc in doc_snapshot:
        data = doc.to_dict()

        print("\n===== SNAPSHOT =====")
        print(data)

        with state_lock:
            latest_status["status"]  = data.get("status", "")
            latest_status["command"] = data.get("command", "")

# [FIX] Listener sekarang membaca dari esp32_ref, bukan system_ref
esp32_ref.on_snapshot(on_esp32_snapshot)

# ================================
# KAMERA HELPER
# ================================
def buka_kamera(index):
    cap = cv2.VideoCapture(index)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_BUFFERSIZE,   1)
    cap.set(cv2.CAP_PROP_AUTOFOCUS,    0)
    cap.set(cv2.CAP_PROP_FOCUS,       40)
    return cap

def hitung_ketajaman(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    return cv2.Laplacian(gray, cv2.CV_64F).var()

def flush_realtime(cap, durasi_detik=1.2, target_fps=20):
    """
    Flush buffer kamera berdasarkan WAKTU NYATA, bukan jumlah grab().
    Panggilan grab() yang terlalu cepat (tanpa delay) tidak benar-benar
    memaksa sensor mengambil frame baru -- hanya menguras antrian buffer
    lama yang sudah ada. Dengan delay antar grab() yang meniru frame
    rate asli kamera, kita pastikan buffer benar-benar terisi frame baru
    dan auto-exposure sempat stabil di pencahayaan LED saat ini.
    """
    interval = 1.0 / target_fps
    start = time.time()
    count = 0
    while time.time() - start < durasi_detik:
        cap.grab()
        count += 1
        time.sleep(interval)
    print(f"   🔄 Flush real-time: {count} grab dalam {durasi_detik:.1f}s")

def capture_dengan_retry(index, min_sharpness=80, max_retry=1):
    """
    Buka kamera sekali, flush real-time singkat, lalu ambil HANYA 2 frame
    dan pilih yang paling tajam. Tidak ada retry buka-tutup kamera berkali-kali
    -- itu justru memicu auto-exposure 'berburu' ulang tiap kali dan
    membuat hasil makin buram.
    """
    print(f"   📷 Membuka kamera...")
    cap = buka_kamera(index)

    # Flush real-time singkat: cukup untuk sensor settle ke kondisi sekarang
    flush_realtime(cap, durasi_detik=1.2, target_fps=20)

    # Ambil 2 frame saja, jeda singkat di antaranya
    frames, scores = [], []
    for i in range(2):
        ret, frame = cap.read()
        if ret:
            score = hitung_ketajaman(frame)
            frames.append(frame)
            scores.append(score)
            print(f"   Frame {i+1}/2 | Ketajaman: {score:.1f}")
        time.sleep(0.2)

    cap.release()

    if not frames:
        return None, 0

    best_idx = int(np.argmax(scores))
    best_frame = frames[best_idx]
    best_score = scores[best_idx]
    print(f"   ✅ Frame terbaik: #{best_idx+1} (skor {best_score:.1f})")

    if best_score < min_sharpness:
        print(f"   ⚠️ Skor di bawah ambang ({min_sharpness}), tetap dipakai (skor {best_score:.1f})")

    return best_frame, best_score

# ================================
# FIRESTORE HELPER
# ================================
def fs_write(status, command=""):
    """Tulis status ke device/system — untuk dashboard Flutter."""
    system_ref.set({
        "status":  status,
        "command": command,
        "updated": firestore.SERVER_TIMESTAMP,
    })
    print(f"[FS] write → status={status} command={command}")

def fs_write_esp32(command):
    """[FIX] Kirim command ke device/esp32 — untuk dibaca ESP32."""
    esp32_ref.update({
        "command": command,
        "updated": firestore.SERVER_TIMESTAMP,
    })
    print(f"[FS] esp32 command → {command}")

def get_status():
    with state_lock:
        return latest_status["status"]

def get_command():
    with state_lock:
        return latest_status["command"]

# ================================
# HELPER SISTEM
# ================================
def kirim_ke_firestore(label, confidence, sensor, status):
    type_label = "Kaleng" if label == "kaleng" else "Botol" if label == "botol_plastik" else "Tidak Diketahui"
    db.collection("logs").add({
        "type":       type_label,
        "confidence": round(confidence * 100, 1),
        "sensor":     sensor,
        "status":     status,
        "time":       firestore.SERVER_TIMESTAMP,
    })
    print(f"✅ Log terkirim: {type_label} | {confidence:.0%} | {status}")

def keputusan_akhir(cnn, sensor):
    if cnn == "tidak_diketahui" or sensor == "TIDAK_ADA_OBJEK":
        return "REJECT:TIDAK_DIKETAHUI"
    cnn_norm = "KALENG" if cnn == "kaleng" else "PLASTIK"
    if cnn_norm == sensor:
        return f"GERAK:{cnn_norm}"
    else:
        return "REJECT:KONFLIK"

def selesai_reset():
    global state, label_cnn, confidence_cnn, hasil_sensor
    print(f"⏳ Cooldown {COOLDOWN_SEC} detik...")
    time.sleep(COOLDOWN_SEC)
    state          = "waiting"
    label_cnn      = None
    confidence_cnn = None
    hasil_sensor   = None
    fs_write("IDLE", "")
    time.sleep(0.5)
    print("\n✅ Siap! Menunggu objek baru...\n")

def led_on():
    # [FIX] LED_ON dikirim ke ESP32, bukan system
    fs_write_esp32("LED_ON")
    time.sleep(1.5)

def led_off():
    # [FIX] LED_OFF dikirim ke ESP32, bukan system
    fs_write_esp32("LED_OFF")
    time.sleep(0.3)

# ================================
# STATE & VARIABEL
# ================================
state          = "waiting"
label_cnn      = None
confidence_cnn = None
hasil_sensor   = None

# [TIMING] Variabel pencatat waktu untuk pengujian performa sistem
t_object_detected = None
t_capture_start    = None
t_capture_end      = None
t_cnn_done         = None
t_validate_sent    = None
t_validation_done  = None
t_execute_sent     = None
t_servo_done       = None

fs_write("IDLE", "")
time.sleep(1)

print("=================================")
print("  Sistem Deteksi Sampah - Ready  ")
print("=================================")
print("Menunggu objek...\n")

# ================================
# MAIN LOOP
# ================================
try:
    while True:
        current_status = get_status()

        # -----------------------------------------------
        if state == "waiting":
            if current_status == "OBJECT_DETECTED":
                print("\n📦 Objek terdeteksi!")
                t_object_detected = time.time()  # [TIMING] mulai siklus

                fs_write("COUNTDOWN", "")
                time.sleep(0.3)

                print(f"⏳ Countdown {CAPTURE_DELAY} detik...")
                start_countdown = time.time()

                while time.time() - start_countdown < CAPTURE_DELAY:
                    remaining = CAPTURE_DELAY - (time.time() - start_countdown)
                    print(f"\r⏳ Capture dalam: {remaining:.1f}s  ", end="", flush=True)
                    time.sleep(0.1)

                print("\n💡 LED ON...")
                led_on()

                print("📷 Capturing (kamera fresh + flush real-time)...")
                t_capture_start = time.time()  # [TIMING] mulai capture+CNN
                frame, sharpness = capture_dengan_retry(
                    CAMERA_INDEX,
                    min_sharpness=80,
                    max_retry=3
                )
                t_capture_end = time.time()  # [TIMING] capture selesai

                led_off()
                print("💡 LED OFF")

                if frame is None:
                    print("❌ Gagal capture!")
                    selesai_reset()
                    continue

                if sharpness < 50:
                    print(f"⚠️ Gambar mungkin blur (skor {sharpness:.1f})")

                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename  = f"{SAVE_DIR}/capture_{timestamp}.jpg"
                cv2.imwrite(filename, frame)
                print(f"✅ Gambar disimpan: {filename}")

                print("🤖 Mengklasifikasi...")
                label_cnn, confidence_cnn = classify_image(filename)
                if confidence_cnn < 0.75:
                    label_cnn = "tidak_diketahui"
                t_cnn_done = time.time()  # [TIMING] klasifikasi CNN selesai
                print(f"🏷️  CNN: {label_cnn} | Confidence: {confidence_cnn:.2%}")
                print(f"⏱️  [TIMING] Capture+CNN: {t_cnn_done - t_capture_start:.2f}s")

                print("🔌 Validasi sensor...")
                fs_write("VALIDATING", "")
                # [FIX] Kirim VALIDATE ke esp32_ref agar ESP32 bisa baca
                fs_write_esp32("VALIDATE")
                t_validate_sent = time.time()  # [TIMING] command VALIDATE dikirim
                state = "validating"

        # -----------------------------------------------
        elif state == "validating":
            print("⏳ Menunggu hasil sensor...")
            start_wait = time.time()
            last_retry = time.time()

            while time.time() - start_wait < 30:
                current = get_status()

                # Retry kirim VALIDATE tiap 8 detik
                if time.time() - last_retry > 8:
                    print("🔄 Retry kirim VALIDATE...")
                    fs_write("VALIDATING", "")
                    # [FIX] Retry juga ke esp32_ref
                    fs_write_esp32("VALIDATE")
                    last_retry = time.time()

                if current == "VALIDATION_DONE":
                    t_validation_done = time.time()  # [TIMING] sensor selesai validasi
                    print(f"⏱️  [TIMING] Validasi sensor: {t_validation_done - t_validate_sent:.2f}s")

                    # [FIX] Baca hasil sensor dari esp32_ref, bukan system_ref
                    doc          = esp32_ref.get().to_dict()

                    hasil_sensor = doc.get("command", "TIDAK_ADA_OBJEK")

                    if hasil_sensor not in ["KALENG", "PLASTIK", "TIDAK_ADA_OBJEK"]:
                        hasil_sensor = "TIDAK_ADA_OBJEK"

                    print(f"📡 Sensor: {hasil_sensor}")
                    perintah = keputusan_akhir(label_cnn, hasil_sensor)

                    print(f"\n--- Keputusan Akhir ---")
                    print(f"CNN    : {label_cnn} ({confidence_cnn:.0%})")
                    print(f"Sensor : {hasil_sensor}")
                    print(f"Aksi   : {perintah}")
                    print("-----------------------")

                    fs_write("EXECUTING", "")
                    time.sleep(0.3)
                    # [FIX] Kirim perintah GERAK/REJECT ke esp32_ref
                    fs_write_esp32(perintah)
                    t_execute_sent = time.time()  # [TIMING] command eksekusi dikirim
                    time.sleep(0.5)
                    state = "executing"
                    break

                time.sleep(0.3)
            else:
                print("⚠️ Timeout tunggu sensor! Reset...")
                fs_write("IDLE", "")
                selesai_reset()

        # -----------------------------------------------
        elif state == "executing":
            print("⏳ Menunggu konfirmasi ESP32...")
            start_wait = time.time()

            while time.time() - start_wait < 20:
                current = get_status().strip()  # [FIX] strip whitespace
                print(f"   Status: {current}", end="\r", flush=True)

                if "SERVO_DONE" in current:      # [FIX] pakai 'in' bukan ==
                    t_servo_done = time.time()  # [TIMING] servo selesai bergerak
                    print("\n✅ Servo berhasil!")
                    print(f"⏱️  [TIMING] Servo bergerak: {t_servo_done - t_execute_sent:.2f}s")
                    print(f"⏱️  [TIMING] TOTAL SIKLUS: {t_servo_done - t_object_detected:.2f}s")
                    kirim_ke_firestore(label_cnn, confidence_cnn, hasil_sensor, "DITERIMA")
                    selesai_reset()
                    break

                elif "REJECT_LOCK" in current:   # [FIX] pakai 'in' bukan ==
                    t_servo_done = time.time()  # [TIMING] proses sampai reject
                    print("\n🔔 REJECT - Menunggu objek diambil...")
                    print(f"⏱️  [TIMING] TOTAL SIKLUS (hingga reject): {t_servo_done - t_object_detected:.2f}s")
                    kirim_ke_firestore(label_cnn, confidence_cnn, hasil_sensor, "DITOLAK")
                    state = "reject_lock"
                    break

                time.sleep(0.3)
            else:
                print("\n⚠️ Timeout tunggu servo! Reset...")
                fs_write("IDLE", "")
                selesai_reset()

        # -----------------------------------------------
        elif state == "reject_lock":
            print("⏳ Menunggu objek diambil...")
            start_wait = time.time()

            while time.time() - start_wait < 60:
                current = get_status()

                if current == "OBJECT_CLEARED" or current == "IDLE":
                    print("✅ Objek diambil!")
                    selesai_reset()
                    break

                time.sleep(0.3)
            else:
                print("⚠️ Timeout reject lock! Reset...")
                fs_write("IDLE", "")
                selesai_reset()

        time.sleep(0.2)

except KeyboardInterrupt:
    print("\n🛑 Dihentikan manual.")
finally:
    fs_write("OFFLINE", "")
    print("🔒 Selesai.")