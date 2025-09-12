// PupFoodi ESP32 – Bi-Directional Sync + Feeding Logic (Scan-based)
#include <SPI.h>
#include <MFRC522.h>
#include <vector>
#include <esp_now.h>
#include <WiFi.h>
#include <BluetoothSerial.h>
#include <AccelStepper.h>

BluetoothSerial SerialBT;

#define SS_PIN 5
#define RST_PIN 22
#define UID_SIZE 4
MFRC522 mfrc522(SS_PIN, RST_PIN);

// Stepper (food dispenser)
#define STEPPER_IN1 32
#define STEPPER_IN2 33
#define STEPPER_IN3 25
#define STEPPER_IN4 26
AccelStepper stepper(AccelStepper::HALF4WIRE, STEPPER_IN1, STEPPER_IN3, STEPPER_IN2, STEPPER_IN4);

// Linear Actuator via L298N
#define ACTUATOR_ENA 27
#define ACTUATOR_IN1 14
#define ACTUATOR_IN2 12

// MAC Addresses
uint8_t kittyKleanMAC[] = {0x3C, 0x8A, 0x1F, 0xA1, 0x09, 0xB8};
uint8_t autoDoorMAC[]   = {0x14, 0x2B, 0x2F, 0xC6, 0xFC, 0x1C};

struct petInfo {
  std::vector<byte> petUID;
  bool isDog;
  int scanCount = 0;
  // Metadata for dosing
  uint16_t gramsPerDay = 0;        // from app
  uint16_t densityGramsPerCup = 0; // from app
};
std::vector<petInfo> storedPets;

struct struct_message {
  uint8_t count;
  uint8_t values[20][4];
  bool isDog[20];
};
struct_message incomingList;

bool actionRunning = false;

void setup() {
  Serial.begin(115200);
  SerialBT.begin("PupFoodi");
  SPI.begin();
  mfrc522.PCD_Init();

  stepper.setMaxSpeed(650);
  stepper.setAcceleration(450);

  pinMode(ACTUATOR_ENA, OUTPUT);
  pinMode(ACTUATOR_IN1, OUTPUT);
  pinMode(ACTUATOR_IN2, OUTPUT);
  analogWrite(ACTUATOR_ENA, 255);

  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) {
    Serial.println("❌ ESP-NOW init failed");
    return;
  }
  esp_now_register_recv_cb(OnDataRecv);
  esp_now_register_send_cb(OnDataSent);

  addPeer(kittyKleanMAC);
  addPeer(autoDoorMAC);

  Serial.println("🟢 PupFoodi Ready - Waiting for RFID scan...");
}

void broadcastCmd(const char *payload) {
  esp_now_send(kittyKleanMAC, (const uint8_t*)payload, strlen(payload) + 1);
  esp_now_send(autoDoorMAC,   (const uint8_t*)payload, strlen(payload) + 1);
}

