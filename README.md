<img src="docs/images/lucid-header.png" align="left" width="136" hspace="10" alt="Lucid">

**A clean, free and private meditation app for Android.**

<img src="docs/images/icons/no_accounts.svg" width="18" align="top" alt=""> No account &nbsp;&nbsp;
<img src="docs/images/icons/block.svg" width="18" align="top" alt=""> No ads &nbsp;&nbsp;
<img src="docs/images/icons/visibility_off.svg" width="18" align="top" alt=""> No tracking &nbsp;&nbsp;
<img src="docs/images/icons/smartphone.svg" width="18" align="top" alt=""> Stays on your phone

<a href="https://github.com/Ignophi/lucid/releases/latest"><img src="https://img.shields.io/github/v/release/Ignophi/lucid?color=5B8FC9" alt="Latest release"></a>
<a href="https://github.com/Ignophi/lucid/actions/workflows/flutter.yml"><img src="https://github.com/Ignophi/lucid/actions/workflows/flutter.yml/badge.svg" alt="Tests"></a>
<img src="https://img.shields.io/badge/Android-7.0%2B-5B8FC9?logo=android&logoColor=white" alt="Android 7.0+">
<a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-5B8FC9" alt="License: GPL-3.0"></a>
<a href="https://github.com/jithware/brethap"><img src="https://img.shields.io/badge/based%20on-Brethap-8B949E" alt="Based on Brethap"></a>

<br clear="left">

## Features

<table>
  <tr>
    <th><a href="docs/FEATURES.md#breathe"><img src="docs/images/icons/air.svg" width="16" alt=""> Breathe</a></th>
    <th><a href="docs/FEATURES.md#programs"><img src="docs/images/icons/grid_view.svg" width="16" alt=""> Programs</a></th>
    <th><a href="docs/FEATURES.md#your-session"><img src="docs/images/icons/tune.svg" width="16" alt=""> Your session</a></th>
    <th><a href="docs/FEATURES.md#calendar"><img src="docs/images/icons/calendar_month.svg" width="16" alt=""> Calendar</a></th>
  </tr>
  <tr>
    <td><a href="docs/FEATURES.md#breathe"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1.jpg" width="170" alt="Breathing guide"></a></td>
    <td><a href="docs/FEATURES.md#programs"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2.jpg" width="170" alt="Breathing programs"></a></td>
    <td><a href="docs/FEATURES.md#your-session"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3.jpg" width="170" alt="Session settings"></a></td>
    <td><a href="docs/FEATURES.md#calendar"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/4.jpg" width="170" alt="Calendar"></a></td>
  </tr>
  <tr>
    <th><a href="docs/FEATURES.md#sessions"><img src="docs/images/icons/view_agenda.svg" width="16" alt=""> Sessions</a></th>
    <th><a href="docs/FEATURES.md#analytics"><img src="docs/images/icons/insights.svg" width="16" alt=""> Analytics</a></th>
    <th><a href="docs/FEATURES.md#year-overview"><img src="docs/images/icons/calendar_view_month.svg" width="16" alt=""> Year overview</a></th>
    <th><a href="docs/FEATURES.md#achievements"><img src="docs/images/icons/emoji_events.svg" width="16" alt=""> Achievements</a></th>
  </tr>
  <tr>
    <td><a href="docs/FEATURES.md#sessions"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/5.jpg" width="170" alt="Session log"></a></td>
    <td><a href="docs/FEATURES.md#analytics"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/6.jpg" width="170" alt="Analytics"></a></td>
    <td><a href="docs/FEATURES.md#year-overview"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/7.jpg" width="170" alt="Year overview"></a></td>
    <td><a href="docs/FEATURES.md#achievements"><img src="fastlane/metadata/android/en-US/images/phoneScreenshots/8.jpg" width="170" alt="Achievements"></a></td>
  </tr>
</table>

<a href="docs/FEATURES.md#measurements"><img src="docs/images/icons/sensors.svg" width="18" align="top" alt=""> Measurements</a> &nbsp;&nbsp;
<a href="docs/FEATURES.md#reminders"><img src="docs/images/icons/notifications.svg" width="18" align="top" alt=""> Reminders</a> &nbsp;&nbsp;
<a href="docs/FEATURES.md#backup"><img src="docs/images/icons/cloud_upload.svg" width="18" align="top" alt=""> Automatic backup</a> &nbsp;&nbsp;
<a href="docs/FEATURES.md#backup"><img src="docs/images/icons/import_export.svg" width="18" align="top" alt=""> Import and export</a>

<sub>Tap a feature for details.</sub>

## Download

<a href="https://github.com/Ignophi/lucid/releases/latest"><img src="https://img.shields.io/badge/Download-APK-5B8FC9?style=for-the-badge&logo=android&logoColor=white" height="34" alt="Download the APK"></a>

<sub>F-Droid and IzzyOnDroid are planned.</sub>

<details>
<summary><b>What's different from Brethap</b></summary>
<br>

Lucid is a fork of [Brethap](https://github.com/jithware/brethap) by Jithware.

- **New:** session reviews, analytics, measurements, achievements, reminders,
  automatic backup, the breathing wave, pause, your own programs.
- **Changed:** name, icon, app ID and design. The timer keeps running with the
  screen off. Presets and saved slots became programs. Hold tones are silent
  by default.
- **Removed:** Wear OS, web and iOS builds, translations (English only for
  now).

</details>

<details>
<summary><b>Build it yourself</b></summary>
<br>

Flutter 3.41.2 (see `.fvmrc`) and Java 17, with a phone connected:

```bash
flutter pub get          # download dependencies, generate texts
flutter test             # run the tests
flutter run --release    # build and install on the phone
```

To try it with three years of made-up sessions, import
[docs/demo/lucid-demo-sessions.csv](docs/demo/lucid-demo-sessions.csv)
(Sessions > ⋮ > Import). Signed releases: [docs/RELEASING.md](docs/RELEASING.md).

</details>

<details>
<summary><b>Privacy</b></summary>
<br>

Lucid sends nothing anywhere. Sessions, settings and measurements stay on your
phone and in the backups it saves to your Download folder. The microphone is
only used if you turn on sound measurements. See [PRIVACY.md](PRIVACY.md).

</details>

---

<sub>Based on [Brethap](https://github.com/jithware/brethap) by Jithware ·
Free software under the [GPL-3.0](LICENSE) · Ideas and bugs:
[Issues](https://github.com/Ignophi/lucid/issues)</sub>
