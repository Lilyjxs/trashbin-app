// #include <ESP32Servo.h>

// // ================================
// // PIN DEFINITION
// // ================================
// #define KAPASITIF_PIN   5
// #define INDUKTIF_PIN    4
// #define SERVO_KALENG    18
// #define SERVO_PLASTIK   19

// #define SERVO_IDLE      90
// #define SERVO_PULL      0
// #define SERVO_HOLD      1000

// Servo servoKaleng;
// Servo servoPlastik;

// void setup() {
//   Serial.begin(115200);
//   pinMode(KAPASITIF_PIN, INPUT);
//   pinMode(INDUKTIF_PIN,  INPUT);

//   servoKaleng.attach(SERVO_KALENG);
//   servoPlastik.attach(SERVO_PLASTIK);
//   servoKaleng.write(SERVO_IDLE);
//   servoPlastik.write(SERVO_IDLE);

//   Serial.println("=================================");
//   Serial.println("   TES SENSOR + SERVO - Ready    ");
//   Serial.println("=================================");
//   Serial.println("Dekatkan objek ke sensor...");
// }

// void loop() {
//   bool kapasitif = digitalRead(KAPASITIF_PIN);
//   bool induktif  = digitalRead(INDUKTIF_PIN);

//   bool adaObjek = (kapasitif == LOW);
//   bool adaLogam = (induktif  == LOW);

//   Serial.print("Kapasitif: ");
//   Serial.print(kapasitif);
//   Serial.print(" | Induktif: ");
//   Serial.print(induktif);
//   Serial.print(" → ");

//   if (adaObjek && adaLogam) {
//     Serial.println("KALENG → Servo kaleng gerak!");
//     servoKaleng.write(SERVO_PULL);
//     delay(SERVO_HOLD);
//     servoKaleng.write(SERVO_IDLE);
//     delay(2000); // jeda sebelum baca lagi

//   } else if (adaObjek && !adaLogam) {
//     Serial.println("PLASTIK → Servo plastik gerak!");
//     servoPlastik.write(SERVO_PULL);
//     delay(SERVO_HOLD);
//     servoPlastik.write(SERVO_IDLE);
//     delay(2000);

//   } else {
//     Serial.println("Tidak ada objek");
//   }

//   delay(500);
// }