# Architecture

CopyStack is a small macOS menu bar app written in Swift (SwiftUI + AppKit, with the
Carbon Event Manager for global hotkeys). This document explains how the pieces fit
together and the reasoning behind the less-obvious decisions.

> Note on naming: the on-disk source folder is still named `Paste App/` and the
> `@main` type is `Paste_AppApp` for historical reasons, even though the product is
> "CopyStack". Renaming them is purely cosmetic and was left out to keep the diff small.

## The core idea

A traditional clipboard manager keeps a long, searchable *history*. CopyStack instead
models a *stack*: you collect a handful of items in order, then paste them back one at a
time, and each item is removed as it's pasted. That single decision shapes the whole
design — the app only needs to watch the clipboard briefly, hold a short ordered list,
and intercept paste.

## Components

The app is organized around a few focused singletons that coordinate state:

| Component | Responsibility |
|-----------|----------------|
| `ClipboardStorage` | The observable stack of items; add/remove rules, LIFO/FIFO order, trimming, copy sound. |
| `ClipboardMonitor` | Polls `NSPasteboard` while the stack window is open and turns each new copy into a typed item. |
| `HotkeyManager` | Registers the global hotkeys (Cmd+Shift+C, Cmd+V) and runs the sequential-paste logic. |
| `WindowManager` | Owns the floating stack window; showing it starts monitoring, hiding it stops monitoring. |
| `MonitoringManager` | Thin coordinator that starts/stops the shared monitor. |
| `ClipboardHelper` | Writes an item back onto the pasteboard (including a video's raw pasteboard data). |

`ClipboardItem` is the value type for one entry — an enum-tagged struct that holds text,
an image, a video (URL + thumbnail + raw pasteboard data), a file, or a web URL.

## Lifecycle

1. **Launch.** The app sets its activation policy to `.accessory` (menu bar only, no Dock
   icon). It registers global hotkeys but does **not** start monitoring the clipboard.
2. **Collect.** `Cmd+Shift+C` (or the menu) starts monitoring, simulates `Cmd+C` to copy
   the current selection, and shows the floating stack window after a short delay.
3. **Monitor.** While the window is open, `ClipboardMonitor` polls the pasteboard every
   50 ms and adds anything new to the stack.
4. **Paste.** While the stack has items, `Cmd+V` is intercepted globally: it pastes the
   next item, removes it, and loads the following item onto the clipboard. The hotkey is
   registered only while items exist — with an empty stack, `Cmd+V` is the untouched
   system paste, so the app can never break pasting elsewhere.
5. **Close.** Hiding the window stops monitoring and clears the stack.

Monitoring is deliberately **not** continuous — it only runs while the stack window is
open. This keeps CPU usage near zero at rest and avoids quietly recording everything the
user copies.

## Content-type detection

When the clipboard changes, the monitor walks a priority chain and stops at the first
match:

**video → image → file → URL → text**

The ordering matters:

- **Video before image.** Video files on the pasteboard often carry thumbnail/preview
  data that would otherwise be misread as an image. Videos are detected first and their
  *entire* raw pasteboard payload is captured, so they can be re-pasted byte-for-byte into
  apps (WhatsApp, Slack) that expect specific metadata. Videos copied from temporary
  locations are stashed in Application Support; leftovers are swept on the next launch
  (the stack always starts empty, so nothing there can still be referenced).
- **Image** detection tries several fallbacks (direct `NSImage`, image file URLs,
  TIFF/PNG/HEIC data, generic image types) because different source apps expose images
  differently.
- **File** matches non-image/non-video file URLs; **URL** matches only `http(s)` links;
  **text** is the final fallback.

Two robustness details:

- **De-duplication window.** Each captured item is hashed and remembered for 500 ms so a
  single copy that surfaces on the pasteboard in stages isn't added twice.
- **Async retries.** Some apps write clipboard data asynchronously and briefly leave the
  pasteboard empty. The monitor retries capture at 50/100/200/400 ms, bailing out if the
  clipboard changes again in the meantime.

## Paste order: LIFO vs FIFO

New items are inserted at index 0 (the top). Which item pastes *next* depends on the mode:

- **LIFO** — newest first (`items.first`). On overflow, the oldest items (at the end) are
  dropped.
- **FIFO** — oldest first (`items.last`). On overflow, the *second-newest* item is dropped
  instead, which preserves both the item the user just copied and the oldest items waiting
  to be pasted — so the highlighted "next" item never disappears unexpectedly.

The stack is capped at 50 items.

## Avoiding feedback loops

When CopyStack loads an item back onto the clipboard (to set up the next paste), that
write would itself look like a new copy and get re-captured. To prevent this, every
internal pasteboard write records the resulting `changeCount` via
`ClipboardMonitor.ignoreChange(withCount:)`, and the monitor skips that exact change.
Matching on the change count (rather than a "skip the next change" flag) means a user
copy that races in right after an internal write is still captured.

## Permissions

The only required permission is **Accessibility**, needed to simulate `Cmd+C` and
`Cmd+V` via `CGEvent`. It's checked inline at the point of use
(`AXIsProcessTrustedWithOptions`, which also shows the system grant prompt); if it's
missing, the paste is skipped *before* any stack item is consumed. The global hotkeys
themselves use the Carbon API and need no extra permission.

## Updates

`UpdateChecker` (in `AppDelegate.swift`) queries the GitHub Releases API for the configured
`owner/repo` on launch and every 24 hours, and offers a direct `.dmg` download when a newer
version is available. It has no third-party dependencies. Set the `repo` constant to your
own repository to enable it.
