---
name: android-re
user-invocable: false
description: >
  Android reverse engineering tools and workflows. Auto-activates when context involves
  APK files, DEX bytecode, smali, Android manifests, ADB, Android apps, Java decompilation,
  or Android-specific analysis.
---

# Android Reverse Engineering

This skill covers Android-specific RE tools available in the dev shell. For general-purpose tools (Ghidra, radare2, rizin, binwalk, Frida, YARA, mitmproxy, etc.), see `CLAUDE.md`.

## Obtaining an APK

| Tool | Command | Description |
|------|---------|-------------|
| apkeep | `apkeep -a com.example.app -d apk-pure .` | Download an APK or XAPK by package name; `-d` picks the source (`apk-pure`, `google-play`, `f-droid`) |

A split APK arrives as a `.xapk`, which is a zip of one base APK plus per-ABI and
per-density configs. Native libraries are in the config APK, not the base:
`unzip app.xapk -d xapk` then `unzip xapk/config.arm64_v8a.apk 'lib/*'`. The dex
is in the base APK. `google-play` needs credentials, `apk-pure` does not.

## APK Disassembly & Manipulation

| Tool | Command | Description |
|------|---------|-------------|
| apktool | `apktool d app.apk` | Decode APKs to smali + resources; rebuild with `apktool b` |
| APKEditor | `APKEditor` | Edit APK resources directly |
| apksigner | `apksigner sign --ks key.jks app.apk` | Sign and verify APK signatures (Android SDK) |
| apksigcopier | `apksigcopier` | Copy, extract, or patch APK signature blocks between files |
| APKiD | `apkid app.apk` | Identify compilers, packers, and obfuscators used to build an APK |
| aapt2 | `aapt2 dump badging app.apk` | Inspect APK metadata, resources, and manifest |
| bundletool | `bundletool build-apks --bundle=app.aab --output=out.apks` | Convert Android App Bundles (.aab) to APK sets |

## Java/DEX Decompilation

| Tool | Command | Description |
|------|---------|-------------|
| jadx | `jadx -d output/ app.apk` | Decompile DEX/APK directly to Java source (also has GUI: `jadx-gui`) |
| dex2jar | `d2j-dex2jar app.apk` | Convert DEX bytecode to a standard JAR for use with Java decompilers |
| bytecode-viewer | `bytecode-viewer` | GUI combining multiple decompilers (Procyon, CFR, FernFlower, etc.) |

## Android Dynamic Instrumentation

| Tool | Command | Description |
|------|---------|-------------|
| frida (Android) | `frida -U -f com.app.pkg -l script.js` | Inject JavaScript into running Android processes via USB |
| frida-ps | `frida-ps -U` | List processes on a USB-connected Android device |
| frida-trace | `frida-trace -U -f com.app.pkg -i "open*"` | Auto-generate handler stubs for traced functions on device |
| jnitrace | `jnitrace -l libnative.so com.app.pkg` | Trace all JNI API calls made by a native library at runtime |

## Android Static Analysis & Security Scanning

| Tool | Command | Description |
|------|---------|-------------|
| trueseeing | `trueseeing app.apk` | Scan APKs for vulnerabilities without decompilation |
| quark-engine | `quark -a app.apk -s` | Score and analyze APKs for malware behaviors |
| koodousfinder | `koodousfinder` | Search for and analyze Android applications |

## ADB & Device Interaction

| Tool | Command | Description |
|------|---------|-------------|
| adb | `adb devices` / `adb shell` / `adb pull` | Android Debug Bridge for device communication |
| fastboot | `fastboot flash` | Flash device partitions |
| scrcpy | `scrcpy` | Mirror and control an Android device screen over USB or TCP/IP |

## Android Image & OTA Tools

| Tool | Command | Description |
|------|---------|-------------|
| simg2img | `simg2img system.img system.raw.img` | Convert Android sparse images to raw ext4 images |
| sdat2img | `sdat2img system.transfer.list system.new.dat system.img` | Convert `.dat` sparse data files to ext4 images |
| payload-dumper-go | `payload-dumper-go payload.bin` | Extract partition images from `payload.bin` in Android OTA updates |
| imgpatchtools | `ApplyPatch` / `BlockImageUpdate` / `BlockImageVerify` / `imgdiff` | Apply and manipulate Android OTA incremental patches |

## Android Python Libraries

| Library | Import | Description |
|---------|--------|-------------|
| pyaxmlparser | `import pyaxmlparser` | Parse AndroidManifest.xml and extract app metadata |
| hermes-dec | `from hermes_dec import ...` | Decompile React Native Hermes bytecode |

## Android Node.js Tools

| Tool | Command | Description |
|------|---------|-------------|
| apk-mitm | `apk-mitm app.apk` | Patch APKs to bypass certificate pinning for MITM traffic interception |

## Workflows

### Full APK static analysis

```sh
# Identify build toolchain and protections
apkid app.apk

# Decode to smali + resources
apktool d app.apk -o tmp/apktool_com.example.app/

# Decompile to Java source
jadx -d tmp/jadx_com.example.app/ app.apk

# Scan for vulnerabilities
trueseeing app.apk

# Check for malware behaviors
quark -a app.apk -s
```

### Native library analysis (from APK)

```sh
# Extract the APK
unzip app.apk -d tmp/extracted_com.example.app/

# Analyze ARM .so with Ghidra
ghidra  # import tmp/extracted_com.example.app/lib/arm64-v8a/libnative.so

# Or use radare2/rizin for quick CLI analysis
r2 -A tmp/extracted_com.example.app/lib/arm64-v8a/libnative.so
```

### Runtime hooking with Frida (Android)

```sh
# List running processes on device
frida-ps -U

# Attach and trace
frida -U -f com.target.app -l hook.js --no-pause

# Trace JNI calls
jnitrace -l libnative.so com.target.app
```

### Extract OTA / system images

```sh
# From a payload.bin OTA
payload-dumper-go payload.bin

# Convert sparse to raw
simg2img system.img system.raw.img

# Mount and inspect
mkdir tmp/mnt && sudo mount -o loop system.raw.img tmp/mnt/
```

### Bypass certificate pinning

```sh
# Patch APK to disable pinning
apk-mitm app.apk

# Install patched APK and intercept traffic
adb install app-patched.apk
mitmproxy --listen-port 8080
```

## Notes

- `androguard` is excluded from the environment because its `dataset` dependency is currently marked broken in nixpkgs. `pyaxmlparser` is included as a lightweight alternative for Android XML parsing. Re-add androguard when the upstream issue is resolved.
- Frida requires a `frida-server` binary running on the target Android device (matching the frida-tools version).
- mitmproxy certificate must be installed on the target device for HTTPS interception. Push it via: `adb push ~/.mitmproxy/mitmproxy-ca-cert.cer /sdcard/`.
- bytecode-viewer and jadx-gui require a display server. On headless/WSL systems, use an X server (e.g., VcXsrv) or use the CLI equivalents.
