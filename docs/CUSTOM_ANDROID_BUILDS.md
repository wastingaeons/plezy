# Plezy Custom Android builds (Obtainium)

This fork publishes **raw, signed APK assets** for Android TV and Android phones.
The GitHub Actions workflow is `.github/workflows/custom-android-apk.yml`.

## Architecture and installation

| Device | Release asset |
| --- | --- |
| 32-bit ARM Chromecast / Android TV | `plezy-custom-armeabi-v7a.apk` |
| 64-bit ARM Chromecast / Android TV / Android phone | `plezy-custom-arm64-v8a.apk` |
| x86_64 emulator | `plezy-custom-x86_64.apk` |

The GitHub-built custom APK uses **`com.wastingaeons.plezy`**, distinct from
upstream's `com.edde746.plezy`. It installs alongside official Plezy, with
its own app data. Library logins, preferences, and companion-remote pairing
do **not** automatically transfer between the two.

This package ID must remain stable on all future custom releases. Keep the
signing keystore and alias stable too, or Android will reject upgrades.

## One-time signing setup (required)

> Never commit or share the keystore or its passwords. Back up the keystore
> and passwords somewhere safe outside GitHub; losing them prevents seamless
> upgrades of already-installed custom APKs.

On a machine with JDK 21 (`keytool`), create a signing key **once**:

```powershell
keytool -genkeypair -keystore plezy-custom-upload.jks -alias plezy-custom -keyalg RSA -keysize 3072 -validity 10000
```

Choose a strong keystore password when prompted. Use the same password for
the key if asked, or remember both separately.

In **GitHub → wastingaeons/plezy → Settings → Secrets and variables → Actions**,
create these four **repository secrets**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the exact `.jks` file bytes |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | `plezy-custom` |

To get the Base64 value from PowerShell (copies it to the clipboard):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.\plezy-custom-upload.jks').Path)) | Set-Clipboard
```

Paste the clipboard into GitHub's `ANDROID_KEYSTORE_BASE64` repository secret.
Do not paste it into an issue, chat, or tracked source file. Do not create a
fresh signing key for each build.

## Build without publishing

After this workflow is merged to `main`, go to
[Actions → Custom Android APKs](https://github.com/wastingaeons/plezy/actions/workflows/custom-android-apk.yml).
Choose **Run workflow**, leave **Publish release** unchecked, and start the run.
After success, download the `plezy-custom-android-apks` workflow artifact.

This artifact is for testing. Obtainium expects a **GitHub Release**, not a
temporary workflow artifact.

## Publish an Obtainium-ready release

From **Actions → Custom Android APKs**:

1. Choose the `main` branch.
2. Check **Publish release**.
3. Enter a **new** tag, for example `custom-v1.0.0`.
4. Run the workflow.

It compiles three ABI-specific release APKs with the same signing identity,
uploads them as workflow artifacts, and attaches the raw APKs to a GitHub
Release at
[releases](https://github.com/wastingaeons/plezy/releases).

Alternatively, pushing a tag named `custom-v*` builds and publishes a
release automatically. Only create release tags from reviewed code.

## Obtainium

In Obtainium, add `https://github.com/wastingaeons/plezy` as a GitHub source.
Select the asset containing **`armeabi-v7a`** on 32-bit Chromecast models,
or **`arm64-v8a`** on 64-bit models. The multiple-APK asset list makes the
architecture filter important.

Obtainium checks **GitHub Releases**. Publishing a new release with a higher
tag and Android versionCode lets it offer an APK update when installed with the
same package ID and signing key.

## Notes

- This workflow uses Flutter 3.47.1, matching upstream's current workflow.
- Builds increment Android `versionCode` from GitHub's workflow run number.
- The first successful release should be tested on a spare device before
  installing it on the regular Chromecast(s).
- GitHub-hosted runners are ephemeral; the signing key is restored securely from
  repository secrets for each build.
- The workflow is **not yet validated** until it has a successful GitHub
  Actions run. Some native dependencies may need additional build setup.
