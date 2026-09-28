# Kasarani Music Center — Teacher & Faculty Portal 🎼🎹

Official native Android faculty application for **Kasarani Music Center** (KMC).

---

## 📌 Overview
The **KMC Teacher Portal** (`KMC teacher Portal`) is a dedicated application developed specifically for Kasarani Music Center's faculty instructors, heads of department, and studio directors. 

> [!NOTE]
> This application is an internal faculty management app issued directly by the **School Director / Administrative Office** and is not distributed publicly via the student landing page.

---

## 🚀 Key Modules & Capabilities

1. **Brand Preloader & Splash Screen**:
   - Official KMC animated brand splash screen with the school logo, *"Passion to Profession"* motto, and live progress indicators ensuring complete faculty engine initialization.

2. **Faculty Live Dashboard**:
   - Real-time active studio session tracking with immediate one-tap attendance toggles (`Present`, `Excused`, `No Show`).
   - Quick KPI cards: Weekly teaching hours, Active students, Pending drill reviews, and Faculty compensation tracker.

3. **Weekly Studio Schedule & Timetables**:
   - Day-by-day studio schedule across all practice rooms (Studio 1 - 4, Sound Lab).
   - In-app lesson notes logging directly synced with student portfolios.

4. **Student Dossiers & Practice Reviews**:
   - Searchable faculty student roster with instrument levels and progress metrics.
   - Interactive practice drill evaluation rubric (Technique, Rhythm, Interpretation) with instructor feedback submission.

5. **Faculty Credentials & Compensation**:
   - Faculty ID ledger (`KMC-FAC-XXX`), certified instrument accreditations, and real-time monthly earnings summary (`KES`).

---

## 🛠️ Technical Specifications

- **Application Label**: `KMC teacher Portal`
- **Application ID / Package**: `ke.ac.kasaranimusic.kmc_teacher_app`
- **Framework**: Flutter 3.29+ / Dart 3.7+
- **Design System**: Material 3 Dark Palette (Deep Navy `#061C2D`, Studio Card `#0B2B43`, KMC Brand Neon `#35C400`, Sky Blue `#69C5E6`, Gold `#F0BD55`)
- **Android Target**: Android 15 (API 35), Min SDK: Android 7.0 (API 24)
- **Supported Architecture**: `arm64-v8a`, `armeabi-v7a`, `x86_64`

---

## 📦 Building and Release

### Debug Build
```powershell
flutter build apk --debug
```

### Release Build
```powershell
flutter build apk --release
```

---
*© 2026 Kasarani Music Center. All Rights Reserved. "Passion to Profession"*
