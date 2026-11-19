# Releasing Lucid

## 1. Create your signing key (once)

Every version must be signed with the same key, or phones will refuse to
update. Make it once, back it up (with its passwords) somewhere safe, and
never commit it.

```bash
conda activate brethap                      # the environment has Java (keytool)
keytool -genkeypair -v -keystore ~/lucid-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias lucid   # asks for passwords
```

For signed builds on your laptop (optional), create `android/key.properties`
(ignored by git):

```properties
storeFile=/home/YOU/lucid-release.jks
storePassword=...
keyAlias=lucid
keyPassword=...
```

## 2. Let GitHub sign the APKs (once)

In the repository: Settings > Secrets and variables > Actions > New repository
secret. Add four secrets:

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | the output of `base64 -w0 ~/lucid-release.jks` |
| `KEYSTORE_PASSWORD` | the keystore password |
| `KEY_ALIAS` | `lucid` |
| `KEY_PASSWORD` | the key password |

## 3. Make a release

1. Raise the version in `pubspec.yaml`, e.g. `version: 1.0.1+2`. The number
   after `+` must go up by one every release.
2. Describe it in `fastlane/metadata/android/en-US/changelogs/<number>.txt`
   (the number after `+`; at most 500 characters).
3. Commit, tag and push:

```bash
git commit -am "Lucid 1.0.1"
git tag v1.0.1
git push origin main --tags
```

The **Release** workflow tests and builds the signed APK and attaches it,
with its SHA-256 checksum, to a new release on the Releases page. The
**Tests** workflow checks every push to `main`.

Screenshots for the store listings go in
`fastlane/metadata/android/en-US/images/phoneScreenshots/` (PNG or JPG,
named `1.jpg`, `2.jpg`, …; the README shows the same files). Crop off the
status bar and navigation bar. For good-looking ones, use the demo history in
`docs/demo/lucid-demo-sessions.csv` (943 made-up sessions, Sept 2023 to
Nov 2026, with scores, comments and measurements):

1. Sessions > ⋮ > Export, to keep your own sessions in a file.
2. Backup > Automatic backup off (so the demo doesn't replace your backup).
3. Sessions > ⋮ > Clear all, then Import the demo file.
4. Take the screenshots.
5. Clear all, Import your own file again, and turn automatic backup back on.

## 4. Getting into app stores

### IzzyOnDroid (quickest)

A repository that F-Droid clients (F-Droid, Droid-ify, Neo Store) can add. It
takes the APK from your GitHub releases, so your own signature is kept.
Request inclusion with a link to the repository at
<https://gitlab.com/IzzyOnDroid/repo> (open an issue). No fees, no ID.

### F-Droid (main repository)

No fees and no ID checks. F-Droid builds Lucid from the source code on its own
servers, so the app must be free software with no proprietary parts. Lucid
qualifies: the Wear OS code that kept Brethap's F-Droid build separate is
gone. F-Droid signs its builds with its own key, so people can't switch
between the F-Droid and GitHub versions without reinstalling, unless the
builds are made reproducible later.

1. Make the first release (step 3) so the `v1.0.0` tag exists.
2. Open a "Request for Packaging" at <https://gitlab.com/fdroid/rfp>, or fork
   <https://gitlab.com/fdroid/fdroiddata> and send a merge request adding
   `metadata/io.github.ignophi.lucid.yml`. A draft is in
   [docs/fdroid/io.github.ignophi.lucid.yml](fdroid/io.github.ignophi.lucid.yml).
3. Reviewers may ask for small changes; new tags are then picked up
   automatically.

### Google Play (possible, with paperwork)

A one-time fee (USD 25), identity verification, and for new personal accounts
a closed test with at least 12 testers for 14 days before the app can be
published. Play also needs an app bundle (`flutter build appbundle`), the
privacy policy ([PRIVACY.md](../PRIVACY.md)), a data safety form, and a short
explanation of why Lucid uses a foreground service (to keep the session timer
and breathing guide running with the screen off).

### Apple App Store

Not possible as is: Lucid is an Android app. An iPhone version would need
iOS-specific work, a Mac with Xcode and a paid Apple developer account
(USD 99 a year).
