# TrashBin
**Alat Pemisah Kaleng dan Botol Plastik Berbasis Artificial Intelligence**

Prototipe sistem pemilahan sampah otomatis yang menggunakan kamera dan model CNN EfficientNetB0 untuk mengklasifikasikan objek, divalidasi oleh sensor induktif, lalu motor servo mengarahkan objek ke wadah yang sesuai. Seluruh proses dapat dipantau secara realtime melalui aplikasi mobile berbasis Flutter yang terhubung ke Firebase Firestore.

---

## Komponen Sistem

- **ESP32:** mikrokontroler utama, membaca sensor dan menggerakkan servo
- **camera.py:** program Python yang menjalankan model CNN dan logika keputusan
- **Flutter App:** aplikasi mobile untuk monitoring realtime
- **Firebase Firestore:** backend komunikasi antar komponen

---
