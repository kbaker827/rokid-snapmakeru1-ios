# Rokid Snapmaker U1


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that polls your [Snapmaker U1](https://snapmaker.com) over the local network and streams live print status to Rokid AR glasses.

## How it works

```
Snapmaker U1  ──HTTP :8080──▶  iPhone (RokidSnapmaker)  ──Bluetooth/RokidSDK──▶ Rokid Glasses
```

No cloud required. The app talks directly to the machine's built-in HTTP API on your local Wi-Fi.

## What's displayed on the glasses

Three selectable formats:

**Compact** (single line):
```
Benchy  45%  1h 6m  N:210° B:60°
```

**Minimal**:
```
45%  1h 6m left
```

**Detailed** (multiline):
```
Benchy
45%
Nozzle 210°  Bed 60°
1h 6m remaining
```

Immediate alerts are pushed to the glasses for:
- ✅ Print complete
- ⏸ Print paused / ▶ resumed
- ⚠️ Printer error

## Glasses protocol (TCP :8089)

Each message is a JSON object followed by `\n`:

```json
{"type":"print","text":"Benchy  45%  1h 6m  N:210° B:60°"}
{"type":"status","machineStatus":"PRINTING","fileName":"Benchy.gcode","completion":45.2,"timeLeft":3960,"elapsed":3300,"nozzleTemp":210,"nozzleTarget":210,"bedTemp":60,"bedTarget":60,"x":110.5,"y":85.2,"z":22.4}
{"type":"alert","text":"✅ Print complete: Benchy"}
```

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into the glasses Swift file:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Setup

1. Open `RokidSnapmaker.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on an iPhone (iOS 17+) **on the same Wi-Fi as your Snapmaker U1**.
4. Allow local network permission when prompted.
5. Open **Settings** in the app and enter the Snapmaker's IP address.
   - Find it on the machine's touchscreen under **Settings → Wi-Fi** or in your router's DHCP list.
6. Tap **Connect & Authorize** — the machine displays an authorization dialog.
7. Tap **Allow** on the Snapmaker screen.
8. Print status starts streaming immediately.
9. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Polling

| State    | Interval         |
|----------|-----------------|
| Printing | every 5 s (default, adjustable) |
| Idle     | every 15 s      |

Adjust the base interval in Settings (2–30 s).

## Requirements

- iOS 17.0+
- Xcode 15+
- Snapmaker U1 (or other Snapmaker machine with HTTP API) on the same Wi-Fi
- No API key or cloud account needed
