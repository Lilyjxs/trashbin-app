#include <ESP32Servo.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);


const char* WIFI_SSID     = "NoPresure";
const char* WIFI_PASSWORD = "1234567890";
const char* PROJECT_ID    = "skripsi-462c1";
const char* API_KEY       = "AIzaSyAD17ryTiNPRfaOjJVxKnnSXZczUa6zLeY";

String firestoreBase = "https://firestore.googleapis.com/v1/projects/";
String docPath       = "/databases/(default)/documents/device/esp32";

#define IR_PIN          15
#define KAPASITIF_PIN    5
#define INDUKTIF_PIN     4
#define PIN_SERVO_KIRI  13
#define PIN_SERVO_KANAN 12
#define BUZZER_PIN      25
#define LED_PIN_1       17
#define LED_PIN_2       16

#define POS_STANDBY_KIRI   110
#define POS_STANDBY_KANAN   10
#define POS_KALENG_KIRI    120
#define POS_KALENG_KANAN   120
#define POS_PLASTIK_KIRI     0
#define POS_PLASTIK_KANAN    0

#define TIMEOUT_MS       30000
#define COOLDOWN_MS       5000
#define POLLING_MS         500
#define BUZZER_LONG_ON     500
#define BUZZER_LONG_OFF    300
#define BUZZER_FAST_ON     100
#define BUZZER_FAST_OFF    100

typedef enum { IDLE, PROCESSING, REJECT_LOCK } SystemState;
SystemState state = IDLE;

enum RejectType { NONE, UNKNOWN, CONFLICT };
RejectType rejectType = NONE;

Servo servoKiri;
Servo servoKanan;

unsigned long buzzerTimer = 0;
bool buzzerOn             = false;
int  buzzerMode           = 0;

unsigned long timeoutTimer  = 0;
bool timeoutActive          = false;
unsigned long cooldownTimer = 0;
bool cooldownActive         = false;

unsigned long lastPollTime  = 0;

int  animFrame    = 0;
bool animBlink    = false;
bool animToggle   = false;
int  animProgress = 0;
unsigned long lastAnimTick = 0;

void firestoreWrite(String status, String command = "") {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = firestoreBase + PROJECT_ID + docPath + "?key=" + API_KEY;

  String body = "{\"fields\":{";
  body += "\"status\":{\"stringValue\":\"" + status + "\"},";
  body += "\"command\":{\"stringValue\":\"" + command + "\"},";  
  body += "\"last_seen\":{\"integerValue\":" + String(millis()) + "}";  
  body += "}}";

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  int code = http.sendRequest("PATCH", body);
  Serial.println("Firestore write: " + status + " | code: " + String(code));
  http.end();
}

String firestoreReadCommand() {
  if (WiFi.status() != WL_CONNECTED) return "";

  HTTPClient http;
  String url = firestoreBase + PROJECT_ID + docPath + "?key=" + API_KEY;

  http.begin(url);
  int code = http.GET();

  if (code != 200) {
    http.end();
    return "";
  }

  String payload = http.getString();
  http.end();

  // Parse JSON
  DynamicJsonDocument doc(2048);
  deserializeJson(doc, payload);

  String command = "";
  if (doc["fields"]["command"]["stringValue"]) {
    command = doc["fields"]["command"]["stringValue"].as<String>();
  }

  return command;
}

void firestoreClearCommand() {
  firestoreWrite(getStateString(), "");
}

String getStateString() {
  switch (state) {
    case IDLE:        return "IDLE";
    case PROCESSING:  return "PROCESSING";
    case REJECT_LOCK: return "REJECT_LOCK";
    default:          return "IDLE";
  }
}

void buzzerStop() {
  digitalWrite(BUZZER_PIN, LOW);
  buzzerOn   = false;
  buzzerMode = 0;
}

