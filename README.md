# 🚗🔍 AutoDentifyr: Damage Decoded

AutoDentifyr is a high-performance mobile application designed to automatically detect and estimate repair costs for vehicle damage using on-device computer vision, making it an essential tool for instant vehicle inspection and insurance estimation.

---

## 🌟 Features

- **Live Camera Inference**: Instant damage detection using your device's camera.
- **Photo Upload Analysis**: Analyze existing photos from your gallery for precise damage assessment.
- **Instant Price estimation**: Real-time overlays of estimated repair costs directly on detected areas. *(Note: Current estimates use static placeholder values per damage type)*
- **Unified Sharing Mechanism**: Share comprehensive "What You See Is What You Get" reports, including stats and annotated images, using a high-fidelity screenshot system.
- **Privacy First (On-Device)**: AI inference runs locally. No images are uploaded to external servers, ensuring data privacy and offline capability.
- **Dynamic Calibration**: Adjust confidence thresholds in real-time to fine-tune detection sensitivity.

---

## 🏗️ Project Structure

```text
lib/
├── core/                   # Core configurations
│   └── theme/              # Design System (AppPallete, AppTheme)
├── models/                 # Data structures and Enums
├── presentation/           # UI Layer (Feature-First structure)
│   ├── bloc/               # State Management (Auth BLoC)
│   ├── controllers/        # Business Logic (Camera Inference Controller)
│   ├── screens/            # Main Screens (Live Mode, Upload Mode, Login)
│   └── widgets/            # Reusable Components (Overlays, Sliders, Controls)
├── services/               # External Services (Firebase Auth, Model Manager)
└── main.dart               # Entry point
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable)
- Physical Android or iOS device (Camera required for Live Mode)

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/your-repo/autodentifyr
    cd autodentifyr
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**:
    This project requires Firebase for authentication. You must provide your own configuration files:
    - **Android**: Place `google-services.json` in `android/app/`.
    - **iOS**: Place `GoogleService-Info.plist` in `ios/Runner/`.
    - **Dart**: Create `lib/firebase_options.dart` (see `lib/firebase_options.example.dart` for reference).

4.  **Model Setup**:
    > **Important**: The ML models are not included in this repository. You must manually add your model(s) and rename it to `best`:

    - **Android**: Place your `best.tflite` model in `android/app/src/main/assets`.
    - **iOS**: Open `ios/Runner.xcworkspace` in Xcode, then drag and drop your `best.mlpackage` folder into the `Runner` folder.

5.  **Run the app**:
    ```bash
    flutter run
    ```

## 🗺️ Roadmap & Future Work

We are actively working to improve the accuracy and utility of AutoDentifyr. Future updates will focus on:

-   **Context-Aware Pricing**: Moving beyond static estimates to dynamic pricing models.
-   **Make & Model Capture**: Capturing vehicle make and model to tailor repair costs to specific manufacturers and models.
-   **Severity Reasoning**: Analyzing the damage to provide nuanced severity-based cost adjustments.

## 🤝 Contributing

We welcome contributions to AutoDentifyr!

-   🐛 **Bug Reports**: Found an issue? Create an issue with details.
-   💡 **Feature Requests**: Have ideas for improvements? We'd love to hear them.
-   🔧 **Pull Requests**: Ready to contribute code? Submit a pull request.

---
*Disclaimer: Price estimates provided by the app are static placeholders for demonstration purposes and should be verified by a certified automotive professional.*
