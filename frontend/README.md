# Frontend — Flutter (iOS, Android, Web)

Created in Phase 0. Theme tokens and two starter widgets already live in `lib/core/`.

## Create the project around the existing files

```bash
cd frontend
flutter create --org lk.payandsave --project-name pay_and_save --platforms android,ios,web .
flutter pub add flutter_riverpod go_router drift sqlite3_flutter_libs dio google_fonts intl uuid socket_io_client
flutter pub add flutter_localizations --sdk=flutter
flutter pub add dev:drift_dev dev:build_runner
```

Bundle `Noto Sans Sinhala` and `Noto Sans Tamil` under `assets/fonts/` and declare them in `pubspec.yaml` with exactly those family names (see `lib/core/theme/app_typography.dart`).

## Planned structure

```
lib/
├── core/        theme, widgets, router, api client, l10n, offline db (drift)
├── features/
│   ├── auth/        welcome, phone login, OTP, your data
│   ├── home/        member home, circle switcher
│   ├── contribute/  record payment, recorded, saved offline
│   ├── history/     history, verified record, savings, export
│   ├── turn_order/
│   ├── reminders/   reminders, notifications
│   ├── organizer/   create circle, invite, turn setup, cycle details, verify, close
│   └── community/   dashboard, circles, health, disputes, consent, evidence, privacy
└── l10n/        app_en.arb, app_si.arb, app_ta.arb
```
