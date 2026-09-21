# Seldon architecture

Seldon is one SwiftUI project with separate iOS and visionOS entry points. The
targets share the model, service, state, design token, and view layers; only
scene configuration and platform-specific navigation/toolbars are conditional.

## Boundaries

- `Models` contains the verified normalized usage and forecast responses. It
  retains only fields needed for presentation and stable internal identity. Raw
  provider payloads, account identifiers in user-facing text, and arbitrary
  diagnostic or qualification messages do not cross into views.
- `Services` owns HTTP transport and local connection persistence. It requests
  the current snapshot and optional forecast from the same configured base URL.
  The service protocol makes state and previews testable without a network
  dependency.
- `State` contains one `@Observable @MainActor` dashboard owner. It performs
  initial and explicit manual loads, preserves the last usage snapshot on
  refresh failure, clears forecast data at the start of every refresh, and
  clears both snapshots when a different saved server is selected. Each load
  has a generation so an older usage or forecast response cannot overwrite a
  newer connection.
- `Design` is the single home for spacing, color, typography, and geometry
  tokens shared by both platforms.
- `Views` are feature-oriented projections of the shared state. Card, aligned
  comparison, and reset agenda presentations do not fetch or own dashboard
  data. Geometry and Dynamic Type choose the composition from the actual
  content container width.
- `App` contains only platform entry points. iOS uses a native
  `NavigationStack`; visionOS uses a normal resizable `WindowGroup` with the
  requested default size and content minimum.

## Concurrency and state

`DashboardModel` is the stable state owner. Its service calls use Swift
concurrency and return to the main actor before changing observable state.
Views use `.task` for the one initial load and call explicit model actions for
refresh and connection changes. Breakpoint changes only select a projection;
they never recreate the model or initiate a request.

## Wire contract

`GET /api/v1/usage` is decoded as the inspected normalized shape. Timestamps
are ISO-8601 strings; percentages and window durations are numeric; source
statuses and snapshot count keys are exact. `GET /api/v1/usage/forecast` is
decoded as the inspected aggregate shape with per-account forecasts and
separate compatible pools. Unknown or unused fields are ignored. Diagnostic,
error, and qualification keys are reduced to presence markers so the UI can
show safe qualification copy without exposing backend text.

The forecast is optional for compatibility with older servers. A forecast
failure does not fail a usage load. The state owner exposes the current usage
snapshot with a runway-unavailable state and never retains an ETA from the
previous refresh. Runway durations use the forecast's `generated_at` as their
reference time, so the UI does not create a countdown ticker.

## Responsive composition

The dashboard measures its content container. It uses one stream below 680 pt,
two card columns from 680 through 1,039 pt, and the comparison plus reset
agenda at 1,040 pt and above. At accessibility Dynamic Type sizes it always
uses the card stream. The readable content width is capped at 1,560 pt and
the reset agenda moves below the comparison until the comparison and agenda
can fit side by side.

## Testing

The test target covers exact normalized decoding, safe diagnostic/error
presence handling, formatting, and state transitions with an in-memory
service. UI verification remains a simulator/device concern because window
resizing and VoiceOver behavior depend on the platform runtime.
