# CueLink

A macOS companion app for [ProPresenter](https://renewedvision.com/propresenter/) that listens for MIDI notes and fires configurable HTTP webhooks. Trigger any web-enabled system from a ProPresenter macro.

## How It Works

```
ProPresenter Macro → MIDI Note (IAC Bus) → CueLink → HTTP Webhook
```

1. Set up a ProPresenter macro to send a MIDI note via the IAC Driver
2. CueLink listens for that note and fires your configured webhook
3. Your downstream system (OBS, lighting, Companion, etc.) responds

## Features

- **MIDI → Webhook mapping** — Map any MIDI note + channel to an HTTP endpoint
- **Multiple mappings** — One note can trigger multiple webhooks
- **MIDI Learn** — Click Learn, play a note, done
- **Custom payloads** — Default JSON payload or fully custom per mapping
- **Custom headers** — Add auth tokens or any headers per mapping
- **Activity log** — Timestamped log of all MIDI events and webhook responses
- **Auto-reconnect** — Automatically reconnects to MIDI devices
- **Retry on failure** — Optional retry (1-3 attempts) per mapping
- **Failure notifications** — macOS notification when a webhook fails
- **Test button** — Test any webhook without sending MIDI
- **Auto-updates** — Check for updates from GitHub releases via Sparkle
- **Menu bar app** — Lives in the menu bar, no dock clutter

## Requirements

- macOS 14 (Sonoma) or later
- IAC Driver enabled in Audio MIDI Setup (for ProPresenter communication)

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/engagetap/cuelink/releases)
2. Drag CueLink to your Applications folder
3. Launch CueLink — it appears in the menu bar

### IAC Driver Setup

1. Open **Audio MIDI Setup** (in /Applications/Utilities)
2. Go to **Window → Show MIDI Studio**
3. Double-click **IAC Driver**
4. Check **Device is online**
5. Ensure at least one bus exists (e.g., "Bus 1")

### ProPresenter Setup

1. In ProPresenter, go to **Preferences → MIDI**
2. Add the IAC Driver as a MIDI output
3. Create a **Macro** that sends a MIDI Note On message
4. In CueLink, select the IAC Driver as your MIDI input
5. Create a mapping and use **Learn** to capture the note

## Building from Source

```bash
cd CueLink
swift build -c release
```

### Build a release DMG

```bash
./scripts/build-release.sh
```

### Run tests

```bash
cd CueLink
swift test
```

## Configuration

Mappings are stored at `~/Library/Application Support/CueLink/mappings.json`.

Each mapping includes:
- **Name** — friendly label
- **MIDI Note + Channel** — which note triggers this mapping
- **Webhook URL** — HTTP/HTTPS endpoint
- **HTTP Method** — POST or PUT
- **Payload** — default JSON or custom
- **Headers** — optional key-value pairs
- **Retry Count** — 0-3 retries on failure
- **Enabled** — toggle without deleting

### Default Payload

```json
{
  "cue": "Mapping Name",
  "note": 60,
  "channel": 1,
  "timestamp": "2026-03-30T12:00:00.000Z"
}
```

## License

MIT
