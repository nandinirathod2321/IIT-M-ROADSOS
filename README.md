<div align="center">

# 🚑 RoadSOS

### AI-Powered Road Safety & Emergency Response Platform

*Reducing emergency response time. Saving lives during the Golden Hour.*

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com)
[![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)
[![Gemini](https://img.shields.io/badge/Gemini_AI-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://deepmind.google/technologies/gemini/)

*Developed for the **Madras AI Road Safety Hackathon 2026***

</div>

---

## 📌 Overview

Road accidents remain one of the leading causes of fatalities worldwide. Delays during the **Golden Hour**, lack of accessible medical information, and difficulty contacting emergency services often worsen outcomes.

**Sanjeevani** is a unified emergency response ecosystem that addresses these challenges by combining:

- One-touch SOS activation
- AI-powered crash detection
- QR-based Medical ID for first responders
- Real-time hospital and emergency service navigation
- Gemini-powered first-aid guidance

---

## ✨ Key Features

### 🚨 Emergency SOS System
- One-touch SOS activation with automatic emergency workflow
- GPS location acquisition and real-time sharing
- Instant emergency contact notifications

### 📍 Nearby Emergency Services
- Locates nearby hospitals, police stations, and towing services
- Real-time navigation via Google Maps integration

### 🩺 Medical ID System
- QR-code-based medical profile accessible to first responders
- Stores blood group, allergies, medications, and emergency contacts
- Works without requiring app installation by the responder

### 🤖 AI Emergency Assistant
- Gemini-powered conversational emergency guidance
- Step-by-step first-aid recommendations
- Context-aware support during active emergencies

### 📱 Crash Detection
- Accelerometer and gyroscope-based impact detection
- Automatic SOS activation with a manual-override countdown
- Background monitoring while driving

### 🌐 Offline Emergency Support
- Cached hospital and emergency service information
- Offline-first local data persistence
- Reliable in low-network or no-network environments

---

## 🔄 Emergency Workflow

```
Crash Detected / SOS Activated
            │
            ▼
    Emergency Countdown
    (manual cancel window)
            │
            ▼
      Location Acquired
            │
            ▼
  Emergency Contacts Notified
            │
            ▼
  Nearest Hospital Identified
            │
            ▼
  Google Maps Navigation Launched
            │
            ▼
  Medical Information Available via QR
```

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter, Dart |
| **Backend** | FastAPI (Python) |
| **Database** | SQLite, Shared Preferences |
| **AI** | Gemini API |
| **Maps & Geocoding** | OpenStreetMap, Nominatim, Google Maps Navigation |

### Flutter Packages

| Package | Purpose |
|---|---|
| `geolocator` | GPS location services |
| `sensors_plus` | Accelerometer & gyroscope access |
| `flutter_dotenv` | Environment variable management |
| `shared_preferences` | Local key-value storage |
| `sqflite` | On-device SQLite database |
| `go_router` | Declarative navigation |
| `flutter_bloc` | State management |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable)
- Dart SDK (bundled with Flutter)
- A valid [Gemini API Key](https://aistudio.google.com/app/apikey)
- Android or iOS device / emulator

### Installation

**1. Clone the repository**

```bash
git clone <repository-url>
cd IIT-M-ROADSOS
```

**2. Install dependencies**

```bash
flutter pub get
```

**3. Configure environment variables**

Create a `.env` file in the root of the mobile project:

```env
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

> ⚠️ Never commit your `.env` file. Ensure it is listed in `.gitignore`.

**4. Run the application**

```bash
flutter run
```

---

## 📂 Project Structure

```
IIT-M-ROADSOS/
├── lib/
│   ├── features/
│   │   ├── sos/              # SOS activation & workflow
│   │   ├── crash_detection/  # Sensor-based crash detection
│   │   ├── medical_id/       # QR Medical Profile
│   │   ├── navigation/       # Hospital & emergency services
│   │   └── ai_assistant/     # Gemini AI integration
│   ├── core/                 # Shared utilities, models, services
│   └── main.dart
├── backend/                  # FastAPI backend
├── assets/                   # Images, icons, fonts
├── .env                      # Environment variables (do not commit)
└── pubspec.yaml
```

---

## 🎯 Project Objectives

- ⚡ Improve emergency response efficiency
- ⏱️ Reduce critical delays during the Golden Hour
- 🏥 Provide instant access to medical information for first responders
- 📡 Enable rapid communication during road emergencies
- 🛡️ Improve road safety through technology-driven solutions

---

## 🔮 Future Enhancements

- [ ] Ambulance Network Integration
- [ ] Government Emergency Service Integration
- [ ] Advanced AI Crash Prediction & Prevention
- [ ] Wearable Device Support (smartwatches)
- [ ] Multilingual Voice Assistance
- [ ] Real-Time Responder Network
- [ ] Telematics & Insurance Integration

---

## 👥 Team

Developed by **Team RoadSOS** for the **Madras AI Road Safety Hackathon 2026**.

---

## 📄 License

This project is developed for **educational, research, and hackathon purposes**.  
All rights reserved by the respective contributors.

---

<div align="center">

*Built with ❤️ to make roads safer and emergencies faster.*

</div>
