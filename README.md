# PupPal 🐾

A Flutter app for pet care—feeding guidance, device control, and optional local AI helpers.

[![Stars](https://img.shields.io/github/stars/yonathan-star/puppal_app?style=flat&color=FFD166)](https://github.com/yonathan-star/puppal_app/stargazers)
![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-Pixel_Ready-3DDC84?logo=android&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web-lightgrey)
[![License](https://img.shields.io/badge/License-MIT-informational)](LICENSE)

---

## ✨ Features

- **Feeding Estimator (Local)**: weight + breed → grams/day using standard RER/MER formulas (offline).
- **Extensible**: optional Cloudflare Worker for server tasks; room for BLE/Serial device control.
- **Flutter scaffold**: runs on Android (Pixel), iOS, and Web.

> The estimator is guidance only—always confirm with a veterinarian.

---

## 🗂️ Repository Layout

```text
puppal_app/
├─ lib/
├─ assets/
│  └─ readme/
│     ├─ social-preview.png
│     ├─ home.png
│     ├─ calculator.png
│     ├─ calculator-2.png
│     └─ bluetooth.png
├─ cloudflare_worker/
├─ android/
├─ ios/
├─ web/
├─ linux/
├─ macos/
├─ windows/
├─ test/
├─ pubspec.yaml
├─ pubspec.lock
├─ analysis_options.yaml
├─ .gitignore
├─ .metadata
└─ README.md
```

---

## 📸 Screenshots

<!-- Banner (optional; adjust width if you want) -->
<p align="center">
  <img src="assets/readme/social-preview.png?v=2" alt="PupPal banner" width="960">
</p>

<!-- Screenshots (two rows, 230px each; click to view full size) -->
<p align="center">
  <a href="assets/readme/home.png?v=2"><img src="assets/readme/home.png?v=2" alt="Home screen" width="200"></a>
  <a href="assets/readme/calculator.png?v=2"><img src="assets/readme/calculator.png?v=2" alt="Feeding estimator" width="200"></a>
  <a href="assets/readme/bluetooth.png?v=2"><img src="assets/readme/bluetooth.png?v=2" alt="Bluetooth manager" width="200"></a>
  <br>
  <a href="assets/readme/calculator-2.png?v=2"><img src="assets/readme/calculator-2.png?v=2" alt="Estimator (details)" width="200"></a>
</p>

> Pure Markdown can’t control on-page image width. If these look too large, export smaller copies to the **same paths** (e.g., 720 px wide).

---

## 🎞️ GIF of the App

<p align="center">
  <a href="assets/readme/demo.gif?v=2">
    <img src="assets/readme/demo.gif?v=2" alt="App demo" width="230">
  </a>
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
```

**If you have a Pixel plugged in:**

```bash
flutter devices
flutter run -d <pixel_device_id>
```

---

## 🧠 Local Feeding Estimator (optional module)

This repo supports a local, offline feeding estimator based on veterinary formulas:

```
RER = 70 × (kg^0.75)
MER = RER × factor  (species, age, neuter, activity, breed bias, BCS)
grams/day = MER_kcal / kcal_per_gram
```

Suggested integration (example files):

- Logic: `lib/ai/local_feeding_ai.dart`
- UI page: `lib/pages/feeding_calculator_page.dart`

Open from any screen:

```dart
import 'package:puppal_app/pages/feeding_calculator_page.dart';

final grams = await showFeedingCalculator(context);
```

---

## ☁️ Optional: Cloudflare Worker

If you want a lightweight backend:

```bash
cd cloudflare_worker
npm i
npx wrangler login
npx wrangler deploy
```

---

## 🧪 Testing

```bash
flutter test
```

---

## 📦 Build

**Android**

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS (on macOS)**

```bash
flutter build ios --release
```

**Web**

```bash
flutter build web
```

---

## 🤝 Contributing

- Create a feature branch: `git checkout -b feature/<name>`  
- Commit with clear messages  
- Open a PR with summary, screenshots/GIF if UI, and test notes





