# DreoBar

A native macOS menu bar app for controlling [Dreo](https://www.dreo.com) smart fans, and a complete
reverse-engineered reference for Dreo's Bluetooth LE WiFi provisioning protocol.

Click the fan icon in the menu bar to see every device on your account and control it directly.
No Home Assistant, no iCUE, no Python bridge: the app talks to Dreo's cloud API and to the
hardware itself.

## Features

- Power, speed, oscillation and mode control for every device on your account
- Controls render from each device's server-supplied `controlsConf` schema, so new Dreo product
  types work without code changes
- Global hotkey to toggle the last-used device, works while the app is in the background
- `dreobar://toggle` URL scheme, so other automation tools can trigger it
- **Add a new fan to your WiFi over Bluetooth**, without the phone app
- Credentials live in the macOS Keychain, never on disk
- Optional launch at login

## Requirements

macOS 14 or later, Xcode 16 or later, and a Dreo account with email/password sign-in.
Accounts created through "Sign in with Google" or "Sign in with Apple" will not work, since the
app authenticates with `grant_type=email-password`.

## Build

The `.xcodeproj` is generated and gitignored, so generate it after cloning:

```bash
brew install xcodegen
xcodegen generate
open DreoBar.xcodeproj
```

Press Cmd-R to run. The app appears in the menu bar with no Dock icon.

```bash
xcodebuild test -project DreoBar.xcodeproj -scheme DreoBar   # 33 tests
scripts/demo.sh                                              # build and relaunch
```

## Protocol notes

Everything below was reverse-engineered from the official Android app and verified against real
hardware (a Pilot Max tower fan, `DR-HTF004S`). None of it is documented by the vendor, and as far
as I can tell the BLE half has not been published anywhere else.

### Cloud API

- REST host is `https://app-api-{region}.dreo-tech.com`. The region (`us` / `eu`) comes back from
  the login response, so a login may have to be retried once against the corrected host.
- The password is sent as a lowercase-hex MD5 digest, never plaintext.
- Live control runs over a WebSocket at `wss://wsb-{region}.dreo-tech.com/websocket`, with a
  literal text frame `"2"` as the keepalive every 15 seconds.
- Device state arrives under `data.mixed`, where each value is either a raw scalar or a
  `{"state": ..., "timestamp": ...}` wrapper. Some fields (`timeron`, `timeroff`) nest an object
  in `state`, so decoding is done key by key: one unrepresentable field must not discard the rest.

### Bluetooth LE provisioning

Dreo's own name for this is "HeFi". Messages are [CBOR](https://www.rfc-editor.org/rfc/rfc8949.html),
not protobuf or JSON.

| | |
|---|---|
| Service | `0000ffff-0000-1000-8000-00805f9b34fb` |
| Write characteristic | `00009b01-0000-1000-8000-00805f9b34fb` |
| Notify characteristic | `00009b02-0000-1000-8000-00805f9b34fb` |
| Advertised name | `DREO` + suffix, e.g. `DREOpf08s8E` |

Every message is `{"t": <type>, "v": <3-byte version>, "d": <payload>}`. The final `cw` write omits
`v`. Responses all arrive on the single notify characteristic and are demultiplexed by `t`.

| Type | Direction | Meaning |
|---|---|---|
| `st` | app to fan | Set the clock (`d.t` is a Unix timestamp in seconds) |
| `rd` / `ri` | both | Request and report device identity (serial, firmware, MAC, token) |
| `pd` | app to fan | Which account (`d.u`) and API host the fan should bind to |
| `rw` / `wl` | both | Request a WiFi scan, then results streamed in small batches |
| `cw` | both | Send credentials, then connection-progress reports |
| `cf` | fan to app | Final result, including a connectivity self-check |
| `ee` | fan to app | Error. Carries its code on `e` rather than nested under `d` |

**The message order matters.** The fan rejects a `cw` unless the session was opened the way the
official app opens it: `st` then `rd` then `pd`, and only then `rw` and `cw`. Sending
`st` then `rw` then `cw` gets refused with an `ee` error, even when the `cw` bytes are byte-for-byte
identical to a known-good capture. The account id for `pd` comes from the `userid` field of the
login response.

The WiFi password is sent in cleartext. BLE's own link-layer encryption is the only thing
protecting it, and there is no application-layer encryption in this protocol.

## Project layout

```
DreoBar/
├── App/           AppModel (single @Observable state owner), entry point
├── Models/        Data types, BLE/ (CBOR codec, message builders), API/, Errors/
├── Services/      Actor-isolated REST, WebSocket, and BLE pairing clients
├── Repositories/  Keychain and UserDefaults persistence
└── Views/         MenuBar/, Settings/, Setup/, AddDevice/
```

Swift 6 with strict concurrency. `@MainActor @Observable` for app state, `actor` for services,
constructor injection against protocols, and hand-written test doubles rather than a mocking
framework.

## Acknowledgements

The cloud half of the protocol was derived from [`JeffSteinbok/hass-dreo`](https://github.com/JeffSteinbok/hass-dreo),
which is where to look for a Home Assistant integration.

## Disclaimer

Not affiliated with, endorsed by, or supported by Dreo or Hesung Innovation. Built for
interoperability with hardware I own. Use at your own risk.

## License

MIT, see [LICENSE](LICENSE).