void broadcastCmd(const String &cmd) {
  String payload = String("CMD:") + cmd;
  broadcastCmd(payload.c_str());
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

void setMetaForUid(const std::vector<byte> &uid, uint16_t gramsPerDay, uint16_t density) {
  for (auto &p : storedPets) {
    if (p.petUID.size()==UID_SIZE && std::equal(p.petUID.begin(), p.petUID.end(), uid.begin())) {
      p.gramsPerDay = gramsPerDay;
      p.densityGramsPerCup = density;
      return;
    }
  }
  petInfo np; np.petUID = uid; np.isDog = true; np.scanCount=0; np.gramsPerDay=gramsPerDay; np.densityGramsPerCup=density; storedPets.push_back(np);
}

void handleAsciiCommand(const String &cmd) {
  if (cmd.startsWith("SETMETA:")) {
    // SETMETA:UID:grams:density
    int p1 = cmd.indexOf(':');
    int p2 = cmd.indexOf(':', p1+1);
    int p3 = cmd.indexOf(':', p2+1);
    if (p1>0 && p2>p1 && p3>p2) {
      String uidHex = cmd.substring(p1+1, p2);
      String gramsStr = cmd.substring(p2+1, p3);
      String densStr = cmd.substring(p3+1);
      std::vector<byte> uid; if (!parseHexUid(uidHex, uid)) return;
      uint16_t grams = (uint16_t) gramsStr.toInt();
      uint16_t dens = (uint16_t) densStr.toInt();
      setMetaForUid(uid, grams, dens);
      broadcastCmd(cmd);
    }
  } else if (cmd.startsWith("SETWINS:")) {
    // Forward time windows to other devices (PupFoodi doesn't use this data)
    Serial.println("📤 Forwarding SETWINS command to peers");
    broadcastCmd(cmd);
  }
}

void loop() {
  if (SerialBT.available()) {
    String cmd = SerialBT.readStringUntil('\n');
    cmd.trim();
    if (cmd.startsWith("SETMETA:") || cmd.startsWith("SETWINS:")) { handleAsciiCommand(cmd); return; }
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
    // legacy scan-based add/remove
    if (cmd == "0" || cmd == "1" || cmd == "2") {
      while (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) {}
      if (cmd == "0") addUID(mfrc522.uid.uidByte, true);
      else if (cmd == "1") addUID(mfrc522.uid.uidByte, false);
      else if (cmd == "2") removeUID(mfrc522.uid.uidByte);
    }
  }

  if (!actionRunning && mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    for (auto &pet : storedPets) {
      if (std::equal(pet.petUID.begin(), pet.petUID.end(), mfrc522.uid.uidByte)) {
        pet.scanCount++;
        Serial.printf("✅ Authorized tag detected. Scan count: %d\n", pet.scanCount);
        startFeedingSequence(pet);
        mfrc522.PICC_HaltA();
        mfrc522.PCD_StopCrypto1();
        return;
      }
    }
    Serial.println("❌ Unauthorized Tag");
    mfrc522.PICC_HaltA();
    mfrc522.PCD_StopCrypto1();
  }
}

void startFeedingSequence(petInfo &pet) {
  actionRunning = true;

  int grams = computePortionGrams(pet);
  if (grams > 0) {
    Serial.printf("🍖 Dispensing %d g...\n", grams);
    dispenseGrams(grams, pet);
  } else {
    Serial.println("⏭️ No food dispensed (portion 0).");
  }

  Serial.println("📤 Extending tray...");
  digitalWrite(ACTUATOR_IN1, HIGH);
  digitalWrite(ACTUATOR_IN2, LOW);
  delay(3000);
  stopActuator();

  Serial.println("⏳ Waiting 15 seconds...");
  delay(15000);

  Serial.println("📥 Retracting tray...");
  digitalWrite(ACTUATOR_IN1, LOW);
  digitalWrite(ACTUATOR_IN2, HIGH);
  delay(3000);
  stopActuator();

  Serial.println("✅ Feeding cycle complete.");
  actionRunning = false;
}

void stopActuator() {
  digitalWrite(ACTUATOR_IN1, LOW);
  digitalWrite(ACTUATOR_IN2, LOW);
}

int computePortionGrams(const petInfo &pet) {
  // Simple default: split daily grams into 2 portions; if density unknown, still dispense grams
  int daily = pet.gramsPerDay > 0 ? pet.gramsPerDay : 0;
  if (daily <= 0) return 0;
  const int portionsPerDay = 2;
  return (daily + portionsPerDay - 1) / portionsPerDay; // ceil divide
}

void dispenseGrams(int grams, const petInfo &pet) {
  // Convert grams to steps via density and calibration
  // Assume 1 cup = 236.588 mL; density given in g/cup
  int density = pet.densityGramsPerCup > 0 ? pet.densityGramsPerCup : 112; // fallback
  // grams -> cups
  double cups = grams / (double) density;
  // cups -> steps (calibrate steps per cup)
  const int STEPS_PER_CUP = 2048; // TODO: calibrate for hardware
  int steps = (int) round(cups * STEPS_PER_CUP);
  if (steps <= 0) return;
  stepper.move(steps);
  while (stepper.distanceToGo() != 0) stepper.run();
  delay(300);
}

void addUID(byte *uid, bool isDogX) {
  for (const auto& pet : storedPets)
    if (std::equal(pet.petUID.begin(), pet.petUID.end(), uid)) return;
  petInfo newPet = {std::vector<byte>(uid, uid + UID_SIZE), isDogX, 0};
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
    for (int j = 0; j < UID_SIZE; j++) incomingList.values[i][j] = storedPets[i].petUID[j];
    incomingList.isDog[i] = storedPets[i].isDog;
  }
  sendToAllPeers();
}

void sendToAllPeers() {
  esp_now_send(kittyKleanMAC, (uint8_t*)&incomingList, sizeof(incomingList));
  esp_now_send(autoDoorMAC, (uint8_t*)&incomingList, sizeof(incomingList));
  Serial.println("📤 UID list broadcasted to all peers");
}

void OnDataRecv(const esp_now_recv_info *info, const uint8_t *data, int len) {
  memcpy(&incomingList, data, sizeof(incomingList));
  storedPets.clear();
  for (int i = 0; i < incomingList.count; i++) {
    std::vector<byte> uid(incomingList.values[i], incomingList.values[i] + UID_SIZE);
    storedPets.push_back({uid, incomingList.isDog[i], 0});
  }
  Serial.println("📥 UID list synced from peer");
}

void OnDataSent(const uint8_t *mac, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "📦 Send Success" : "⚠️ Send Fail");
}

void addPeer(uint8_t *mac) {
  esp_now_del_peer(mac);
  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, mac, 6);
  peer.channel = 0;
  peer.encrypt = false;
  esp_now_add_peer(&peer);
}
