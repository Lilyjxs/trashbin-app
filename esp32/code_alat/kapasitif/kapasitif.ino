// #define SENSOR_PIN 4
// #define DEBOUNCE_TIME 50  // ms

// bool lastState = HIGH;
// bool currentState;
// unsigned long lastDebounceTime = 0;

// void setup() {
//   Serial.begin(115200);
//   pinMode(SENSOR_PIN, INPUT);
  
//   Serial.println("=================================");
//   Serial.println("  Sistem Deteksi Objek - Ready  ");
//   Serial.println("=================================");
// }

// void loop() {
//   bool reading = digitalRead(SENSOR_PIN);

//   // Debounce logic
//   if (reading != lastState) {
//     lastDebounceTime = millis();
//   }

//   if ((millis() - lastDebounceTime) > DEBOUNCE_TIME) {
//     if (reading != currentState) {
//       currentState = reading;

//       if (currentState == LOW) {
//         Serial.println("✅ [KAPASITIF] Objek Terdeteksi");
//         Serial.println("   → Siap untuk proses selanjutnya");
//       } else {
//         Serial.println("❌ [KAPASITIF] Tidak Ada Objek");
//         Serial.println("   → Menunggu input...");
//       }
//     }
//   }

//   lastState = reading;
// }