// AutoDoor ESP32 – Bi-Directional Sync (Improved)
#include <SPI.h>
#include <MFRC522.h>
#include <vector>
#include <esp_now.h>
#include <WiFi.h>
#include <ESP32Servo.h>
#include "BluetoothSerial.h"

#define SS_PIN 5
#define RST_PIN 22
#define UID_SIZE 4
MFRC522 mfrc522(SS_PIN, RST_PIN);
BluetoothSerial SerialBT;

#define LEG_SERVO_PIN 17
#define LOCK_SERVO_PIN 16
Servo legServo;
Servo lockServo;

struct petInfo {
  std::vector<byte> petUID;
  bool isDog;
  // Per-UID metadata
  // For AutoDoor we care about time windows only
  struct TimeWindow { uint16_t startMin; uint16_t endMin; };
  std::vector<TimeWindow> windows;
};
std::vector<petInfo> storedPets;

struct struct_message {
  uint8_t count;
  uint8_t values[20][4];
  bool isDog[20];
};
struct_message incomingList;

uint8_t kittyKleanMAC[] = {0x3C, 0x8A, 0x1F, 0xA1, 0x09, 0xB8};
uint8_t pupFoodiMAC[]   = {0x14, 0x2B, 0x2F, 0xC7, 0x16, 0x34};

void setup() {
  Serial.begin(115200);
  SerialBT.begin("AutoDoor New");
  SPI.begin();
  mfrc522.PCD_Init();

  legServo.attach(LEG_SERVO_PIN);
  lockServo.attach(LOCK_SERVO_PIN);
  lockDoor();
  retractLeg();

  Serial.print("AutoDoor MAC: ");
  Serial.println(WiFi.macAddress());

  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) {
    Serial.println("❌ ESP-NOW init failed");
    return;
  }

  esp_now_register_recv_cb(OnDataRecv);
  esp_now_register_send_cb(OnDataSent);

  addPeer(kittyKleanMAC);
  addPeer(pupFoodiMAC);

  Serial.println("✅ AutoDoor ready");
}

// ---------- Helper: broadcast ASCII command to peers via ESP-NOW ----------
void broadcastCmd(const String &cmd) {
  String payload = String("CMD:") + cmd;
  const char *p = payload.c_str();
  esp_now_send(kittyKleanMAC, (const uint8_t*)p, strlen(p) + 1);
  esp_now_send(pupFoodiMAC,   (const uint8_t*)p, strlen(p) + 1);
}

int nowMinutes() {
  // Placeholder: without RTC/NTP, we cannot know real time. Return -1 to indicate unknown.
  return -1;
}

bool isWithinWindows(const std::vector<petInfo::TimeWindow> &wins, int minutesNow) {
  if (wins.empty()) return true; // no restriction
  if (minutesNow < 0) return true; // unknown time → allow
  for (const auto &w : wins) {
    uint16_t s = w.startMin;
    uint16_t e = w.endMin;
    if (s == e) continue; // skip empty
    if (s <= e) {
      if (minutesNow >= s && minutesNow <= e) return true;
    } else {
      // overnight window e.g. 22:00-06:00
      if (minutesNow >= s || minutesNow <= e) return true;
    }
  }
  return false;
}

void setWindowsForUid(const std::vector<byte> &uid, const std::vector<petInfo::TimeWindow> &wins) {
  for (auto &p : storedPets) {
    if (p.petUID.size() == UID_SIZE && std::equal(p.petUID.begin(), p.petUID.end(), uid.begin())) {
      p.windows = wins;
      return;
    }
  }
  // not found → create cat by default false
  petInfo np; np.petUID = uid; np.isDog = true; np.windows = wins;
  storedPets.push_back(np);
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
    // SETWINS:UID:st-en,st-en
    int p1 = cmd.indexOf(':');
    int p2 = cmd.indexOf(':', p1+1);
    if (p1>0 && p2>p1) {
      String uidHex = cmd.substring(p1+1, p2);
      String list = cmd.substring(p2+1);
      std::vector<byte> uid;
      if (!parseHexUid(uidHex, uid)) return;
      std::vector<petInfo::TimeWindow> wins;
      int start = 0;
      while (start < list.length()) {
        int comma = list.indexOf(',', start);
        String token = list.substring(start, comma == -1 ? list.length() : comma);
        int dash = token.indexOf('-');
        if (dash > 0) {
          uint16_t s = (uint16_t) token.substring(0, dash).toInt();
          uint16_t e = (uint16_t) token.substring(dash+1).toInt();
          wins.push_back({s, e});
        }
        if (comma == -1) break; else start = comma + 1;
      }
      setWindowsForUid(uid, wins);
      broadcastCmd(cmd);
    }
  }
}