void buzzerUpdate() {
  if (buzzerMode == 0) return;
  int onTime  = (buzzerMode == 1) ? BUZZER_LONG_ON  : BUZZER_FAST_ON;
  int offTime = (buzzerMode == 1) ? BUZZER_LONG_OFF : BUZZER_FAST_OFF;

  if (buzzerOn && millis() - buzzerTimer >= onTime) {
    digitalWrite(BUZZER_PIN, LOW);
    buzzerOn    = false;
    buzzerTimer = millis();
  } else if (!buzzerOn && millis() - buzzerTimer >= offTime) {
    digitalWrite(BUZZER_PIN, HIGH);
    buzzerOn    = true;
    buzzerTimer = millis();
  }
}

void gerakServo(String jenis) {
  if (jenis == "KALENG") {
    displaySortirKaleng();
    firestoreWrite("SERVO_DONE", "");
    delay(1000);
    servoKiri.write(POS_KALENG_KIRI);
    servoKanan.write(POS_KALENG_KANAN);
  } else if (jenis == "PLASTIK") {
    displaySortirPlastik();
    servoKiri.write(POS_PLASTIK_KIRI);
    servoKanan.write(POS_PLASTIK_KANAN);
    firestoreWrite("SERVO_DONE", "");
  }
  delay(2000);
  // servoKiri.write(POS_STANDBY_KIRI);
  // servoKanan.write(POS_STANDBY_KANAN);
}

String bacaSensor() {
  displayValidasi(false);
  delay(1000);

  bool objekMasihAda = (digitalRead(IR_PIN) == LOW);

  bool induktif  = digitalRead(INDUKTIF_PIN);
  delay(1500);
  bool kapasitif = digitalRead(KAPASITIF_PIN);

  bool adaLogam = (induktif == LOW);

  Serial.print("DEBUG kapasitif: ");
  Serial.print(kapasitif);
  Serial.print(" | induktif: ");
  Serial.print(induktif);
  Serial.print(" | IR masih ada: ");
  Serial.println(objekMasihAda);

  String hasil;
  if (!objekMasihAda) {
    hasil = "TIDAK_ADA_OBJEK";
  } else {
    hasil = adaLogam ? "KALENG" : "PLASTIK";
  }
  Serial.println("HASIL: " + hasil);

  // Tulis hasil ke Firestore
  firestoreWrite("VALIDATION_DONE", hasil);

  // Tunggu camera.py kirim perintah balik
  Serial.println("Menunggu perintah dari camera.py...");
  unsigned long waitStart = millis();
  String perintah = "";

  while (millis() - waitStart < 15000) {
    delay(500);
    perintah = firestoreReadCommand();
    Serial.println("Polling command: " + perintah);

    if (perintah.startsWith("GERAK:") || perintah.startsWith("REJECT:")) {
      Serial.println("✅ Perintah diterima: " + perintah);
      break;
    }
  }

  if (perintah == "") {
    Serial.println("⚠️ Tidak ada perintah dalam 15 detik!");
  }

  return perintah;
}

void resetToIdle() {
  buzzerStop();
  rejectType = NONE;
  digitalWrite(LED_PIN_1, LOW);
  digitalWrite(LED_PIN_2, LOW);
  state          = IDLE;
  timeoutActive  = false;
  cooldownActive = true;
  cooldownTimer  = millis();
  animProgress   = 0;
  firestoreWrite("IDLE", "");
  displayCooldown(0);
}

void animUpdate() {
  unsigned long now = millis();
  if (now - lastAnimTick < 100) return;
  lastAnimTick = now;
  animFrame++;
  animBlink  = !animBlink;
  animToggle = !animToggle;
  if (animProgress < 100) animProgress += 2;
}

void setup() {
  Serial.begin(115200);

  pinMode(IR_PIN,        INPUT);
  pinMode(KAPASITIF_PIN, INPUT);
  pinMode(INDUKTIF_PIN,  INPUT);
  pinMode(BUZZER_PIN,    OUTPUT);
  pinMode(LED_PIN_1,     OUTPUT);
  pinMode(LED_PIN_2,     OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_PIN_1,  LOW);
  digitalWrite(LED_PIN_2,  LOW);

  servoKiri.attach(PIN_SERVO_KIRI);
  servoKanan.attach(PIN_SERVO_KANAN);
  servoKiri.write(POS_STANDBY_KIRI);
  servoKanan.write(POS_STANDBY_KANAN);

  // Init OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED tidak terdeteksi!");
    while (true);
  }
  display.clearDisplay();
  display.display();

  delay(500);
  displayStandby();
  Serial.print("Connecting WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 20) {
    delay(500);
    Serial.print(".");
    retry++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected: " + WiFi.localIP().toString());
    firestoreWrite("IDLE", "");
  } else {
    Serial.println("\nWiFi GAGAL! Cek SSID/Password.");
  }

  displayStandby();
  Serial.println("=================================");
  Serial.println("   Sistem ESP32 - Ready (IDLE)   ");
  Serial.println("=================================");
}

