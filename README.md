# Clockout

A tip and shift tracker for iPhone that shows what you really make an hour.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black) ![SwiftUI](https://img.shields.io/badge/SwiftUI-Swift%205-orange) ![Built on GitHub Actions](https://img.shields.io/badge/built%20on-GitHub%20Actions%20macOS-2088FF)

**Coming to the App Store.**

<p align="center">
  <img src="fastlane/screenshots/en-US/01_iPhone.png" width="250" alt="Clockout screenshot">
  <img src="fastlane/screenshots/en-US/02_iPhone.png" width="250" alt="Clockout screenshot">
  <img src="fastlane/screenshots/en-US/03_iPhone.png" width="250" alt="Clockout screenshot">
</p>

For servers, bartenders, baristas, delivery drivers, stylists and anyone paid hourly plus tips. Wages plus tips, minus tip-out, divided by the hours you actually worked: that is your real hourly rate, and Clockout shows it for every shift, week and job.

## Features

- Punch out: clock in and out (past midnight handled) or type the hours; sales, cash tips, card tips and a tip-out from the job's rule
- Live take-home and per-hour as you type
- The month against your goal with a pace line; week, year, average per shift, tips as a share of sales
- Insights (Swift Charts): take-home by weekday, which shift type pays best, sixteen weeks of tips and wages, jobs side by side
- Paycheck check: compares your logged hours and wages with what the check says
- Tax year totals by job and month, exported as CSV; multiple jobs, each with its own wage and tip-out rule

## Price

A paid app: one price, no in-app purchases, no subscription, no ads.

## Privacy

No network code at all: Clockout makes no requests and collects no data. Everything is saved on the device in `clockout.json`. The privacy manifest (`Resources/PrivacyInfo.xcprivacy`) declares no tracking and no collected data types.

## Built without a Mac

This app was written on a Windows PC. No Mac is involved at any point: every build, signature, screenshot and App Store submission runs on GitHub Actions macOS runners, driven by the App Store Connect API.

- **`project.yml`** is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. The `.xcodeproj` is generated on the runner and never committed, so the repo can be edited on any OS and there are no `.pbxproj` merge conflicts.
- **`.github/workflows/build.yml`** runs on every push: picks the newest Xcode 26 and iPhone simulator on the runner, builds, then launches the app once per screen with `-shot <screen>` (sample data, fixed 9:41 status bar) and captures the store screenshots with `simctl`, uploaded as a workflow artifact.
- **`.github/workflows/appstore.yml`** (manual) has three modes: `compile`, `dry_run` (build, sign, upload, do not submit) and `release` (also submits for review). The distribution certificate is imported from a secret into a throwaway keychain; [fastlane](https://fastlane.tools) (`fastlane/Fastfile`) fetches the App Store profile with the API key, sets the build number one above the latest on TestFlight, archives, and uploads the binary with `fastlane/metadata` and the committed `fastlane/screenshots`.
- **`.github/workflows/review-video.yml`** records the App Review screen recording: the app is launched with `-demoAutoplay` and drives its own real screens.
- **`Store/*.py`** talk to the App Store Connect API directly from Windows (Python, `requests` + `PyJWT`): `asc.py` registers the bundle id and pushes metadata, `listing.py` sets the age rating, review details, price and screenshots, and `signing.py` creates the distribution certificate locally so its private key is never stranded on a disposable runner.

Only one step is manual: Apple's API will not create the app record itself, so that is made once in the App Store Connect web UI.

## Build and run

With a Mac and Xcode 26 (the version CI uses; the app targets iOS 17+):

```bash
brew install xcodegen
xcodegen generate
open Clockout.xcodeproj
```

Run the `Clockout` scheme on any iPhone simulator. No signing is needed for the simulator; from the command line:

```bash
xcodebuild build -project Clockout.xcodeproj -scheme Clockout \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

To see it filled with sample data, launch with a screenshot argument, e.g. `xcrun simctl launch booted com.mattbusel.clockout -shot today`.

Without a Mac: fork the repo and push. The Build workflow compiles it on a GitHub macOS runner and attaches the screenshots as an artifact.

Shipping your own build needs these repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (base64 of the `.p8`), `DEVELOPMENT_TEAM`, `DIST_CERT_P12`, `DIST_CERT_PASSWORD`, plus your own bundle id in `project.yml` and `fastlane/Fastfile`.

## Code map

All app code is in `Sources/` (SwiftUI, Observation, no third-party dependencies).

| File | What it does |
| --- | --- |
| `App.swift` | entry point, tabs, the add-shift form state, `-shot` handling |
| `Model.swift` | jobs, shifts, tip-out rules, hourly and pay-period maths, JSON persistence, CSV |
| `Views.swift` | tonight, add, shifts, insights, paycheck and tax screens |
| `Theme.swift` | late-night diner look, receipt paper |
| `Demo.swift` / `Autopilot.swift` | screenshot data and the App Review recording |

`Store/` holds the App Store Connect scripts, `fastlane/` the lanes, listing text and screenshots, `Resources/` the asset catalog and privacy manifest.

---

**More apps built the same way:** [Chain](https://github.com/Mattbusel/chain), [Ironbook](https://github.com/Mattbusel/ironbook), [Quiver](https://github.com/Mattbusel/quiver), [Race Fuel](https://github.com/Mattbusel/race-fuel), [Minder](https://github.com/Mattbusel/minder), [Baseline Ledger](https://github.com/Mattbusel/baseline-ledger), [Fairway Ledger](https://github.com/Mattbusel/fairway-ledger), [Odometer](https://github.com/Mattbusel/odometer), [Rooms](https://github.com/Mattbusel/rooms), [Curve](https://github.com/Mattbusel/curve), [Pricebook](https://github.com/Mattbusel/pricebook), [Chores](https://github.com/Mattbusel/chores), [Pawprint](https://github.com/Mattbusel/pawprint), [Pocket Beings](https://github.com/Mattbusel/pocket-beings), [Glyphstorm](https://github.com/Mattbusel/glyphstorm), [Clear the Strait](https://github.com/Mattbusel/clear-the-strait).
