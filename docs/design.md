# Seldon

Implementation-ready UI specification · 20 September 2026

This file is the design source of truth for the shared SwiftUI iOS and visionOS app. Its repository location is explicitly requested for this project.

## Goal

Seldon is a quiet instrument for seeing agent-harness usage at a glance. Its name recalls Foundation's forecaster, connecting science-fiction literature to the product's function rather than its infrastructure. Its interface expresses that influence through precise typography, cool light, clear measurements, and generous negative space. It should look at home floating beside a working Vision Pro window and remain useful on an iPhone.

The primary questions are: which account is being measured, how much of each quota window is used, when that window resets, and how current the measurement is?

The inspected Lachesis response reports quota percentages, not token totals. The UI says **Usage**, **used**, and **reset**. It must not label percentages as token counts or invent a remaining-token estimate.

## Scope and non-goals

Implement one dashboard, one connection sheet, source-reported freshness, initial loading, and an explicit manual refresh. Load once when the configured dashboard first appears. Do not introduce polling, auto-retry, retry backoff, stale thresholds, account switching, quota alerts, account management, historical collection, trend graphs, estimated costs, or notifications.

Seldon consumes an existing HTTP endpoint exposed through an operator-managed SSH tunnel. It does not create or manage that tunnel, store SSH keys, change the server host's listener, or reconfigure Lachesis. Do not add an immersive scene, decorative 3D objects, particles, scan lines, blinking indicators, or ambient animation.

## Verified service contract and presentation

The parent implementation task inspected this normalized shape:

```text
GET /api/v1/usage
  generated_at
  counts { cache, error, live, stale }
  results[]
    account_id
    status
    sample
      account_id, provider, label, plan
      observed_at, age_seconds
      windows[] { id, name, used_percent, resets_at, window_seconds }
      diagnostics[] { code, message }
      raw { provider-specific payload }
    error
```

`GET /health` also returns `status`, `version`, `links`, and `providers`. A separate health screen is outside this design; the dashboard's successful usage response is its useful connection result.

| Source | Display | Rules |
| --- | --- | --- |
| `sample.label` | Account title | Preserve the operator's label; wrap rather than replace it with an ID. |
| `sample.provider` | Provider name | Use a readable provider label; no vendor logo assets required. |
| `sample.plan` | Secondary metadata | Show beside the provider when present. |
| `result.status` | Source badge | `live` → “Live”; `cache` → “Cached”; `stale` → “Stale”; `error` → “Error”. Status is supplied by the service, never inferred from elapsed time. |
| `window.name` | Window title | Preserve the returned name. Do not assume every account has “5 hour” and “Weekly” windows. |
| `window.used_percent` | Utilization meter and number | Format as a percentage with at most one fractional digit, e.g. “42.6%”. Append the visible word “used” in compact cards; the expanded chart has a shared “Used” column heading. |
| `window.resets_at` | Local reset date/time | Show “Resets 3:45 PM” for today and “Resets Sep 24, 3:45 PM” otherwise. Use the device's locale/time format. The accessibility value includes the full date, time, and time zone. |
| `window.window_seconds` | Window duration | Secondary detail only if the returned window name does not already explain duration; use a localized duration such as “5 hours”. |
| `sample.observed_at` | Sample timestamp | “Observed 3:42 PM”; include the date when necessary. Never label it “refreshed” or “live now”. |
| `sample.age_seconds` | Sample age | “Sample age 2 min” describes the server's reported age when the snapshot was fetched. Do not run an age timer or use it to reclassify freshness. |
| `generated_at` | Dashboard snapshot timestamp | “Snapshot Sep 20, 3:42 PM”; distinguish this from each sample's observation time. |
| `counts` | Snapshot summary | Nonzero entries in the order Live, Cached, Stale, Error; include zero values only when all counts are zero. These are source counts, not a synthesized availability score. |

