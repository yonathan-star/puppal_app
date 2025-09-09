<p align="center">
  <img src="assets/readme/social-preview.png" alt="PupPal banner" width="100%" />
</p>

<h1 align="center">PupPal 🐾</h1>
<p align="center">
  A Flutter app for pet care—feeding guidance, device control, and optional local AI helpers.
</p>

<p align="center">
  <a href="https://github.com/yonathan-star/puppal_app/stargazers">
    <img alt="Stars" src="https://img.shields.io/github/stars/yonathan-star/puppal_app?style=flat&color=FFD166">
  </a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white">
  <img alt="Android" src="https://img.shields.io/badge/Android-Pixel_Ready-3DDC84?logo=android&logoColor=white">
  <img alt="Platforms" src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web-lightgrey">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/License-MIT-informational"></a>
</p>

---

## ✨ Features
- **Feeding Estimator (Local)**: weight + breed → grams/day using standard RER/MER formulas (offline).
- **Extensible**: optional Cloudflare Worker for server tasks; room for BLE/Serial device control.
- **Flutter scaffold**: runs on Android (Pixel), iOS, and Web.

> **Note**: The estimator is guidance only—always confirm with a veterinarian.

---

## 🗂️ Repository Layout

puppal_app/
├─ lib/ # Flutter application code
├─ assets/readme/ # Images used in this README (screenshots, banner)
├─ cloudflare_worker/ # Optional edge/backend worker (TypeScript)
├─ android/ ios/ web/ … # Platform targets
└─ README.md


---

<h2 align="center">📸 Screenshots</h2>

<p align="center">
  <a href="assets/readme/home.png"><img src="assets/readme/home.png" alt="Home screen" width="280"></a>
  <a href="assets/readme/calculator.png"><img src="assets/readme/calculator.png" alt="Feeding estimator" width="280"></a>
  <a href="assets/readme/bluetooth.png"><img src="assets/readme/bluetooth.png" alt="Bluetooth manager" width="280"></a>
</p>

<p align="center">
  <a href="assets/readme/calculator-2.png"><img src="assets/readme/calculator-2.png" alt="Estimator (details)" width="280"></a>
</p>
<p align="center">
  <img src="assets/readme/demo.gif" alt="App demo" width="420">
</p>

---

## 🚀 Getting Started

### Prereqs
- Flutter SDK (stable), Dart
- For Android (Pixel): Android SDK + USB debugging enabled

### Install & run
```bash
git clone https://github.com/yonathan-star/puppal_app.git
cd puppal_app
flutter pub get
flutter run

### If you have a Pixel plugged in:
flutter devices
flutter run -d <pixel_device_id>

### 🧠 Local Feeding Estimator (optional module)
### This repo supports a local, offline feeding estimator based on veterinary formulas:
RER = 70 × (kg^0.75)
MER = RER × factor (species, age, neuter, activity, breed bias, BCS)
Grams/day = MER_kcal / kcal_per_gram
Suggested integration (example files):
Logic: lib/ai/local_feeding_ai.dart
UI page: lib/pages/feeding_calculator_page.dart
Open from any screen:

import 'package:puppal_app/pages/feeding_calculator_page.dart';
final grams = await showFeedingCalculator(context);

### ☁️ Optional: Cloudflare Worker

### If you want a lightweight backend:

cd cloudflare_worker
npm i
npx wrangler login
npx wrangler deploy

### 🧪 Testing

flutter test

### 📦 Build

### Android:

flutter build apk --release
# or
flutter build appbundle --release


### iOS (on macOS):

flutter build ios --release


### Web:

flutter build web

🤝 Contributing
Create a feature branch: git checkout -b feature/<name>
Commit with clear messages
Open a PR with summary, screenshots/GIF if UI, and test notes



