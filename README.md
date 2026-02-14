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

## Requirements

- macOS 13+
- Swift 6.0+