void loop() {
  if (SerialBT.available()) {
    String cmd = SerialBT.readStringUntil('\n');
    cmd.trim();

    if (cmd.equalsIgnoreCase("GETUIDLIST")) {
      // Send UID list over Bluetooth in the format the app expects
      SerialBT.println("Sending list...");
      for (int i = 0; i < (int)storedPets.size(); i++) {
        // Build 8-char hex string without spaces
        String hex = "";
        for (int j = 0; j < UID_SIZE; j++) {
          if (storedPets[i].petUID[j] < 0x10) hex += "0";
          hex += String(storedPets[i].petUID[j], HEX);
        }
        hex.toUpperCase();
        SerialBT.print("UID ");
        SerialBT.print(i + 1);
        SerialBT.print(": ");
        SerialBT.println(hex);
      }
      SerialBT.println("Updated list sent successfully");
      return;
    }

    // Direct delete by UID command: DEL:XXXXXXXX
    if (cmd.startsWith("DEL:")) {
      String hex = cmd.substring(4);
      hex.trim();
      hex.toUpperCase();
      if (hex.length() == 8) {
        byte uid[UID_SIZE];
        bool ok = true;
        for (int i = 0; i < UID_SIZE; i++) {
          String byteStr = hex.substring(i * 2, i * 2 + 2);
          char b0 = byteStr.charAt(0);
          char b1 = byteStr.charAt(1);
          int v0 = (b0 >= '0' && b0 <= '9') ? (b0 - '0') : (b0 >= 'A' && b0 <= 'F') ? (b0 - 'A' + 10) : -1;
          int v1 = (b1 >= '0' && b1 <= '9') ? (b1 - '0') : (b1 >= 'A' && b1 <= 'F') ? (b1 - 'A' + 10) : -1;
          if (v0 < 0 || v1 < 0) { ok = false; break; }
          uid[i] = (byte)((v0 << 4) | v1);
        }
        if (ok) {
          bool removed = removeUID(uid);
          if (removed) {
            SerialBT.print("Removed UID: "); SerialBT.println(hex);
          } else {
            SerialBT.println("UID not found");
          }
        } else {
          SerialBT.println("Invalid DEL format");
        }
      } else {
        SerialBT.println("Invalid DEL length");
      }
      return;
    }

    if (cmd.startsWith("SETWINS:")) {
      handleAsciiCommand(cmd);
      return;
    }

    if (cmd == "0" || cmd == "1" || cmd == "2") {
      SerialBT.println("📡 Waiting for tag scan...");
      unsigned long start = millis();
      bool tagScanned = false;

      while (millis() - start < 10000) {
        if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
          tagScanned = true;
          break;
        }
      }

      if (tagScanned) {
        // Log scanned UID in spaced hex format
        SerialBT.print("Scanned UID: ");
        for (int i = 0; i < UID_SIZE; i++) {
          if (mfrc522.uid.uidByte[i] < 0x10) SerialBT.print("0");
          SerialBT.print(mfrc522.uid.uidByte[i], HEX);
          if (i < UID_SIZE - 1) SerialBT.print(" ");
        }
        SerialBT.println();

        bool ok = false;
        if (cmd == "0") {
          ok = addUID(mfrc522.uid.uidByte, true);
          SerialBT.println(ok ? "New UID added!" : "UID already exists");
        } else if (cmd == "1") {
          ok = addUID(mfrc522.uid.uidByte, false);
          SerialBT.println(ok ? "New UID added!" : "UID already exists");
        } else if (cmd == "2") {
          ok = removeUID(mfrc522.uid.uidByte);
          if (ok) {
            // Also echo removed UID as contiguous hex for clarity
            String hex = "";
            for (int j = 0; j < UID_SIZE; j++) {
              if (mfrc522.uid.uidByte[j] < 0x10) hex += "0";
              hex += String(mfrc522.uid.uidByte[j], HEX);
            }
            hex.toUpperCase();
            SerialBT.print("Removed UID: ");
            SerialBT.println(hex);
          } else {
            SerialBT.println("UID not found");
          }
        }

        mfrc522.PICC_HaltA();
        mfrc522.PCD_StopCrypto1();
        delay(500);
      } else {
        SerialBT.println("⏱️ Tag scan timed out");
      }
    }
  }

  if (!SerialBT.available() && mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    bool authed = isAuthorized(mfrc522.uid.uidByte);
    bool allowed = true;
    if (authed) {
      // enforce time windows if present
      for (const auto &p : storedPets) {
        if (p.petUID.size() == UID_SIZE && std::equal(p.petUID.begin(), p.petUID.end(), mfrc522.uid.uidByte)) {
          allowed = isWithinWindows(p.windows, nowMinutes());
          break;
        }
      }
    }
    if (authed && allowed) {
      Serial.println("✅ Authorized - Opening door");
      startDoorSequence();
    } else {
      Serial.println("❌ Unauthorized or outside time window");
    }
    mfrc522.PICC_HaltA();
    mfrc522.PCD_StopCrypto1();
    delay(500);
  }
}

