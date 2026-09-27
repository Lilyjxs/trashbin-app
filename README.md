# TrashBin 🗑️
**Alat Pemisah Kaleng dan Botol Plastik Berbasis Artificial Intelligence**

Prototipe sistem pemilahan sampah otomatis yang menggunakan kamera dan model CNN EfficientNetB0 untuk mengklasifikasikan objek, divalidasi oleh sensor induktif, lalu motor servo mengarahkan objek ke wadah yang sesuai. Seluruh proses dapat dipantau secara realtime melalui aplikasi mobile berbasis Flutter.

---

## Struktur Repository

```
trashbin-app/
├── android/          # Konfigurasi Android (Flutter)
├── ai/
│   ├── classify.py   # Inferensi model CNN
│   ├── train.py      # Training model EfficientNetB0
│   ├── dataset/
│   │   ├── train/    # Gambar training (tidak disertakan)
│   │   └── val/      # Gambar validasi (tidak disertakan)
│   └── model/        # Model hasil training (tidak disertakan)
├── esp32/
│   └── kamera/
│       ├── main.ino  # Program ESP32
│       └── camera.py # Program kamera + logika sistem
├── lib/              # Source code Flutter
├── assets/           # Aset aplikasi (Lottie, ikon, dsb)
├── requirements.txt  # Library Python
└── pubspec.yaml      # Dependensi Flutter
```

---

## Kebutuhan Sistem

**Hardware:**
- ESP32 38-pin + papan ekspansi
- Sensor IR, sensor induktif, sensor kapasitif
- 2x motor servo MG996R
- LCD OLED SSD1306 128x64
- Webcam USB
- Power supply 12V

**Software:**
- Python 3.x
- Arduino IDE
- Flutter SDK
- Firebase project (Firestore)

---

## Instalasi

### 1. Python (camera.py)
```bash
pip install -r requirements.txt
```

Buat file `serviceAccountKey.json` dari Firebase Console dan letakkan di:
```
esp32/kamera/serviceAccountKey.json
```

### 2. Model AI
Download `model_sampah.h5` dan letakkan di:
```
ai/model/model_sampah.h5
```

> Link model: [Google Drive](https://drive.google.com/drive/folders/1xlR64UPnTzXZ_QsUXFa7RLoE4JLTsUPX?usp=sharing)

### 3. ESP32
Buka `esp32/kamera/main.ino` di Arduino IDE, sesuaikan WiFi SSID, password, dan Firebase credentials, lalu upload ke ESP32.

### 4. Flutter
```bash
flutter pub get
flutter run
```

Atau install langsung APK dari link Google Drive di atas.

---

## Cara Penggunaan

1. Hubungkan adaptor ke listrik
2. Pastikan ESP32 terhubung ke hotspot
3. Hubungkan webcam ke laptop via USB
4. Jalankan camera.py:
   ```bash
   cd esp32/kamera
   python camera.py
   ```
5. Tunggu muncul pesan `Sistem Deteksi Sampah - Ready`
6. Buka aplikasi TrashBin, pastikan status **ONLINE**
7. Masukkan objek ke lubang input alat

---

## Dibuat Oleh

**Afdhal Nesta Alfito** — 20122060  
Program Studi Sistem Komputer  
Fakultas Ilmu Komputer & Teknologi Informasi  
Universitas Gunadarma — 2026
