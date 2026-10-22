# 🚀 CareerPilot

**Your AI-Powered Career Guidance Platform**

CareerPilot is a Flutter-based career guidance application designed to help users improve their resumes, explore career opportunities, plan their professional growth, and prepare for interviews.

## ✨ Features

- 🔐 **User Authentication** — Secure sign-up and login using Firebase Authentication, including email verification.
- 📄 **AI Resume Analysis** — Analyze resumes using Google's Gemini AI to identify strengths, weaknesses, skills, and areas for improvement.
- 🎯 **Career Recommendations** — Discover career paths and opportunities relevant to your skills, interests, and career goals.
- 💼 **Job Discovery** — Explore relevant job opportunities and access job application links when a job data source is configured.
- 🗺️ **Personalized Career Roadmap** — Get a structured plan to develop skills and work toward your career goals.
- 🎤 **AI Mock Interviews** — Practice interview questions and receive feedback to improve your interview performance.
- 👤 **User Profile** — Manage profile information and career preferences.
- ☁️ **Cloud Firestore** — Store and retrieve user information and supported application data.

*Note: Feature availability depends on implementation and configuration. External job discovery requires a suitable job data source.*

## 🛠️ Technologies Used

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform user interface |
| Dart | Application development |
| Firebase Authentication | User registration and login |
| Cloud Firestore | Cloud database |
| Google Gemini API | AI-powered career features |
| Visual Studio Code | Development environment |
| Git and GitHub | Version control and collaboration |

## 📁 Project Structure

```text
Career_pilot/
├── android/
├── assets/
│   └── images/
│       └── careerpilot_logo.jpeg
├── lib/
│   ├── config/
│   │   └── gemini_config.dart
│   ├── models/
│   │   ├── career_path_profile.dart
│   │   ├── job_model.dart
│   │   ├── mock_interview_model.dart
│   │   ├── notification_model.dart
│   │   ├── resume_analysis_model.dart
│   │   ├── roadmap_model.dart
│   │   └── user_model.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── email_verification_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── careers/
│   │   │   └── careers_screen.dart
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart
│   │   ├── interview/
│   │   │   ├── interview_hub_screen.dart
│   │   │   ├── interview_result_screen.dart
│   │   │   ├── interview_session_screen.dart
│   │   │   └── interview_setup_screen.dart
│   │   ├── notifications/
│   │   │   └── notifications_screen.dart
│   │   ├── profile/
│   │   │   └── profile_screen.dart
│   │   ├── resume/
│   │   │   ├── resume_analysis_screen.dart
│   │   │   └── upload_resume_screen.dart
│   │   ├── roadmap/
│   │   │   ├── career_path_form_screen.dart
│   │   │   └── roadmap_screen.dart
│   │   └── splash/
│   │       └── splash_screen.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── gemini_service.dart
│   │   ├── mock_interview_service.dart
│   │   ├── notification_service.dart
│   │   ├── resume_extractor_service.dart
│   │   ├── roadmap_service.dart
│   │   ├── storage_service.dart
│   │   └── voice_assistant_service.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── widgets/
│   │   ├── custom_button.dart
│   │   ├── custom_text_field.dart
│   │   ├── feature_card.dart
│   │   └── job_card.dart
│   ├── firebase_options.dart
│   └── main.dart
├── test/
│   ├── career_goal_test.dart
│   ├── gemini_diagnostic_test.dart
│   ├── gemini_service_retry_test.dart
│   ├── job_discovery_test.dart
│   ├── mock_interview_test.dart
│   ├── notification_test.dart
│   ├── periodic_notification_test.dart
│   ├── resume_analysis_test.dart
│   ├── roadmap_test.dart
│   ├── voice_assistant_test.dart
│   └── widget_test.dart
├── web/
│   ├── icons/
│   ├── index.html
│   └── manifest.json
├── .firebaserc
├── .gitignore
├── .metadata
├── analysis_options.yaml
├── firebase.json
├── firestore.rules
├── storage.rules
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

*The structure above is illustrative. Your actual folders may differ depending on the current implementation.*

## ⚙️ Getting Started

### Prerequisites

Install the following:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-dart)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Git](https://git-scm.com/)
- A Firebase project configured for the application
- A Gemini API key for AI features

### Installation

**1. Clone the repository**

```bash
git clone https://github.com/YOUR_USERNAME/Career_pilot.git
```

Replace `YOUR_USERNAME` with your GitHub username.

**2. Open the project**

```bash
cd Career_pilot
```

**3. Install dependencies**

```bash
flutter pub get
```

**4. Configure Firebase**

Use your existing Firebase project and configure the required platforms. Follow the [FlutterFire setup guide](https://firebase.google.com/docs/flutter/setup).

Do not upload private service-account credentials or other secrets to GitHub.

**5. Configure the Gemini API key**

For local development, if the application reads the key through `String.fromEnvironment('GEMINI_API_KEY')`, run:

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=YOUR_API_KEY
```

Replace `YOUR_API_KEY` locally with your own key. Never commit real API keys to the repository.

For production deployments, use a secure backend to protect API credentials.

## ▶️ Running the Application

To run on Chrome:

```bash
flutter run -d chrome
```

If Gemini requires a compile-time API key, use the configured `--dart-define` command shown above.

To run on a connected Android device:

```bash
flutter devices
flutter run -d YOUR_DEVICE_ID
```

Replace `YOUR_DEVICE_ID` with the device ID reported by Flutter.

## 🧪 Testing

Check code quality:

```bash
flutter analyze
```

Run automated tests:

```bash
flutter test
```

Test authentication, resume uploads, AI responses, Firestore persistence, and navigation in the running application as well.

## 📱 Building for Android

When the application is ready for release, run:

```bash
flutter build apk --release
```

If the Gemini configuration requires a compile-time key, supply it to the release build using the appropriate `--dart-define` configuration. Remember that embedding a key in an APK does not keep it secret.

The generated APK is normally located at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 🔒 Security

- Never commit API keys or passwords.
- Configure Firebase Authentication and Firestore security rules appropriately.
- Restrict user data access to authorized users.
- Keep production AI credentials on a secure backend.
- Validate uploaded file types and file sizes.
- Avoid storing unnecessary sensitive information.

## 🎯 Project Objective

CareerPilot aims to make career planning more accessible by bringing resume feedback, career exploration, personalized learning guidance, and interview preparation together in one application.

## 👥 Contributors

Add your team members' names and their contributions here.

## 📄 License

No license has been specified yet. Add a license if required by your project or institution.