bool isAuthorized(byte *uid) {
  for (const auto& pet : storedPets) {
    if (pet.petUID.size() == UID_SIZE && std::equal(pet.petUID.begin(), pet.petUID.end(), uid)) return true;
  }
  return false;
}

bool addUID(byte *uid, bool isDogX) {
  for (const auto& pet : storedPets) {
    if (pet.petUID.size() == UID_SIZE && std::equal(pet.petUID.begin(), pet.petUID.end(), uid)) return false;
  }
  petInfo newPet = {std::vector<byte>(uid, uid + UID_SIZE), isDogX};
  storedPets.push_back(newPet);
  updateAndSendUIDList();
  return true;
}

bool removeUID(byte *uid) {
  for (auto it = storedPets.begin(); it != storedPets.end(); ++it) {
    if (it->petUID.size() == UID_SIZE && std::equal(it->petUID.begin(), it->petUID.end(), uid)) {
      storedPets.erase(it);
      updateAndSendUIDList();
      return true;
    }
  }
  return false;
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
  esp_now_send(kittyKleanMAC, (uint8_t*)&incomingList, sizeof(incomingList));
  esp_now_send(pupFoodiMAC, (uint8_t*)&incomingList, sizeof(incomingList));
}

void OnDataRecv(const esp_now_recv_info *info, const uint8_t *data, int len) {
  memcpy(&incomingList, data, sizeof(incomingList));
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

void startDoorSequence() {
  legServo.attach(LEG_SERVO_PIN);   // Re-attach before use
  lockServo.attach(LOCK_SERVO_PIN);

  unlockDoor();
  delay(500);
  extendLeg();
  delay(3000);
  retractLeg();
  delay(2000);
  lockDoor();
}


void extendLeg()   { legServo.write(90); }
void retractLeg()  { legServo.write(0); }
void unlockDoor()  { lockServo.write(0); }
void lockDoor()    { lockServo.write(90); }

void addPeer(uint8_t *mac) {
  esp_now_del_peer(mac);
  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, mac, 6);
  peer.channel = 0;
  peer.encrypt = false;
  esp_now_add_peer(&peer);
}
