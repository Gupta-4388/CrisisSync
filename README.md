# CrisisSync

CrisisSync is a real-time hotel emergency coordination system powered by Flutter Web, Firebase, and Gemini Flash AI. It unifies situational awareness across Guests, Staff, and Emergency Responders within 3 seconds of incident detection.

## Architecture

[Sensor/Camera] → [Gemini Flash Detection] → [Firestore /incidents]
                                                       ↓
                                          [Cloud Function triggers]
                                                       ↓
                              [Gemini × 3 parallel role instruction calls]
                                    ↓              ↓              ↓
                             [/alerts/guest] [/alerts/staff] [/alerts/responder]
                                    ↓              ↓              ↓
                            [Guest PWA]      [Staff App]    [Command Dashboard]
                            [Hindi/TTS]    [Accountability]  [Floor Map + Report]

## Tech Stack
- Frontend: Flutter Web
- Backend: Firebase Realtime Database & Firestore
- AI Logic: Gemini 1.5 Flash via Firebase Cloud Functions
- State Management: Provider

## Setup Instructions
1. Clone the repository and run `flutter pub get`.
2. Connect a Firebase project (`firebase init`) and enable Auth, Firestore, and Realtime Database.
3. Deploy the Cloud Functions from the `/functions` directory: `firebase deploy --only functions`.
4. Create a local `.env` file based on `.env.example` or ensure you have your key ready.
5. Boot the web app or build it using the `--dart-define` flag:
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your_key
   flutter build web --dart-define=GEMINI_API_KEY=your_key
   ```

## Demo Scenario Walkthrough
Use the `?admin=true` URL parameter to access the Sensor Simulator. Trigger the "DEMO MODE" to automatically sequence a fire detection, Cloud Function response formatting in multiple languages, and Realtime Database live-syncing across three simultaneous user tabs. 

## UN SDG Alignment
Designed in alignment with **SDG 3 (Good Health and Well-being)** and **SDG 11 (Sustainable Cities and Communities)** to dramatically reduce casualties in urban mega-structures.