Use `account_id` and window `id` internally for stable identity only. Never display account IDs, email addresses, credentials, the `raw` object, or arbitrary backend error/diagnostic text. The initial UI may show “Service reported an issue” for a diagnostic-bearing sample; adding human-readable diagnostic detail requires confirming that the actual messages are suitable for display. Do not serialize raw payloads into UI debug overlays or fixtures.

Do not sum or average utilization across windows or accounts: the denominators differ. Preserve the service's account and window order in the main dashboard. “Next resets” is the one explicitly time-sorted projection.

### Contract boundaries

Actual JSON types, optionality, status spelling, and date encoding must be checked against the inspected service payload before writing decoding code. This table defines UI semantics, not permission to guess a family of alternate wire schemas. Ignore unused raw fields rather than model them. Accommodate absence only where the actual contract permits it: an unreported value displays “Not reported”, never a synthetic zero; an error result without a sample displays “Account unavailable” and the source error badge, without revealing its internal account ID. If a separately inspected account inventory supplies a safe label, that label may identify the error row.

## Visual system

### Typography

Use the system font throughout. Main numbers use the monospaced system design and monospaced digits. Ordinary text stays in the default system design. This contrast supplies the futuristic character without a custom font dependency.

| Role | SwiftUI base style | Treatment |
| --- | --- | --- |
| App wordmark | `.title2` | Medium weight, “SELDON”, 2 pt tracking; decorative letterspacing is limited to this short word. |
| Screen title | `.largeTitle` | Bold, “Usage”; appears in the spacious layout, not repeated beneath a navigation title on iPhone. |
| Overview number | `.title` | Monospaced digits, regular weight; number of accounts, not a global utilization figure. |
| Account title | `.headline` | Primary foreground; at most two lines at normal text sizes, unlimited lines at accessibility sizes. |
| Window percentage | `.title3` | Monospaced digits, medium weight. Expanded rows retain this size instead of growing indefinitely with the window. |
| Window label / controls | `.body` | Default system styling. |
| Provider / plan / reset | `.subheadline` | Secondary foreground; reset text has full contrast when it is the row's primary detail. |
| Timestamp / section hint | `.footnote` | Secondary foreground, never `.caption2`; wraps normally. |

These are Dynamic Type styles, not fixed pixel fonts. The only tracking is the wordmark. Do not shrink numbers or labels with `minimumScaleFactor` to force a dense layout.

### Color and material tokens

| Token | Dark iOS | Light iOS | Use |
| --- | --- | --- | --- |
| `canvas` | `#0A111B` | `#F3F6FA` | iOS screen background. |
| `surface` | `#131F2E` | `#FFFFFF` | iOS content groups. |
| `surfaceRaised` | `#1B2A3A` | `#E9EFF6` | Meter track and small inset regions. |
| `accent` | `#70DEEF` | `#006C80` | Interactive accent and utilization fill. |
| `accentSecondary` | `#ABA5FA` | `#6551AE` | Small provider/category marker when needed; never a status signal. |
| `separator` | `#34465B` | `#C7D3DF` | Thin rules and meter tick marks. |
| `attention` | `#F1C47A` | `#825300` | Source-reported Stale or Error symbol; accompanying text remains primary. |

Primary and secondary text use semantic `.primary` and `.secondary` rather than fixed white/gray colors. Use system tint behavior for standard controls. Utilization retains the same accent at 1% and 99%; there are no invented warning thresholds.

On visionOS retain the system window glass and semantic vibrant text. Do not paint the entire window with the dark iOS canvas. Account groups use a restrained translucent neutral fill or native grouped material to separate content; no independent glass effects on every card. Use `accent` sparingly for meter fills and selected controls. iOS native bars/sheets own their system glass. Do not apply iOS Liquid Glass APIs to visionOS.

There are no bloom effects behind text, gradients across type, neon outlines around every component, heavy drop shadows, or full-screen branded backplates. One 1 pt separator between major regions is enough. Native window rounding remains native.

### Spacing and geometry

