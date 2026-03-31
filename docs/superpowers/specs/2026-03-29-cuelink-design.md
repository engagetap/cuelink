# CueLink Design Spec

**Date:** 2026-03-29
**Status:** Draft

## Overview

CueLink is a macOS companion app for ProPresenter (v21+). It listens for MIDI notes sent from ProPresenter macros over the IAC bus and fires configurable HTTP webhooks in response. It provides a simple, user-friendly interface for mapping MIDI notes to webhook destinations.

## Architecture

- **Single-process SwiftUI menu bar app** (Approach A)
- **Tech stack:** Swift, SwiftUI, CoreMIDI, URLSession
- **Target:** macOS 14+ (Sonoma)
- **No external dependencies** — all system frameworks
- **Distribution:** Xcode project, single target, Developer ID signing (or unsigned for personal use)

## App Structure & Lifecycle

CueLink runs as a **menu bar app** with a status icon. Clicking the icon shows a popover with:

- Connection status (which MIDI device is active)
- Quick view of recent activity
- Buttons to open the full Settings window or quit

The **Settings window** is a standard macOS window with sections for:

1. **MIDI Device** — select input device
2. **Mappings** — list of MIDI note to webhook mappings
3. **Activity Log** — timestamped history

Launch at login is optional and configurable.

## MIDI Handling

- Uses **CoreMIDI** to enumerate available MIDI input sources
- User selects a specific MIDI device/source from a dropdown (e.g., "IAC Driver Bus 1")
- App creates a MIDI input port and connects to the selected source
- Listens for **Note On** messages only (Note Off ignored)
- **Learn mode:** User clicks a "Learn" button next to a mapping. The app enters learn mode and captures the next incoming MIDI note (channel + note number), then auto-populates the mapping. Learn mode stays active until a note is received or the user cancels manually. No timeout. While in learn mode, the Learn button pulses/animates to provide clear visual feedback that the app is waiting for input.
- If the selected MIDI device disconnects, the app shows a warning in the menu bar popover and polls every 5 seconds for reconnection

## Webhook Mappings

Each mapping consists of:

- **Name** — user-friendly label (e.g., "Start Stream", "Change Scene")
- **MIDI Note** — channel + note number (set via Learn or manual entry)
- **Webhook URL** — the destination HTTP endpoint
- **Payload mode** — toggle between Default and Custom
  - **Default:** sends `{"cue": "<mapping name>", "note": <note number>, "channel": <channel>, "timestamp": "<ISO 8601>"}`
  - **Custom:** user provides a full JSON body in a text editor
- **HTTP Method** — POST (default), with option for PUT
- **Headers** — optional key-value pairs (e.g., for auth tokens)
- **Enabled/Disabled toggle** — deactivate a mapping without deleting it

**Duplicate MIDI notes are allowed.** A single MIDI note can trigger multiple mappings — all matching enabled mappings fire their webhooks.

Mappings are displayed as a table/list in the Settings window. Users can add, edit, duplicate, and delete mappings.

## Activity Log

- Scrollable table in the Settings window
- Each entry shows:
  - **Timestamp** — system time, formatted as `HH:mm:ss.SSS` with date grouping
  - **Direction** — MIDI In or Webhook Out
  - **Details** — for MIDI: note + channel; for Webhook: URL + HTTP status code
  - **Status** — success (green dot), failure (red dot), or unmatched MIDI note (grey dot)
- Kept in memory only — clears on app restart
- Capped at 500 most recent entries
- "Clear Log" button to reset manually

## Persistence & Data Model

### App Settings (UserDefaults)

- Selected MIDI device identifier
- Launch at login preference
- Window positions

### Mappings (`~/Library/Application Support/CueLink/mappings.json`)

Array of mapping objects, read on launch, written on every change.

### Data Model (Swift structs, Codable)

```swift
struct CueLinkMapping: Codable, Identifiable {
    var id: UUID
    var name: String
    var midiNote: UInt8
    var midiChannel: UInt8
    var webhookURL: String
    var payloadMode: PayloadMode // .default or .custom
    var customPayload: String?
    var httpMethod: HTTPMethod // .post or .put
    var headers: [String: String]
    var isEnabled: Bool
}

enum PayloadMode: String, Codable {
    case `default`
    case custom
}

enum HTTPMethod: String, Codable {
    case post = "POST"
    case put = "PUT"
}
```

## Error Handling

- **MIDI device not found / disconnected:** Status indicator turns red in menu bar popover. App polls for device reappearance every 5 seconds and auto-reconnects.
- **Webhook failure (network error, non-2xx):** Logged in activity log with red status. No retry — fires once per trigger.
- **Duplicate MIDI note mapping:** Allowed. All matching enabled mappings fire.
- **Invalid webhook URL:** Validated on save — must be valid HTTP/HTTPS URL.
- **Invalid custom JSON payload:** Validated on save — must parse as valid JSON.

## Communication Flow

```
ProPresenter Macro
    -> MIDI Note On (IAC Bus)
        -> CueLink (CoreMIDI listener)
            -> Match against enabled mappings
                -> HTTP POST/PUT to webhook URL(s)
                    -> Log result in Activity Log
```
