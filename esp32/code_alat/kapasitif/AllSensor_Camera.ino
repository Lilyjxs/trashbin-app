#include <ESP32Servo.h>

// ================================
// PIN DEFINITION
// ================================
#define IR_PIN          15
#define KAPASITIF_PIN   5
#define INDUKTIF_PIN    4
#define SERVO_KALENG    18
#define SERVO_PLASTIK   19
#define BUZZER_PIN      23

// ================================
// KONFIGURASI
// ================================
#define SERVO_IDLE      90
#define SERVO_PULL      0
#define SERVO_HOLD      1000
#define TIMEOUT_MS      30000  // 30 detik timeout


// Tambah di bagian atas (global variable)
unsigned long cooldownTimer = 0;
bool cooldownActive = false;
#define COOLDOWN_MS 5000  // 5 detik ignore IR setelah servo selesai

// ================================
// STATE
// ================================
typedef enum {
  IDLE,
  PROCESSING,
  REJECT_LOCK
} SystemState;

SystemState state = IDLE;

Servo servoKaleng;
Servo servoPlastik;

// Buzzer non-blocking
unsigned long buzzerTimer = 0;
bool buzzerOn             = false;
int buzzerMode            = 0; // 1 = panjang, 2 = cepat
#define BUZZER_LONG_ON    500
#define BUZZER_LONG_OFF   300
#define BUZZER_FAST_ON    100
#define BUZZER_FAST_OFF   100

// Timeout
unsigned long timeoutTimer = 0;
bool timeoutActive         = false;

// ================================
// BUZZER
// ================================
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

// ================================
// SERVO
// ================================
void gerakServo(String jenis) {
  if (jenis == "KALENG") {
    servoKaleng.write(SERVO_PULL);
    delay(SERVO_HOLD);
    servoKaleng.write(SERVO_IDLE);
  } else if (jenis == "PLASTIK") {
    servoPlastik.write(SERVO_PULL);
    delay(SERVO_HOLD);
    servoPlastik.write(SERVO_IDLE);
  }
}

// ================================
void bacaSensor() {
  delay(5000); // tunggu objek settle dulu

  // Baca induktif dulu
  bool induktif = digitalRead(INDUKTIF_PIN);
  Serial.print("DEBUG induktif: ");
  Serial.println(induktif);

  delay(500); // jeda sebelum baca kapasitif

  // Baru baca kapasitif
  bool kapasitif = digitalRead(KAPASITIF_PIN);
  Serial.print("DEBUG kapasitif: ");
  Serial.println(kapasitif);

  bool adaLogam = (induktif  == LOW);
  bool adaObjek = (kapasitif == LOW);

  Serial.print("DEBUG sensor - kapasitif: ");
  Serial.print(kapasitif);
  Serial.print(" | induktif: ");
  Serial.println(induktif);

  if (adaObjek && adaLogam) {
    Serial.println("HASIL:KALENG");
  } else if (adaObjek && !adaLogam) {
    Serial.println("HASIL:PLASTIK");
  } else {
    Serial.println("HASIL:TIDAK_DIKETAHUI");
  }

  Serial.println("VALIDATION_DONE");
}

// ================================
// RESET
// ================================
void resetToIdle() {
  buzzerStop();
  state          = IDLE;
  timeoutActive  = false;
  cooldownActive = true;    // ← tambah ini
  cooldownTimer  = millis(); // ← tambah ini
  Serial.println("STATE:IDLE");
}

// ================================
// SETUP
// ================================
void setup() {
  Serial.begin(115200);

  pinMode(IR_PIN,        INPUT);
  pinMode(KAPASITIF_PIN, INPUT);
  pinMode(INDUKTIF_PIN,  INPUT);
  pinMode(BUZZER_PIN,    OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  servoKaleng.attach(SERVO_KALENG);
  servoPlastik.attach(SERVO_PLASTIK);
  servoKaleng.write(SERVO_IDLE);
  servoPlastik.write(SERVO_IDLE);

  Serial.println("=================================");
  Serial.println("   Sistem ESP32 - Ready (IDLE)   ");
  Serial.println("=================================");
}

// ================================
// LOOP
// ================================
void loop() {

  // Update buzzer non-blocking
  buzzerUpdate();

  // Timeout safety
  if (timeoutActive && millis() - timeoutTimer >= TIMEOUT_MS) {
    Serial.println("TIMEOUT");
    resetToIdle();
  }

  // Baca perintah dari Python
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();

    if (cmd == "VALIDATE" && state == PROCESSING) {
      timeoutActive = false;
      bacaSensor();

    } else if (cmd.startsWith("GERAK:") && state == PROCESSING) {
      timeoutActive  = false;
      String jenis   = cmd.substring(6);
      gerakServo(jenis);
      Serial.println("SERVO_DONE");
      resetToIdle();

    } else if (cmd == "REJECT:TIDAK_DIKETAHUI" && state == PROCESSING) {
      timeoutActive = false;
      state         = REJECT_LOCK;
      buzzerMode    = 1;
      buzzerOn      = true;
      digitalWrite(BUZZER_PIN, HIGH);
      buzzerTimer   = millis();
      Serial.println("STATE:REJECT_LOCK");

    } else if (cmd == "REJECT:KONFLIK" && state == PROCESSING) {
      timeoutActive = false;
      state         = REJECT_LOCK;
      buzzerMode    = 2;
      buzzerOn      = true;
      digitalWrite(BUZZER_PIN, HIGH);
      buzzerTimer   = millis();
      Serial.println("STATE:REJECT_LOCK");
    }
  }

  // IR sensor logic - ganti yang lama dengan ini
  bool irDetect = (digitalRead(IR_PIN) == LOW);

  if (state == IDLE && irDetect && !cooldownActive) {
      state         = PROCESSING;
      timeoutActive = true;
      timeoutTimer  = millis();
      Serial.println("OBJECT_DETECTED");

  } else if (state == REJECT_LOCK && !irDetect) {
      Serial.println("OBJECT_CLEARED");
      resetToIdle();
      cooldownActive = true;   // aktifkan cooldown setelah reject juga
      cooldownTimer  = millis();
  }

  // Update cooldown timer
  if (cooldownActive && millis() - cooldownTimer >= COOLDOWN_MS) {
      cooldownActive = false;
      Serial.println("COOLDOWN_DONE");
  }
}