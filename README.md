# 🌿 Nooktime

> **Intelligent, Offline-First AI Routine Planner & Tactical HUD**

Nooktime is a privacy-first, highly aesthetic productivity application built with Flutter. It merges cloud-scale AI routine synthesis with on-device local pattern learning, Google Calendar synchronization, real-time analytics, and an interactive daily timeline HUD.

<br>

## ✨ Key Features

- **Tactical HUD & Daily Routine Studio** — Interactive visual timeline with real-time progress indicators, category colour coding, and completion tracking.
- **Dual-Engine AI Routine Planner**
  - ☁️ **Cloud Engine (Gemini)** — Ultra-fast routine synthesis from natural language prompts.
  - 📱 **On-Device Local AI Engine** — Distills scheduling patterns locally with zero network latency when offline.
- **Google Calendar Dual-Sync** — Automatic background sync of events and tasks via OAuth2.
- **Cloud Firestore & Auth** — Encrypted cloud backup with offline-first local SQLite fallback (`sqflite`).
- **Streak & Analytics Engine** — Habit metrics, category time breakdown, and productivity score tracking.

<br>

## 🏗️ Architecture Overview

```
                    ┌───────────────────────────────────────────┐
                    │              Nooktime App                 │
                    └─────────────────────┬─────────────────────┘
                                          │
                ┌─────────────────────────┴─────────────────────────┐
                ▼                                                   ▼
  ┌───────────────────────────┐                       ┌───────────────────────────┐
  │   Cloud AI Engine (Gemini)│                       │  On-Device Local AI Engine │
  └─────────────┬─────────────┘                       └─────────────┬─────────────┘
                │                                                   │
                └─────────────────────────┬─────────────────────────┘
                                          ▼
                             ┌──────────────────────────────┐
                             │ SQLite Local DB / Sync Repo  │
                             └──────────────┬───────────────┘
                                            ▼
                             ┌──────────────────────────────┐
                             │  Google Calendar & Firestore │
                             └──────────────────────────────┘
```

<br>

---

## 🚀 Getting Started

Follow these steps **in order**. Skipping any step will cause the build to fail.

### Prerequisites

Make sure the following are installed before you begin:

| Tool | Minimum Version | Download |
|------|----------------|---------|
| Flutter SDK | `3.41.1` (Dart `3.11.0`) | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Android Studio / SDK | API 35+ | [developer.android.com](https://developer.android.com/studio) |
| JDK | 17 (Eclipse Temurin recommended) | [adoptium.net](https://adoptium.net/) |
| Git | Any | [git-scm.com](https://git-scm.com/) |

Verify your setup:

```bash
flutter doctor
```

All items should show ✅ (Android toolchain + connected device/emulator required).

---

### Step 1 — Clone & Install Dependencies

```bash
git clone https://github.com/annxshan/nooktime.git
cd nooktime
flutter pub get
```

---

### Step 2 — Set Up Firebase (Required)

> ⚠️ **This step is mandatory.** The app uses Firebase Auth, Firestore, and the Google Services plugin. The build will fail without `google-services.json`.

#### 2a. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/) and click **Add project**.
2. Enter a project name (e.g. `nooktime`) and follow the prompts.

#### 2b. Register an Android App

1. In your Firebase project, click ⚙️ **Project Settings** → **Your apps** → **Add app** → **Android**.
2. Enter the package name exactly as:
   ```
   com.example.nooktime
   ```
3. Click **Register app**.

#### 2c. Download `google-services.json`

1. On the same page, click **Download `google-services.json`**.
2. Place the file here in your local clone:
   ```
   android/app/google-services.json
   ```
   > This file is intentionally gitignored and must never be committed. The repo includes `android/app/google-services.json.example` as a reference for the expected format only — it will **not** work as a real config.

#### 2d. Enable Firebase Services

In the Firebase Console, enable the following for your project:

- **Authentication** → Sign-in method → enable **Google**
- **Firestore Database** → Create database (start in test mode for development)

---

### Step 3 — Set Up Google Sign-In OAuth (Required for Calendar Sync)

The app uses Google Calendar via OAuth2. You need an OAuth 2.0 Web Client ID:

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → **Credentials**.
2. Create or use the existing **OAuth 2.0 Client ID** of type **Web application**.
3. Copy the `client_id` value (ends in `.apps.googleusercontent.com`).
4. Open `lib/main.dart` and replace the placeholder on line 55:

   ```dart
   await authService.initialize(
     serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
   );
   ```

5. Also enable the **Google Calendar API** in Google Cloud Console:
   - APIs & Services → Library → search **"Google Calendar API"** → Enable.

---

### Step 4 — Configure SHA-1 Fingerprint (Required for Google Sign-In on Android)

Google Sign-In requires your app's debug SHA-1 fingerprint to be registered in both Firebase and Google Cloud Console.

Get your debug SHA-1:

```bash
# macOS / Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Then add the SHA-1 fingerprint in:
- **Firebase Console** → Project Settings → Your Android app → Add fingerprint
- **Google Cloud Console** → Credentials → Your OAuth Client ID → Authorized Android Apps → Add fingerprint

---

### Step 5 — Run the App

```bash
flutter run
```

To enable **Gemini-powered AI scheduling**, pass your API key at runtime:

```bash
flutter run --dart-define=GROQ_API_KEY=your_gemini_or_groq_api_key_here
```

> Get a free Gemini API key at [aistudio.google.com](https://aistudio.google.com/) or a Groq key at [console.groq.com](https://console.groq.com/). The app works without it — AI features will fall back to the local pattern engine.

---

## 📦 Building a Release APK

```bash
flutter build apk --split-per-abi
```

Output APKs (one per CPU architecture) are placed in:
```
build/app/outputs/flutter-apk/
  app-arm64-v8a-release.apk     ← most modern Android phones
  app-armeabi-v7a-release.apk   ← older 32-bit devices
  app-x86_64-release.apk        ← emulators
```

---

## 🤖 Local AI Models (Optional)

For fully offline AI inference, place a GGUF-quantized model in:

```
assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf
```

> Model files are gitignored due to size. Recommended: [Qwen 2.5 0.5B Q4_K_M](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF).

---

## 🧪 Testing & Code Quality

```bash
flutter analyze    # static analysis
flutter test       # unit tests
```

---

## 🗂️ Gitignored Files — What You Need to Supply

| File | Location | Why it's missing |
|------|----------|-----------------|
| `google-services.json` | `android/app/` | Contains private Firebase config & API keys |
| `GoogleService-Info.plist` | `ios/Runner/` | iOS equivalent of above |
| `firebase_options.dart` | `lib/` | Generated by FlutterFire CLI — optional alternative to manual setup |
| `api_keys.dart` | `lib/core/constants/` | Stores Groq/Gemini API keys locally |
| GGUF model files (`*.gguf`) | `assets/models/` | Too large for git (100 MB+) |

---

## 🔑 Environment Variables (via `--dart-define`)

| Key | Description | Required |
|-----|-------------|----------|
| `GROQ_API_KEY` | Groq / Gemini API key for cloud AI scheduling | No (optional) |

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for details.