void loop() {
  buzzerUpdate();
  animUpdate();
  servoKiri.write(POS_STANDBY_KIRI);
  servoKanan.write(POS_STANDBY_KANAN);

  if (timeoutActive && millis() - timeoutTimer >= TIMEOUT_MS) {
    Serial.println("TIMEOUT");
    displayTimeout();
    firestoreWrite("TIMEOUT", "");
    delay(2000);
    resetToIdle();
  }

  if (cooldownActive && millis() - cooldownTimer >= COOLDOWN_MS) {
    cooldownActive = false;
    displayStandby();
  }

  if (cooldownActive) {
    displayCooldown(animProgress);
  }

  if (millis() - lastPollTime >= POLLING_MS) {
    lastPollTime = millis();

    String cmd = firestoreReadCommand();

    if (cmd == "LED_ON") {
      digitalWrite(LED_PIN_1, HIGH);
      digitalWrite(LED_PIN_2, HIGH);
      firestoreClearCommand();

    } else if (cmd == "LED_OFF") {
      digitalWrite(LED_PIN_1, LOW);
      digitalWrite(LED_PIN_2, LOW);
      firestoreClearCommand();

    } else if (cmd == "VALIDATE" && state == PROCESSING) {
      timeoutActive = false;
      String perintah = bacaSensor();

      if (perintah.startsWith("GERAK:")) {
        String jenis = perintah.substring(6);
        firestoreClearCommand();
        gerakServo(jenis);
        // firestoreWrite("SERVO_DONE", "");
        resetToIdle();

      } else if (perintah == "REJECT:TIDAK_DIKETAHUI") {
        state      = REJECT_LOCK;
        rejectType = UNKNOWN;
        buzzerMode = 1;
        buzzerOn   = true;
        digitalWrite(BUZZER_PIN, HIGH);
        buzzerTimer  = millis();
        animProgress = 0;
        firestoreWrite("REJECT_LOCK", "");
        firestoreClearCommand();
        displayDitolakTidakDikenal(true);
        buzzerTimer = millis(); 

      } else if (perintah == "REJECT:KONFLIK") {
        state      = REJECT_LOCK;
        rejectType = CONFLICT;
        buzzerMode = 2;
        buzzerOn   = true;
        digitalWrite(BUZZER_PIN, HIGH);
        buzzerTimer  = millis();
        animProgress = 0;
        firestoreWrite("REJECT_LOCK", "");
        firestoreClearCommand();
        displayDitolakKonflik(true);
        buzzerTimer = millis();

      } else {
        Serial.println("⚠️ Timeout tunggu perintah, reset...");
        resetToIdle();
      }
    }
  }

  bool irDetect = (digitalRead(IR_PIN) == LOW);

  if (state == IDLE && irDetect && !cooldownActive) {
    state         = PROCESSING;
    timeoutActive = true;
    timeoutTimer  = millis();
    animFrame     = 0;
    firestoreWrite("OBJECT_DETECTED", "");
    displayObjekTerdeteksi();

  } else if (state == REJECT_LOCK && !irDetect) {
    firestoreWrite("OBJECT_CLEARED", "");
    resetToIdle();
  }

  if (state == REJECT_LOCK) {
    if (rejectType == UNKNOWN) displayDitolakTidakDikenal(animBlink);
    else if (rejectType == CONFLICT) displayDitolakKonflik(animBlink);
  }

  if (state == PROCESSING && !cooldownActive) {
    displayCNN(animFrame);
  }

  delay(50);
}