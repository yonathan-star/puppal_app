// KittyKlean ESP32 – Bi-Directional Sync (Cats Only)
#include <SPI.h>
#include <MFRC522.h>
#include <vector>
#include <esp_now.h>
#include <WiFi.h>
#include <BluetoothSerial.h>
#include <AccelStepper.h>

#define SS_PIN 5
#define RST_PIN 22
#define UID_SIZE 4
MFRC522 mfrc522(SS_PIN, RST_PIN);
BluetoothSerial SerialBT;

// Stepper Pins
#define DOOR_IN1 32
#define DOOR_IN2 33
#define DOOR_IN3 25
#define DOOR_IN4 26
#define CLEAN_IN1 14
#define CLEAN_IN2 27
#define CLEAN_IN3 12
#define CLEAN_IN4 13
AccelStepper doorStepper(AccelStepper::HALF4WIRE, DOOR_IN1, DOOR_IN3, DOOR_IN2, DOOR_IN4);
AccelStepper cleaningStepper(AccelStepper::HALF4WIRE, CLEAN_IN1, CLEAN_IN3, CLEAN_IN2, CLEAN_IN4);

// Ultrasonic Sensor
#define TRIG_PIN 4
#define ECHO_PIN 15

struct petInfo {
  std::vector<byte> petUID;
  bool isDog;
  // Accept windows for parity, though KittyKlean ignores them
  struct TimeWindow { uint16_t startMin; uint16_t endMin; };
  std::vector<TimeWindow> windows;};
std::vector<petInfo> storedPets;

struct struct_message {
  uint8_t count;
  uint8_t values[20][4];
  bool isDog[20];
};
struct_message incomingList;

uint8_t autoDoorMAC[]   = {0x14, 0x2B, 0x2F, 0xC6, 0xFC, 0x1C};
uint8_t pupFoodiMAC[]   = {0x14, 0x2B, 0x2F, 0xC7, 0x16, 0x34};

bool motorRunning = false;
int motorState = 0;
int cleaningSteps = 3000;
bool doubleClean = true;

void setup() {
  Serial.begin(115200);
  SerialBT.begin("KittyKlean");
  SPI.begin();
  mfrc522.PCD_Init();

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  doorStepper.setMaxSpeed(500);
  doorStepper.setAcceleration(370);
  cleaningStepper.setMaxSpeed(800);
  cleaningStepper.setAcceleration(650);

  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) {
    Serial.println("❌ ESP-NOW init failed");
    return;
  }

  esp_now_register_recv_cb(OnDataRecv);
  esp_now_register_send_cb(OnDataSent);

  addPeer(autoDoorMAC);
  addPeer(pupFoodiMAC);

  Serial.println("✅ KittyKlean ready");
}

void broadcastCmd(const String &cmd) {
  String payload = String("CMD:") + cmd;
  const char *p = payload.c_str();
  esp_now_send(autoDoorMAC, (const uint8_t*)p, strlen(p) + 1);
  esp_now_send(pupFoodiMAC, (const uint8_t*)p, strlen(p) + 1);
}

bool parseHexUid(const String &hex, std::vector<byte> &out) {
  if (hex.length() != 8) return false;
  out.resize(UID_SIZE);
  for (int i = 0; i < UID_SIZE; i++) {
    int v = (int) strtol(hex.substring(i*2, i*2+2).c_str(), nullptr, 16);
    out[i] = (byte)v;
  }
  return true;
}

void handleAsciiCommand(const String &cmd) {
  if (cmd.startsWith("SETWINS:")) {
    // Forward time windows to other devices (KittyKlean ignores windows locally)
    Serial.println("📤 Forwarding SETWINS command to peers");
    broadcastCmd(cmd);
  } else if (cmd.startsWith("SETMETA:")) {
    // Forward feeding data to other devices (KittyKlean doesn't use this data)
    Serial.println("📤 Forwarding SETMETA command to peers");
    broadcastCmd(cmd);
  }
}

void loop() {
  if (SerialBT.available()) {
    String cmd = SerialBT.readStringUntil('\n');
    cmd.trim();
    if (cmd.startsWith("SETWINS:")) { handleAsciiCommand(cmd); return; }
    if (cmd.startsWith("SETMETA:")) { handleAsciiCommand(cmd); return; }
    if (cmd.equalsIgnoreCase("GETUIDLIST")) {
      SerialBT.println("Sending list...");
      for (int i = 0; i < (int)storedPets.size(); i++) {
        String hex = ""; for (int j=0;j<UID_SIZE;j++){ if(storedPets[i].petUID[j]<0x10) hex+="0"; hex+=String(storedPets[i].petUID[j],HEX);} hex.toUpperCase();
        SerialBT.print("UID "); SerialBT.print(i+1); SerialBT.print(": "); SerialBT.println(hex);
      }
      SerialBT.println("Updated list sent successfully");
      return;
    }
    if (cmd.startsWith("DEL:")) {
      String hex = cmd.substring(4); hex.trim(); hex.toUpperCase();
      if (hex.length()==8){ byte uid[UID_SIZE]; for(int i=0;i<UID_SIZE;i++){ uid[i]=(byte)strtol(hex.substring(i*2,i*2+2).c_str(),nullptr,16);} removeUID(uid); SerialBT.print("Removed UID: "); SerialBT.println(hex);} return;
    }
    if (cmd == "1" || cmd == "2") {
      while (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) {}
      if (cmd == "1") addUID(mfrc522.uid.uidByte, false);
      else if (cmd == "2") removeUID(mfrc522.uid.uidByte);
    }
  }

  if (!motorRunning && mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    if (isAuthorized(mfrc522.uid.uidByte)) {
      Serial.println("✅ Authorized Cat - Start cleaning");
      startCleaningSequence();
    } else {
      Serial.println("❌ Unauthorized tag");
    }
    mfrc522.PICC_HaltA();
    mfrc522.PCD_StopCrypto1();
  }
  checkMotorState();
}

