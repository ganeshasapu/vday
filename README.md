# Mwah

A macOS menu bar app that sends floating heart animations across the screen.

## Build

```bash
bash scripts/build.sh
```

This builds a release binary and packages it into `build/Mwah.app`.

## Run

```bash
open build/Mwah.app
```

### Debug mode

```bash
open build/Mwah.app --args --debug
```

### Run a second instance (for testing)

```bash
open -n build/Mwah.app --args --debug
```

### Run with large heart bursts

```bash
MWAH_HEART_BURST_COUNT=3000 build/Mwah.app/Contents/MacOS/Mwah --debug
```

`MWAH_HEART_BURST_COUNT` is clamped to `1...10000`.

## Auto-Updates Setup (One-Time)

The app uses [Sparkle](https://github.com/sparkle-project/Sparkle) for over-the-air updates signed with Ed25519.

### 1. Generate signing keys

Download Sparkle tools from the [Sparkle releases page](https://github.com/sparkle-project/Sparkle/releases), extract, and run:

```bash
./bin/generate_keys
```

This stores the private key in your macOS Keychain and prints the public key.

### 2. Add the public key to Info.plist

Replace `PASTE_YOUR_ED25519_PUBLIC_KEY_HERE` in `Info.plist` with the public key from above.

### 3. Back up the private key

```bash
./bin/generate_keys -x
```

Save this somewhere safe. If you lose it, existing users won't be able to verify future updates.

## Releasing a New Version

### 1. Build the release

```bash
./scripts/release.sh 1.2.0
```

This builds the app, stamps the version, creates `build/Mwah.zip`, and signs it. Copy the EdDSA signature from the output.

### 2. Update appcast.xml

Add a new `<item>` block at the top of the `<channel>` in `appcast.xml`:

```xml
<item>
    <title>Version 1.2.0</title>
    <description><![CDATA[
        <h2>What's New</h2>
        <ul>
            <li>Your changes here</li>
        </ul>
    ]]></description>
    <pubDate>Sat, 15 Feb 2026 12:00:00 +0000</pubDate>
    <sparkle:version>1.2.0</sparkle:version>
    <sparkle:shortVersionString>1.2.0</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <enclosure
        url="https://github.com/ganeshasapu/vday/releases/download/v1.2.0/Mwah.zip"
        length="FILE_SIZE_IN_BYTES"
        type="application/octet-stream"
        sparkle:edSignature="PASTE_SIGNATURE_HERE"
    />
</item>
```

Fill in `length` (file size printed by the release script) and `sparkle:edSignature` from the build output.

### 3. Commit and push

```bash
git add appcast.xml
git commit -m "Release v1.2.0"
git push
```

### 4. Create a GitHub release

```bash
gh release create v1.2.0 build/Mwah.zip --title "Mwah v1.2.0" --notes "Release notes here"
```

Existing users will get the update automatically (checks daily) or by clicking "Check for Updates..." in the menu.

## Requirements

- macOS 13+
- Swift 6.0+