Use a shared spacing scale: 4, 8, 12, 16, 24, 32 pt. Account group radius is 20 pt; inset meter tracks are capsules. Compact outer content padding is 16 pt. Spacious outer padding is 24 pt. Group interior padding is 16 pt compact / 20 pt spacious. Gap between groups is 16 pt. All dimensions describe base text size; content height grows with text.

## Dashboard hierarchy and components

1. **DashboardToolbar**: wordmark at leading; Refresh and Connection at trailing. Use system symbols `arrow.clockwise` and `network`, with actual text labels for accessibility. At spacious widths show visible “Refresh” and “Connection” labels. At compact widths icons suffice visually. Refresh is one action, not a menu. Connection opens the connection sheet.
2. **SnapshotHeader**: “Usage”, account count, source count summary, snapshot timestamp. On iPhone the navigation title is “Seldon” and the content header uses the account count and snapshot summary without a duplicate large app title. The account count is the number of returned account results, including errored results.
3. **AccountUsageCard / UsageComparison**: account title and provider/plan, source badge, every reported window, observation metadata. Compact and expanded views are presentations of the same data and identifiers.
4. **ResetAgenda**: expanded-only secondary projection listing reported reset times, account labels, and window names. Main usage rows always retain their own reset text, so shrinking never hides required information.

Use real `Button`, `Label`, `ProgressView`, and native sheet/form elements where appropriate. The account cards and chart bars themselves are read-only and must not look like buttons.

### AccountUsageCard

Header: account title on leading; source badge on trailing. Below: provider and plan separated by a middle dot. At narrow sizes or large text, the badge moves below the account title rather than truncating it.

Each usage window has:

```text
Five-hour window                         42.6% used
━━━━━━━━━━━━━━━━━━────────────────────────────────
Resets 3:45 PM
```

The meter is 8 pt high in compact mode, with a neutral unfilled track. It describes used capacity from 0–100%; the numeric label is authoritative. Use a continuous fill, not a ring, so multiple windows can be compared without decoding arc angles. Window rows have 16 pt separation. The account footer has source observation time and reported age on one wrapping line, separated from the meters by 12 pt.

Use source status with a symbol and text: Live (`checkmark.circle`), Cached (`archivebox`), Stale (`clock`), Error (`exclamationmark.circle`). Live and Cached use a neutral foreground; Stale and Error add the attention-colored symbol. No animated “live” dot. A card with a reported diagnostic has the short secondary line “Service reported an issue”.

### UsageComparison

At expanded width account cards become a single aligned instrument panel. Each account is a section: its header retains title/provider/plan/status and observation metadata; each window is one chart row beneath it.

```text
ACCOUNT / WINDOW                 USED          UTILIZATION             RESET
Claude personal · Pro · Live
  Five-hour window              42.6%     ━━━━━━━────────────        3:45 PM
  Weekly                        18.2%     ━━━────────────────       Sep 24
Observed 3:42 PM · Sample age 2 min
```

The account/window column has a minimum of 160 pt, the numeric column 80 pt, the plot at least 160 pt and takes remaining width, and the reset column 136 pt. Use a 12 pt meter and shared 0%, 50%, 100% axis labels above the first plotted row. Light tick marks at those positions are sufficient. Preserve visible window names and exact percentages; never make the chart itself the only way to read a value.

This is a current-snapshot comparison chart, not a time series. Do not draw sparklines or imply historical points. Source errors occupy regular account sections and do not cause other accounts to disappear.

### ResetAgenda

Title “Reported resets”. Show returned reset timestamps in ascending order, each with account label and window name. This is an agenda, not a predicted scheduler. Include the local date/time; for a reported timestamp already in the past, say “Reported Sep 20, 1:00 PM” rather than claiming a reset happened or rolling it forward. A small footer says “Times reported by Lachesis”. No live countdown, progress-to-reset estimate, or promise that capacity will become available.

## Responsive layout and morphing

Measure the actual content container, not the device model or `UIScreen.main`. All thresholds are points at normal Dynamic Type. Accessibility text sizes override the density rules.