bool isAuthorized(byte *uid) {
  for (const auto& pet : storedPets) {
    if (std::equal(pet.petUID.begin(), pet.petUID.end(), uid) && !pet.isDog) return true;
  }
  return false;
}

void addUID(byte *uid, bool isDogX) {
  for (const auto& pet : storedPets) {
    if (std::equal(pet.petUID.begin(), pet.petUID.end(), uid)) return;
  }
  petInfo newPet = {std::vector<byte>(uid, uid + UID_SIZE), isDogX};
  storedPets.push_back(newPet);
  updateAndSendUIDList();
}

void removeUID(byte *uid) {
  for (auto it = storedPets.begin(); it != storedPets.end(); ++it) {
    if (std::equal(it->petUID.begin(), it->petUID.end(), uid)) {
      storedPets.erase(it);
      updateAndSendUIDList();
      return;
    }
  }
}

void updateAndSendUIDList() {
  incomingList.count = storedPets.size();
  for (int i = 0; i < storedPets.size(); i++) {
    for (int j = 0; j < UID_SIZE; j++) {
      incomingList.values[i][j] = storedPets[i].petUID[j];
    }
    incomingList.isDog[i] = storedPets[i].isDog;
  }

  Serial.println("🔄 Sending UID list to peers...");
  esp_now_send(autoDoorMAC, (uint8_t*)&incomingList, sizeof(incomingList));
  esp_now_send(pupFoodiMAC, (uint8_t*)&incomingList, sizeof(incomingList));
}

void OnDataRecv(const esp_now_recv_info *info, const uint8_t *incomingData, int len) {
  memcpy(&incomingList, incomingData, sizeof(incomingList));
  storedPets.clear();
  Serial.println("📥 UID list synced from peer:");
  for (int i = 0; i < incomingList.count; i++) {
    std::vector<byte> uid(incomingList.values[i], incomingList.values[i] + UID_SIZE);
    storedPets.push_back({uid, incomingList.isDog[i]});
    for (int j = 0; j < UID_SIZE; j++) {
      Serial.print(uid[j] < 0x10 ? " 0" : " ");
      Serial.print(uid[j], HEX);
    }
    Serial.println(incomingList.isDog[i] ? " (Dog)" : " (Cat)");
  }
}

void OnDataSent(const uint8_t *mac, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "📦 Send Success" : "⚠️ Send Fail");
}

void startCleaningSequence() {
  motorRunning = true;
  motorState = 1;
  doorStepper.moveTo(700);
}

void checkMotorState() {
  if (!motorRunning) return;
  doorStepper.run();
  cleaningStepper.run();

  if (motorState == 1 && doorStepper.distanceToGo() == 0) {
    delay(2000);
    while (isObjectDetected()) delay(500);
    motorState = 2;
    cleaningStepper.moveTo(cleaningSteps);
  } else if (motorState == 2 && cleaningStepper.distanceToGo() == 0) {
    motorState = doubleClean ? 3 : 5;
    cleaningStepper.moveTo(doubleClean ? cleaningStepper.currentPosition() - cleaningSteps : 0);
  } else if (motorState == 3 && cleaningStepper.distanceToGo() == 0) {
    motorState = 4;
    cleaningStepper.moveTo(cleaningStepper.currentPosition() + cleaningSteps);
  } else if (motorState == 4 && cleaningStepper.distanceToGo() == 0) {
    motorState = 5;
    cleaningStepper.moveTo(0);
  } else if (motorState == 5 && cleaningStepper.distanceToGo() == 0) {
    motorState = 6;
    doorStepper.moveTo(0);
  } else if (motorState == 6 && doorStepper.distanceToGo() == 0) {
    motorRunning = false;
    motorState = 0;
  }
}

bool isObjectDetected() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  int distance = duration * 0.034 / 2;
  return distance > 0 && distance <= 10;
}

void addPeer(uint8_t *mac) {
  esp_now_del_peer(mac);
  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, mac, 6);
  peer.channel = 0;
  peer.encrypt = false;
  esp_now_add_peer(&peer);
}
