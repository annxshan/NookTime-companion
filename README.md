# Nooktime

> **Intelligent, Offline-First AI Routine Planner & Tactical HUD**

Nooktime is a privacy-first, highly aesthetic productivity application built with Flutter. It seamlessly merges cloud-scale AI routine synthesis with on-device local pattern learning, Google Calendar synchronization, real-time analytics, and an interactive daily timeline HUD.

---

## Key Features

- **Tactical HUD & Daily Routine Studio**: Interactive visual timeline with real-time progress indicators, category color coding, and completion tracking.
- **Dual-Engine AI Routine Planner**:
  - **Cloud Engine (Groq Llama 3.3 70B & Gemini)**: Ultra-fast routine synthesis from unstructured natural language prompts (e.g. *"Exam next week, study 3 hours, keep 1 hour gym"*).
  - **On-Device Local AI Engine (Qwen 0.5B / Local Pattern Synthesizer)**: Distills scheduling patterns locally with 0ms network latency when offline or out of quota.
- **Google Calendar Dual-Sync**: Automatic background synchronization of events and tasks with OAuth2 security.
- **Cloud Firestore & Auth Integration**: Encrypted cloud backup with smooth offline-first local SQLite fallback (`sqflite`).
- **Streak & Analytics Engine**: Habit building metrics, category time breakdown, and productivity score tracking.

---

## Architecture Overview

```
                        ┌───────────────────────────────────────────┐
                        │              Nooktime App                 │
                        └─────────────────────┬─────────────────────┘
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    ▼                                                   ▼
      ┌───────────────────────────┐                       ┌───────────────────────────┐
      │   Cloud AI Engine (Groq)  │                       │  On-Device Local AI Engine │
      │  llama-3.3-70b-versatile  │                       │   Local Pattern Learner   │
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

---

## Prerequisites

Before setting up the project, ensure you have installed:

- **Flutter SDK**: `>= 3.11.0` (Dart SDK `>= 3.11.0`)
- **Android SDK Platform-Tools**: Android 15 / SDK 35+ API target
- **Firebase Account**: Required if enabling cloud synchronization & Google Sign-In
- **Groq API Key**: Optional, for enabling remote cloud AI scheduling (`https://console.groq.com/`)

---

## Quick Setup Guide

### 1. Clone & Install Dependencies

```bash
git clone https://github.com/your-username/nooktime.git
cd nooktime
flutter pub get
```

### 2. Configure Firebase (Optional)

1. Copy the sample Firebase configuration:
   ```bash
   cp android/app/google-services.json.example android/app/google-services.json
   ```
2. Alternatively, configure your own Firebase project using FlutterFire CLI:
   ```bash
   flutterfire configure
   ```

### 3. Placing Local AI GGUF Models (Optional)

For local offline LLM inference via GGUF models:
1. Create directory `assets/models/`
2. Place quantized GGUF model files (e.g., `qwen2.5-0.5b-instruct-q4_k_m.gguf`) into `assets/models/`

---

## Running the Application

### Launch with Groq Cloud AI Enabled

Pass your Groq API key at compile time using `--dart-define`:

```bash
flutter run --dart-define=GROQ_API_KEY=your_groq_api_key_here
```

### Launch in Debug Mode

```bash
flutter run
```

---

## Building Release Binaries

### Generate Split-ABI APKs (Recommended for Android)

Split-ABI builds significantly reduce APK file size per architecture (`arm64-v8a`, `armeabi-v7a`, `x86_64`):

```bash
flutter build apk --split-per-abi --dart-define=GROQ_API_KEY=your_groq_api_key_here
```

Output APKs will be located in:
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

## Running Tests & Code Quality Verification

Run static analysis and full test suite:

```bash
flutter analyze
flutter test
```

---

## License

Distributed under the MIT License. See `LICENSE` for details.