| Available width | Composition | Visualization |
| --- | --- | --- |
| Under 680 pt | One vertical stream; compact header; single account column. | 8 pt per-window meters inside account cards. |
| 680–1,039 pt | Spacious header; two equal account columns, each at least 300 pt; shared vertical scrolling. | Same cards with additional breathing room and 10 pt tracks. |
| 1,040 pt and wider | Spacious header; main comparison region plus a 280 pt reset agenda, separated by 24 pt. | Aligned 12 pt usage bars and shared axis; reset agenda uses newly available space. |

At 1,040 pt the comparison region can be tight: if its text and minimum plot columns cannot fit, the reset agenda moves below the comparison rather than squeezing labels. At 1,200 pt and above the agenda is beside the comparison. Overall content is centered with a maximum readable width of 1,560 pt. Beyond that, margins grow; type and bars do not become billboard-sized. The design does not add a third or fourth account-card column.

The change from card deck to comparison panel is an intentional structural change. Preserve selected connection state and dashboard data across it. Do not refetch when the width crosses a breakpoint. Do not reorder accounts during resize or refresh. A brief opacity transition is sufficient; never stretch card text into chart text.

### Minimum and short-window behavior

The visionOS window's content minimum is 420 × 420 pt, with an initial requested size of 1,160 × 760 pt. The content has no maximum window size; its internal readable width is capped. At minimum size the toolbar stays reachable and the dashboard is a single vertically scrolling stream. No horizontal scrolling is required. Do not force all accounts above the fold.

At any width with less than 560 pt height, collapse decorative header space, retain account count and snapshot metadata, and let the content scroll. Do not shrink controls or clip account windows. A short iPhone landscape view follows the same rule.

## visionOS

