# Fidel — Flutter Android System Diagnostics Dashboard

A high-performance, real-time system diagnostics dashboard built with Flutter. Fidel provides detailed insights into your Android device's hardware and software, including CPU, memory, battery, thermal status, sensors, cameras, and more.

## ✨ Features

- **Real-time Monitoring**: Live updates for CPU usage, memory consumption, battery status, and thermal metrics.
- **Detailed Sections**:
  - **Device**: Model, manufacturer, Android version, build fingerprint, security patch level.
  - **CPU**: Core count, ABI, frequency (if available).
  - **Memory & Storage**: RAM usage, total/available storage, swap usage.
  - **Battery**: Health, level, status, technology, voltage, temperature.
  - **Thermal**: Thermal status, temperature zones/sensors.
  - **Sensors**: Real-time charts for accelerometer, gyroscope, magnetometer, light, pressure, etc.
  - **Cameras**: Detailed capabilities for front/back cameras (resolution, focal length, etc.).
  - **Codecs**: List of supported media codecs (encoders/decoders).
  - **Network**: SIM carrier info, Wi-Fi/Miracast support.
- **Data Export**: Export system snapshots or sensor logs to JSON or CSV.
- **Privacy Focused**: Redaction options for sensitive identifiers (serial numbers, MAC addresses) during export.
- **Localization**: Full support for English, Arabic (RTL), German, Spanish, and French.
- **Customization**: Dark/Light theme switching, unit preference settings (Celsius/Fahrenheit, Decimal/Binary data units).

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev/) (Hooks Riverpod)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Localization**: [GetX](https://pub.dev/packages/get) (for translations)
- **Asynchronous Programming**: [RxDart](https://pub.dev/packages/rxdart)
- **Platform Bridge**: Native Android (Kotlin) via MethodChannels and EventChannels.
- **Architecture**: Clean Architecture (Presentation, Application, Domain, Infrastructure).

## 🏗 Architecture

The project follows strict **Clean Architecture** principles to ensure scalability, testability, and maintainability.

- **Presentation Layer** (`lib/features/**/presentation`): UI widgets, pages, and view logic. Depends only on Application.
- **Application Layer** (`lib/application`): Service orchestration, state management (Providers). Depends on Domain.
- **Domain Layer** (`lib/domain`): Business entities, value objects, and repository interfaces. Pure Dart, no Flutter dependencies.
- **Infrastructure Layer** (`lib/infrastructure`): Data sources, repository implementations, mappers. Depends on Domain and Platform.
- **Platform Layer** (`lib/platform`): Native bridge definitions.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel, Dart >= 3.11)
- Android SDK (for building and running on Android)
- Android Studio or VS Code

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/fidel.git
    cd fidel
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    Connect an Android device or start an emulator.
    ```bash
    flutter run
    ```

### Building for Release

To generate an Android APK:

```bash
flutter build apk --release
```

## 🧪 Testing

The project includes unit and widget tests.

Run all tests:

```bash
flutter test
```

## 📄 License

This project is open-source and available under the MIT License.
