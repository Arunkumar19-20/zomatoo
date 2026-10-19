# Cravey

Cravey is a cross-platform Flutter application for food ordering and delivery, currently being refocused toward curated dish discovery with scheduled batch drops.

---

## Architecture & Tech Stack

- **Framework**: Flutter 3.44.x (Dart 3.12.x)
- **Platforms**: Android, iOS, Web, macOS, Linux, Windows
- **State Management**: `provider` (`SessionProvider`, `CartState`)
- **Networking**: `dio` (with token refresh single-flight `AuthInterceptor` and `ApiClient`)
- **Persistence**: `flutter_secure_storage` (auth tokens, refresh tokens, credentials) and `shared_preferences`
- **Mapping & Geolocation**: `flutter_map` with OpenStreetMap tile layer, `latlong2`
- **Payments**: `flutter_stripe` (Stripe PaymentSheet integration)
- **Styling**: Custom modern citrus palette (`AppTheme`, `CitrusHeader`, `ScaleTap`, `FadeInWrapper`, `ShimmerPlaceholder`, `GoogleFonts`)
- **API Specification**: [openapi.yaml](openapi.yaml) (OpenAPI 3.0 contract)

---

## Project Structure

```text
cravey/
├── lib/
│   ├── main.dart               # App entrypoint, session restoration & MultiProvider setup
│   ├── models/                 # Data transfer objects, mock models & CartState
│   │   ├── cart_state.dart     # Cart item state, calculations & checkout coordination
│   │   ├── food_item.dart      # UI FoodItem & Restaurant domain models
│   │   └── models.dart         # OpenAPI DTOs & response schemas
│   ├── screens/                # Flow and feature screens
│   │   ├── splash_screen.dart
│   │   ├── onboarding_screen.dart
│   │   ├── login_screen.dart
│   │   ├── create_account_screen.dart
│   │   ├── home_screen.dart
│   │   ├── restaurant_detail_screen.dart
│   │   ├── cart_screen.dart
│   │   ├── checkout_screen.dart
│   │   └── order_tracking_screen.dart
│   ├── services/               # REST API clients, auth & external integrations
│   │   ├── api_client.dart     # Central Dio singleton & platform host configuration
│   │   ├── auth_interceptor.dart # Single-flight token refresher & 401 handler
│   │   ├── auth_service.dart   # Login, registration, token refresh & secure storage
│   │   ├── cart_service.dart   # Server-side cart synchronization
│   │   ├── order_service.dart  # Order placement, status polling & history
│   │   ├── payment_service.dart# Stripe payment intent creation & verification
│   │   ├── restaurant_service.dart # Restaurant directory & menu retrieval
│   │   └── session_provider.dart # Auth session state ChangeNotifier
│   ├── theme/                  # Global color palettes, typography & theme definitions
│   └── widgets/                # Reusable animated and themed UI widgets
├── openapi.yaml                # OpenAPI 3.0 backend contract
└── test/                       # Unit and widget tests
```

---

## Prerequisites

1. **Flutter SDK**: `^3.44.0` (Dart `^3.12.0`)
   - Verify with: `flutter --version`
2. **Platform toolchains**:
   - **Android**: Android Studio with SDK command-line tools & Android Emulator / device
   - **iOS / macOS**: Xcode 15+ and CocoaPods (`pod install` in `ios/` or `macos/`)
   - **Web**: Google Chrome / Chromium

---

## Getting Started

### 1. Clone & Install Dependencies

```bash
git clone <repository_url>
cd cravey
flutter pub get
```

### 2. Environment Variables & Configuration

The app uses `String.fromEnvironment` for compile-time configuration:

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `API_BASE_URL` | _Empty (uses platform defaults)_ | Custom backend host URL override (e.g. `--dart-define=API_BASE_URL=https://api.cravey.com`) |
| `STRIPE_PUBLISHABLE_KEY` | `pk_test_placeholder` | Stripe publishable key for payment sheet initialization |

#### Backend Endpoint Configuration
`ApiClient.baseUrl` resolves the backend host dynamically:
- If `API_BASE_URL` is provided via `--dart-define=API_BASE_URL=http://...`, it takes precedence on all platforms.
- Otherwise, the app falls back to platform defaults:
  - **Web**: `http://localhost:8080`
  - **Android Emulator**: `http://10.0.2.2:8080`
  - **iOS Simulator / Desktop**: `http://localhost:8080`

Example:
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

#### OAuth 2.0 (Google Login)
- Handled via backend redirects through `/google-login?role=CUSTOMER` and `/oauth2/authorization/google`.
- Mobile uses an in-app `webview_flutter` interceptor.
- Web uses popup/redirect flow synchronized via `localStorage` and `web_oauth_storage_web.dart`.

---

## Running the Application

### Mobile (Android / iOS)
```bash
# Debug run with Stripe test key
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here
```

### Web
```bash
flutter run -d chrome --web-port=8080
```

---

## Running Tests & Static Analysis

```bash
# Run static analysis
dart analyze

# Run unit and widget test suite
flutter test
```

---

## API Specification
The full backend REST contract is defined in [openapi.yaml](openapi.yaml). It covers:
- `/auth/**` — Registration, authentication, token refresh, and logout
- `/api/restaurants/**` — Restaurant listings, menus, and ratings
- `/api/cart/**` — Remote cart synchronization
- `/api/orders/**` — Order creation, polling, and status tracking
- `/payment/**` — Stripe payment intent generation
