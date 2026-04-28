# CrisisSync 🚨

<div align="center">

![CrisisSync](https://img.shields.io/badge/CrisisSync-Emergency%20Coordination-red?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=for-the-badge&logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-11.x-orange?style=for-the-badge&logo=firebase)
![Gemini AI](https://img.shields.io/badge/Gemini-1.5%20Flash-4285F4?style=for-the-badge&logo=google)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**Real-Time Hotel Emergency Coordination — From Detection to Alert in Under 3 Seconds**

[Features](#-features) • [Architecture](#-architecture) • [Tech Stack](#-tech-stack) • [Installation](#-installation) • [Usage](#-usage) • [Project Structure](#-project-structure) • [SDG Alignment](#-un-sdg-alignment)

</div>

---

## 📋 Overview

CrisisSync is a real-time hotel emergency coordination system powered by **Flutter Web**, **Firebase**, and **Gemini 1.5 Flash AI**. It unifies situational awareness across Guests, Staff, and Emergency Responders — triggering role-specific AI instructions within **3 seconds** of incident detection.

Whether it's a fire alarm, medical emergency, or security threat, CrisisSync ensures every stakeholder gets the right information in the right language at the right moment.

---

## ✨ Features

### 👤 **Guest View**
- Real-time emergency alerts with animated red flash display
- **Multi-language support**: English, Hindi, and Telugu
- **AI-powered translation** via Gemini for instant localization
- **Text-to-Speech (TTS)** audio playback of emergency instructions
- Live connection status indicator
- Safe/All-clear status when no incident is active

### 🧑‍💼 **Staff Dashboard**
- Severity-coded incident banners (Amber → Deep Orange → Dark Red)
- Tap-to-expand task assignment panel with role-specific Gemini instructions
- Embedded **Staff Accountability Screen** for real-time headcount
- Instant sign-out and role switching

### 🚒 **Emergency Responder Command Dashboard**
- Full incident details: type, severity, affected zones, and timestamps
- Interactive **floor map visualization** with affected zone highlighting
- Accountability tracking: check-in logs for all staff members
- AI-generated responder briefing with tactical instructions
- Incident report generation and download

### 🛠️ **Admin / Sensor Simulator**
- Accessible via `?admin=true` URL parameter
- **DEMO MODE**: auto-sequences a realistic fire detection scenario
- Configurable incident parameters: type, zone, severity level
- Triggers the full Cloud Function → Gemini → Realtime Database pipeline

### 🤖 **AI-Powered Coordination Engine**
- **Gemini Flash Detection**: classifies sensor input into incident type and severity
- **Parallel AI calls**: simultaneously generates tailored instructions for all 3 roles
- Role-aware prompt engineering — guests get calm evacuation steps, responders get tactical briefs
- Sub-3-second end-to-end latency from detection to alert delivery

---

## 🏗️ Architecture

```
[Sensor / Camera Input]
         │
         ▼
[Gemini 1.5 Flash — Incident Detection & Classification]
         │
         ▼
[Firestore  /incidents/{incidentId}]
         │
         ▼
[Firebase Cloud Function — onIncidentCreated trigger]
         │
         ▼
[Gemini × 3 Parallel Role-Instruction Calls]
    ┌────┴────┬──────────┐
    ▼         ▼          ▼
/alerts/  /alerts/   /alerts/
 guest     staff    responder
    │         │          │
    ▼         ▼          ▼
Guest PWA  Staff App  Command
(TTS +    (Tasks +   Dashboard
Translate) Headcount) (Map + Report)
```

All alerts are pushed via **Firebase Realtime Database** for instant cross-device synchronization.

---

## 🛠️ Tech Stack

### **Frontend**
- **Framework:** Flutter Web (Dart SDK ≥ 3.0)
- **State Management:** Provider 6.x
- **Text-to-Speech:** flutter_tts 4.x
- **UI:** Material Design 3 with dynamic severity theming

### **Backend & AI**
- **AI Model:** Google Gemini 1.5 Flash (`google_generative_ai ^0.4.7`)
- **Database:** Firebase Realtime Database (live sync) + Cloud Firestore (incident store)
- **Authentication:** Firebase Auth (Email/Password)
- **Serverless Logic:** Firebase Cloud Functions (Node.js)

### **Developer Tooling**
- **Linting:** flutter_lints 3.x
- **Testing:** flutter_test
- **Deployment:** Firebase Hosting

---

## 📦 Installation

### Prerequisites
- Flutter SDK ≥ 3.0 installed and on PATH
- A Firebase project with Auth, Firestore, and Realtime Database enabled
- Google Gemini API key (from [Google AI Studio](https://aistudio.google.com/))
- Firebase CLI installed (`npm install -g firebase-tools`)

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/Gupta-4388/CrisisSync.git
   cd CrisisSync
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**
   - Create a project at [Firebase Console](https://console.firebase.google.com/)
   - Enable **Authentication** (Email/Password provider)
   - Create a **Firestore** database
   - Enable **Realtime Database**
   - Update the `FirebaseOptions` in `lib/main.dart` with your project credentials

4. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

5. **Deploy Firestore security rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

6. **Run the app**
   ```bash
   # Development
   flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key

   # Production build
   flutter build web --dart-define=GEMINI_API_KEY=your_key
   firebase deploy --only hosting
   ```

> **Note:** The `GEMINI_API_KEY` is injected at build time via `--dart-define`. Never commit your key to source control. See `.env.example` for reference.

---

## 🎮 Usage

### Running the App

| Role | How to Access |
|---|---|
| **Guest** | Open the app → Select "Guest" on the Role Select screen |
| **Staff** | Open the app → Select "Staff" |
| **Responder** | Open the app → Select "Emergency Responder" |
| **Admin / Demo** | Append `?admin=true` to the URL (e.g. `https://your-app.web.app?admin=true`) |

### Triggering a Demo Incident

1. Open the app with `?admin=true`
2. Click **"DEMO MODE"** to auto-run a realistic fire scenario
3. Open three tabs simultaneously as Guest, Staff, and Responder
4. Watch alerts appear across all three views within seconds

---

## 📂 Project Structure

```
CrisisSync/
├── lib/
│   ├── main.dart                    # App entry point & Firebase init
│   ├── app_state.dart               # Global state (Provider)
│   ├── mock_data.dart               # Demo/mock incident data
│   ├── models/
│   │   ├── alert_model.dart         # Alert data model
│   │   ├── incident_model.dart      # Incident data model
│   │   └── guest_status_model.dart  # Guest check-in model
│   ├── screens/
│   │   ├── splash_screen.dart       # Launch screen
│   │   ├── role_select_screen.dart  # Role picker
│   │   ├── guest_screen.dart        # Guest alert view (TTS + translate)
│   │   ├── staff_screen.dart        # Staff dashboard
│   │   ├── staff_accountability_screen.dart  # Headcount tracker
│   │   ├── responder_screen.dart    # Command dashboard + floor map
│   │   └── admin_sensor_screen.dart # Sensor simulator / demo mode
│   ├── services/
│   │   ├── firebase_service.dart    # Firestore & Realtime DB helpers
│   │   └── gemini_service.dart      # Gemini AI integration
│   └── widgets/                     # Reusable UI components
├── functions/
│   ├── index.js                     # Cloud Function: onIncidentCreated
│   └── package.json
├── firestore.rules                  # Firestore security rules
├── firestore.indexes.json
├── firebase.json                    # Hosting & Functions config
├── pubspec.yaml
└── .env.example                     # Environment variable reference
```

---

## 🔥 Key Capabilities Explained

### Sub-3-Second Alert Pipeline
When an incident is written to `/incidents`, a Cloud Function fires immediately, makes three parallel calls to Gemini Flash — one per role — and writes results back to `/alerts/guest`, `/alerts/staff`, and `/alerts/responder` in Realtime Database. Flutter clients listening to these nodes receive the push instantly, with no polling required.

### Multi-Language TTS
The Guest screen uses Gemini to translate the English alert into Hindi or Telugu on demand, then passes the translated string to `flutter_tts` for spoken delivery. Language selection persists within the session and re-triggers translation automatically when the language is changed mid-incident.

### Role-Specific AI Instructions
Gemini receives a structured prompt per role:
- **Guests** — calm, simple evacuation steps in accessible language
- **Staff** — task checklists mapped to their department and floor
- **Responders** — incident type, affected zones, severity level, and tactical directives

### Admin Sensor Simulator
The simulator allows developers and hotel managers to test the entire pipeline without physical sensors. DEMO MODE auto-fills realistic incident parameters and sequences through the full detection → alert flow, making it ideal for staff training and system validation.

---

## 🔒 Security

- Firebase Auth protects all role-based screens
- Firestore security rules restrict read/write access
- Gemini API key injected via `--dart-define` (never stored in source)
- File-type and size validation on all uploads

---

## 🌐 Deployment

The app is configured for **Firebase Hosting**.

```bash
# Build and deploy everything
flutter build web --dart-define=GEMINI_API_KEY=your_key
firebase deploy
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines
- Follow Dart/Flutter best practices and linting rules (`flutter analyze`)
- Write meaningful commit messages
- Test all three role views before submitting
- Update documentation as needed

---

## 🌍 UN SDG Alignment

CrisisSync was designed in direct alignment with two United Nations Sustainable Development Goals:

| SDG | Goal | How CrisisSync Contributes |
|---|---|---|
| **SDG 3** | Good Health and Well-being | Dramatically reduces injury and casualty rates by delivering life-saving instructions within seconds of an emergency |
| **SDG 11** | Sustainable Cities and Communities | Strengthens the resilience of urban mega-structures and public spaces through intelligent, real-time safety infrastructure |

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 👥 Authors

- **Gupta-4388** — [GitHub Profile](https://github.com/Gupta-4388)

---

## 🙏 Acknowledgments

- Google Gemini 1.5 Flash for blazing-fast AI inference
- Firebase for a real-time, serverless backend that scales instantly
- The Flutter team for enabling beautiful cross-platform web apps from a single codebase
- All first responders and hotel safety professionals whose workflows inspired this system

---

## 📞 Support

For questions or support, please open an issue in the GitHub repository.

---

<div align="center">

**Made with ❤️ for safer buildings and faster response**

⭐ Star this repo if CrisisSync inspires you!

</div>
