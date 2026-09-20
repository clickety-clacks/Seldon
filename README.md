# Seldon

Seldon is a SwiftUI usage dashboard for iPhone and Apple Vision Pro. Configure a usage-server URL to view account quota utilization, reset times, source freshness, and reported status in one quiet, readable panel.

The project uses shared SwiftUI models, services, state, design tokens, and views. It has separate iOS and visionOS app targets where platform-specific scene and navigation behavior differs.

## Preview

<p align="center">
  <img src="docs/images/visionos-preview.png" alt="Seldon dashboard floating in Apple Vision Pro" width="760">
</p>

<p align="center">
  <img src="docs/images/ios-preview.png" alt="Seldon dashboard on iPhone" width="300">
</p>

## Lachesis integration

Seldon is a visual client for [Lachesis](https://github.com/clickety-clacks/lachesis), the usage service that provides its normalized account and quota snapshots. Configure Seldon with the reachable base URL for your Lachesis instance; it requests the usage snapshot from that address.

## What it shows

- Account labels, provider, and plan when reported by the server
- Per-window percentage used and reset time
- Source-reported status: Live, Cached, Stale, or Error
- Observation time, sample age, and snapshot summary
- A compact card layout that expands into an aligned comparison panel when the window is wide enough

Seldon presents the values supplied by the configured server. It does not create token estimates, synthesize a global quota score, collect history, or expose raw provider payloads.

## Platforms

- iOS 26 or later
- visionOS 26 or later

The iOS target uses a complete app icon. The visionOS target uses a layered app icon with an opaque background and transparent foreground.

## Configure a server

On first launch, choose **Configure Connection** and enter a reachable HTTP or HTTPS base URL. Seldon requests:

```text
GET /api/v1/usage
```

The configured URL stays on the device. Seldon does not include credentials, host discovery, connection profiles, or automatic network setup.

## Responsive interface

Seldon measures the available content width instead of choosing layouts by device model:

| Width | Layout |
| --- | --- |
| Under 680 pt | Single column of compact account cards |
| 680–1,039 pt | Two account-card columns |
| 1,040 pt and wider | Usage comparison panel with reset agenda |

The visionOS window requests an initial 1,160 × 760 pt size and maintains a 420 × 420 pt content minimum. At accessibility text sizes, the interface uses one readable scrolling column.

## Build

1. Install Xcode with the iOS and visionOS SDKs.
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen).
3. Generate and open the project:

   ```sh
   xcodegen generate
   open Seldon.xcodeproj
   ```

4. Select the iOS or visionOS scheme, configure your signing team, and run on a simulator or device.

The project declaration is in `project.yml`. Product views and shared code are in `Seldon/`; tests are in `SeldonTests/`.

## Architecture

- `Models`: normalized usage data safe for presentation
- `Services`: HTTP transport and local server-URL persistence
- `State`: observable dashboard state and manual refresh behavior
- `Design`: shared spacing, color, typography, and geometry tokens
- `Views`: adaptive iOS and visionOS projections of the shared state

See [the architecture notes](docs/architecture.md) and [the design specification](docs/design.md) for the complete implementation guidance.
