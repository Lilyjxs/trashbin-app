// Display.ino
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT  64

extern Adafruit_SSD1306 display;

// ================================
// HELPER
// ================================
void drawCentered(String text, int y, uint8_t size = 1) {
  display.setTextSize(size);
  int16_t x1, y1;
  uint16_t w, h;
  display.getTextBounds(text, 0, y, &x1, &y1, &w, &h);
  display.setCursor((SCREEN_WIDTH - w) / 2, y);
  display.print(text);
}

void drawDivider(int y) {
  display.drawFastHLine(0, y, SCREEN_WIDTH, SSD1306_WHITE);
}

void drawProgressBar(int percent) {
  int filled = (SCREEN_WIDTH * percent) / 100;
  display.drawRect(0, 56, SCREEN_WIDTH, 6, SSD1306_WHITE);
  if (filled > 0)
    display.fillRect(0, 56, filled, 6, SSD1306_WHITE);
}

void drawHeader(String title) {
  display.fillRect(0, 0, SCREEN_WIDTH, 14, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  int16_t x1, y1; uint16_t w, h;
  display.getTextBounds(title, 0, 0, &x1, &y1, &w, &h);
  display.setCursor((SCREEN_WIDTH - w) / 2, 3);
  display.print(title);
  display.setTextColor(SSD1306_WHITE);
}

// ================================
// STARTUP
// ================================
void displayStartup(int progress) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawCentered("SMART BIN", 6, 2);
  drawCentered("AI Sorting System", 30, 1);
  drawCentered("Initializing...", 44, 1);
  drawProgressBar(progress);

  display.display();
}

// ================================
// STANDBY
// ================================
void displayStandby() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("READY");
  drawCentered("Sistem Aktif", 20, 1);
  drawDivider(34);
  drawCentered("Masukkan objek", 42, 1);
  drawCentered("untuk memulai", 54, 1);

  display.display();
}

// ================================
// OBJECT DETECTED
// ================================
void displayObjekTerdeteksi() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("DETEKSI");
  drawCentered("Objek", 18, 2);
  drawCentered("Terdeteksi", 38, 1);
  drawCentered("Harap tunggu...", 52, 1);

  display.display();
}

// ================================
// CNN PROCESSING
// ================================
void displayCNN(int frame) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("AI ANALYSIS");
  drawCentered("Menganalisis", 20, 1);
  drawCentered("objek...", 34, 1);

  // Animasi titik sederhana
  String dots = "";
  int d = (frame / 3) % 4;
  for (int i = 0; i < d; i++) dots += ".";
  drawCentered(dots, 48, 1);

  display.display();
}

// ================================
// VALIDASI SENSOR
// ================================
void displayValidasi(bool toggle) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("SENSOR CHECK");

  display.setCursor(4, 20);
  display.print("Induktif :");
  display.setCursor(4, 34);
  display.print("Kapasitif:");

  String status = toggle ? "SCAN" : "    ";
  display.setCursor(82, 20);
  display.print(status);
  display.setCursor(82, 34);
  display.print(status);

  drawCentered("Validating...", 52, 1);

  display.display();
}

// ================================
// SORT KALENG
// ================================
void displaySortirKaleng() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("SORTING");

  display.fillRect(0, 16, SCREEN_WIDTH, 34, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(2);
  int16_t x1, y1; uint16_t w, h;
  String label = "KALENG";
  display.getTextBounds(label, 0, 0, &x1, &y1, &w, &h);
  display.setCursor((SCREEN_WIDTH - w) / 2, 26);
  display.print(label);
  display.setTextColor(SSD1306_WHITE);

  drawCentered("Servo bergerak...", 54, 1);

  display.display();
}

// ================================
// SORT PLASTIK
// ================================
void displaySortirPlastik() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("SORTING");

  display.fillRect(0, 16, SCREEN_WIDTH, 34, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  int16_t x1, y1; uint16_t w, h;
  String label = "BOTOL PLASTIK";
  display.getTextBounds(label, 0, 0, &x1, &y1, &w, &h);
  display.setCursor((SCREEN_WIDTH - w) / 2, 30);
  display.print(label);
  display.setTextColor(SSD1306_WHITE);

  drawCentered("Servo bergerak...", 54, 1);

  display.display();
}

// ================================
// DITOLAK - TIDAK DIKENAL
// ================================
void displayDitolakTidakDikenal(bool blink) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("DITOLAK");

  drawCentered("Objek tidak", 18, 1);
  drawCentered("dikenali", 30, 1);
  drawDivider(44);

  if (blink) {
    drawCentered("Ambil objek!", 50, 1);
  }

  display.display();
}

// ================================
// DITOLAK - KONFLIK
// ================================
void displayDitolakKonflik(bool blink) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("DITOLAK");

  drawCentered("Data tidak", 18, 1);
  drawCentered("cocok", 30, 1);
  drawDivider(44);

  if (blink) {
    drawCentered("Ambil objek!", 50, 1);
  }

  display.display();
}

// ================================
// TUNGGU OBJEK DIAMBIL
// ================================
void displayTunggu(bool blink) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("TUNGGU");

  drawCentered("Ambil objek", 20, 1);
  drawCentered("dari alat", 32, 1);
  drawDivider(44);

  if (blink) {
    drawCentered(">> Buzzer aktif <<", 50, 1);
  }

  display.display();
}

// ================================
// COOLDOWN
// ================================
void displayCooldown(int progress) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("SELESAI");

  drawCentered("Berhasil!", 20, 2);
  drawCentered("Harap tunggu...", 44, 1);
  drawProgressBar(progress);

  display.display();
}

// ================================
// TIMEOUT
// ================================
void displayTimeout() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawHeader("TIMEOUT");

  drawCentered("Sistem tidak", 20, 1);
  drawCentered("merespon!", 32, 1);
  drawDivider(44);
  drawCentered("Reset otomatis...", 50, 1);

  display.display();
}