Use a normal resizable `WindowGroup` with native glass, not a volume or immersive space. Request the initial size with `defaultSize(width:height:)`; use `windowResizability(.contentMinSize)` and a content minimum. The user controls subsequent size and placement. See [Apple's window sizing guidance](https://developer.apple.com/documentation/visionos/positioning-and-sizing-windows).

Keep reading content on one comfortable plane. No rotating charts, head-following elements, exaggerated depth offsets, or gaze-triggered content changes. Native controls supply hover behavior. Minimum interactive regions are 60 × 60 pt on visionOS, with 12 pt between neighboring standalone controls. Read-only meters are not gaze targets.

The main toolbar lives in the window's ordinary toolbar area. Do not add a separate ornament merely for decoration. The connection sheet is presented relative to the same window. A user should never need to arrange additional windows to understand the dashboard.

Retain the adaptive native material and use semantic text to stay readable against different environments, following [Apple's material guidance](https://developer.apple.com/design/human-interface-guidelines/materials).

## iOS and iPadOS

Use a native `NavigationStack`, safe areas, a navigation title, and toolbar actions. Standard content uses the palette above and follows the system's light/dark appearance. iPhone uses the single stream at ordinary portrait widths. iPad and large landscape containers use the same width-based expansion rules as visionOS; do not hardcode an iPad-specific dashboard.

Use 44 × 44 pt minimum interactive regions. The connection form appears as a native sheet with Cancel and Save & Connect. Keep text entry visible above the keyboard. At accessibility sizes use a large sheet/full available height; do not depend on a short fixed detent.

## Connection experience

### First launch

Do not prefill a guessed endpoint or automatically call the server host by hostname. The empty dashboard uses `ContentUnavailableView` with title **Connect to Lachesis**, one short explanation, and the primary **Configure Connection** button.

Exact explanatory copy:

> View account usage from the Lachesis server through your existing SSH tunnel.

### Connection sheet

Title: **Connection**.

One editable field, **Server URL**, with URL keyboard, no autocorrection, and no automatic capitalization. It stores the base HTTP(S) URL; the client appends the known service routes. The placeholder is **http://tunnel-host:port** and is an example, not a runnable endpoint. Existing settings populate the field when editing.

Helper copy:

> Lachesis listens only on the server host's loopback interface. Enter the HTTP address exposed by your existing SSH tunnel.

> On iPhone or Vision Pro, the tunnel endpoint must be reachable from this device. “localhost” refers to this device, not the server host or your Mac.

Actions: **Cancel** and **Save & Connect**. Saving stores the URL locally and loads usage from that address. Draft edits do not affect the active connection until Save & Connect is pressed. Cancel leaves the prior setting intact. Show the active server URL only in this connection sheet, not as a long dashboard heading.

Do not add credential fields, tunnel commands, SSH host discovery, “Fix automatically” actions, environment selectors, or multiple connection profiles. HTTP support, ATS/local-network configuration, and actual endpoint testing are implementation responsibilities; do not imply that a syntactically valid URL proves reachability.

## Loading, empty, and error presentation

These are direct representations of the requested operation, without a new background failure policy.

| State | Presentation |
| --- | --- |
| No saved connection | First-launch configuration state above. |
| Initial request in progress | Native indeterminate `ProgressView` labeled “Loading usage”; toolbar Connection remains available. No fake percentages or shimmering dummy values. |
| Successful response with zero results | `ContentUnavailableView`: “No accounts reported”, “This Lachesis snapshot contains no accounts.” Keep the snapshot timestamp and Refresh action. |
| Successful response with per-account source errors | Show the returned account sections and their source Error badges. Healthy sections remain fully readable. |
| Request fails before any snapshot | `ContentUnavailableView`: “Couldn’t load usage”, “Check the server URL and SSH tunnel, then refresh.” Buttons Refresh and Connection. Do not show raw response bodies. |
| Manual refresh in progress | Keep the currently displayed snapshot and its timestamp; replace Refresh's icon with a native progress indicator and disable that one action while the request is running. |
| Manual refresh fails | Keep the previously displayed snapshot explicitly labeled “Previous snapshot”; show an inline “Refresh failed” message and the same manual Refresh action. Do not relabel source statuses or create client-defined staleness. |

Switching to a different saved server clears the previous server's displayed snapshot before loading the new one. Do not imply one server's values belong to another. No modal alert interrupts reading for a failed refresh.

## Accessibility

- All meaningful values have text equivalents. Source status uses symbol plus word; meter fill color is never the sole signal. Provide a VoiceOver summary per window: “[account label], [window name], 42.6 percent used, resets [full local date and time].” Read source status and sample observation metadata after that account's windows.
- Hide decorative track, tick, and separator elements from the accessibility tree. A meter and its adjacent visible labels must not produce duplicate readings. Account IDs and raw fields must never enter accessibility labels.
- At accessibility Dynamic Type sizes, use one column regardless of window width. Replace the comparison panel with the card presentation, move metadata onto separate lines, allow wrapping, and maintain vertical scrolling. No ellipsis may hide a percentage, reset time, or status.
- Use semantic foreground styles on material. Verify ordinary text contrast at least 4.5:1 and large text at least 3:1 in the actual rendered iOS light/dark and visionOS environments. Adjust the design token shade if necessary rather than adding glow.
- Honor Increase Contrast and Differentiate Without Color. All status semantics already have words and symbols. Under Reduce Transparency use a legible system-appropriate opaque/grouped treatment where the platform exposes that setting; preserve the native window chrome.
- Keyboard and Voice Control users can activate Connection, Refresh, Cancel, and Save & Connect using their visible names. Focus order follows the visual reading order. Every custom interactive region must be a `Button`, never an unlabelled tap gesture.

## Motion

Motion exists only to explain an explicit change. Use a 180 ms ease-in-out opacity transition when changing layout composition. On a successful manual refresh, meter fill may interpolate for 240 ms and a numeric content transition may update percentages. Animate only the changed values; do not apply implicit animation to the entire dashboard or continuously animate a resize.

With Reduce Motion enabled, update bar lengths and numeric text without interpolation; permit only a short opacity change of at most 100 ms. Native loading indicators may remain native. No pulsing Live badge, animated background, repeating shimmer, sliding whole-screen transitions, spring overshoot, or countdown ticker.

## SwiftUI implementation constraints

- Keep one observable dashboard state owner in a stable parent using `@Observable` and native Swift concurrency. The network service and decoded snapshot are shared by all layouts; card/comparison/agenda views are projections, not separate fetching controllers.
- Put connection draft state and focus state in the sheet's stable root. Avoid `.id(width)` or `.id(snapshotTimestamp)` on state-owning views. Breakpoint changes must not recreate the connection state or initiate requests.
- Use actual container width and Dynamic Type to choose composition. `ViewThatFits`, adaptive layout, or a focused `Layout` implementation are appropriate; do not use global screen dimensions or inspect the hardware model.
- Keep visual constants in one shared design-token definition. Split concrete components into appropriately named files: `DashboardView`, `DashboardToolbar`, `SnapshotHeader`, `AccountUsageCard`, `UsageWindowRow`, `UsageComparison`, `ResetAgenda`, `SourceStatusBadge`, and `ConnectionView`. These are component boundaries, not a requirement for extra abstraction layers.
- Prefer native SwiftUI shapes for the meters. Swift Charts is acceptable if it produces the specified accessible horizontal comparison without extra decoration; no third-party chart or font package is needed.
- Use `@Environment` accessibility settings to select motion/layout behavior. Do not fork a separate inaccessible “futuristic” view hierarchy.
- Keep iOS-specific glass and toolbar configuration behind platform boundaries. Use native visionOS material behavior. No UIKit window-size lookup is necessary.
- Preview data must be explicitly synthetic and must use the normalized model. Include multiple windows with different names, a source Stale sample, an Error result, a long safe account label, and an empty snapshot. Preview values never appear as live production data.

## Acceptance checks

1. At 420 × 420 pt on visionOS, Refresh and Connection remain usable; all account windows are reachable by vertical scrolling; there is no horizontal overflow.
2. At approximately 760 pt width, accounts form two readable columns. At 1,160 × 760 pt the chart comparison replaces the cards, with the reset agenda below if necessary. At 1,280 pt width the agenda sits alongside the comparison. At 1,800 pt, readable content remains centered and capped.
3. Resize repeatedly across each breakpoint: the same account data and source statuses remain, no duplicate fetch occurs, and an open connection draft is preserved.
4. An iPhone portrait layout displays the same windows, percentages, reset times, and freshness as the expanded spatial layout. It does not replace the detail with an aggregate score.
5. A 99% value is readable in the same accent as a 1% value; no unsupported quota warning appears. Source Stale/Error labels remain distinguishable without color.
6. Largest accessibility Dynamic Type uses one column with complete wrapping. VoiceOver reads each metric once, with its account/window context and exact reset date/time.
7. Reduce Motion removes numeric and meter interpolation. The interface has no idle animation beyond a native loading indicator during a request.
8. First launch clearly explains the existing tunnel requirement. A URL pointing at an unreachable tunnel produces the defined error state; the UI never claims to establish SSH itself.
9. Manual refresh changes only after the user acts. Failure preserves a clearly identified previous snapshot and does not synthesize source freshness.
10. Screens, accessibility labels, previews, and user-facing logs contain no raw provider payloads, account IDs, email addresses, credentials, or fabricated token counts.

## Implementation handoff and open questions

Implement the dashboard, connection form, and adaptive presentation above. Use the inspected service payload as the decoding authority. The primary visual is current quota utilization, so historical chart work is outside scope.

No product-design decision is waiting on the user. The implementation must confirm exact field optionality, timestamp encoding, and safe label contents from the real normalized response. A real device connection also depends on an operator-provided tunnel endpoint reachable by that device; the design intentionally does not choose a tunnel transport or change server exposure.

Review handoff terminology: the implementation is **ready for Flynn verification** after its build and checks; only Flynn confirms the product behavior.
