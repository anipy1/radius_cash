# CLAUDE.md — Flutter Architecture Rules

This project follows the architecture of **Real-World Flutter by Tutorials** (Kodeco),
adapted to a single-package `lib/` layout with modern tooling. These rules are
non-negotiable. Detailed patterns, templates, and rationale live in `.claude/skills/`
— consult the matching skill before working on any area listed in the routing table
below.

## Golden rules

### Structure
- All code lives in `lib/`, organized as: `features/`, `repositories/`,
  `domain_models/`, `component_library/`, `form_fields/`, `remote_api/`,
  `local_storage/`, `monitoring/`, `routing/`, `l10n/`, plus `main.dart`.
- **The four commandments**: (1) no circular dependencies between folders;
  (2) no `common`/`shared`/`utils` folder — ever; (3) every top-level folder and every
  feature/repository has exactly one barrel file exporting its minimal public API;
  (4) implementation lives in `src/` — never import another folder's `src/` files.
- Dependency direction is strictly downward:
  `main/routing → features → (component_library, form_fields, repositories) →
  (remote_api, local_storage) → domain_models`. `domain_models` depends on nothing
  but `equatable`.

### Features
- A feature never imports another feature. Cross-feature communication happens via
  callback constructor parameters (`onSignInSuccess`, `onItemSelected`,
  `onAuthenticationError`), wired exclusively in `lib/routing/`.
- Every feature is a two-widget pair: public `XScreen` (creates the `BlocProvider`,
  takes repositories + callbacks) and `@visibleForTesting XView` (the actual UI).
- Feature barrels export only the Screen (and its public types) — never Bloc, Cubit,
  State, or Event classes.

### Data
- Three model families with mandatory suffixes: `*RM` remote models (in
  `remote_api/`), `*CM` cache models (in `local_storage/`), unsuffixed domain models
  (in `domain_models/`). Only repositories see more than one family.
- Repositories are the single access point to data and the exception-translation
  boundary: every API/storage exception is caught and rethrown as a `domain_models`
  exception. Features never see Dio, Hive, or `*RM`/`*CM` types.
- Mappers are extension methods in the repository's `src/mappers/`, one file per
  direction. Repositories return domain models only — `Future` for one-shot,
  `Stream` for reactive/multi-emission (fetch policies, BehaviorSubject).

### State
- State management is the bloc library only — no Provider-only state, no Riverpod,
  no GetX. **Cubit by default; upgrade to Bloc only when you must control how
  incoming events are processed** (debouncing, restartable, repository-stream
  subscriptions).
- All state classes extend `Equatable`. Form-shaped screens use a single state class
  with `copyWith` + a `SubmissionStatus` enum; phase-shaped screens use a `sealed`
  base class with `InProgress`/`Success`/`Failure` subclasses.
- `BlocBuilder` builds UI; `BlocListener` handles one-off side effects (snackbars,
  dialogs, navigation callbacks); never navigate or show snackbars from a builder.

### Wiring
- Dependency injection is constructor injection composed once in `main.dart`
  (`late final` chaining). No service locator, no `GetIt`, no
  `context.read<Repository>()`.
- Navigation uses go_router in `lib/routing/` — the only place that knows multiple
  features exist.

### Quality
- No magic numbers: spacing and font sizes come from `Spacing`/`FontSize` tokens;
  colors from the app theme. No hardcoded user-visible strings: everything goes
  through l10n.
- Secrets arrive via `--dart-define` (`String.fromEnvironment`); auth tokens live in
  `flutter_secure_storage` only. Never commit keys.
- Definition of done: new Cubit/Bloc → bloc test; new mapper → unit test; new shared
  widget → widget test. Run `flutter analyze` before declaring work complete.

## Approved packages

Never introduce a competing package for a concern already covered here. If a better
alternative exists, propose it — don't switch without approval.

| Concern | Package |
|---|---|
| State management | `flutter_bloc`, `bloc_concurrency`, `equatable` |
| Networking | `dio` (+ `json_annotation`/`json_serializable`) |
| Local cache | `hive_ce` (+ `hive_ce_generator`), `path_provider` |
| Secure storage | `flutter_secure_storage` |
| Reactive streams | `rxdart` |
| Forms | `formz` |
| Routing | `go_router` |
| Pagination | `infinite_scroll_pagination` |
| Localization | `intl` + Flutter gen-l10n |
| Monitoring | `firebase_core`, `firebase_analytics`, `firebase_crashlytics`, `firebase_remote_config` — only ever imported inside `lib/monitoring/` |
| Testing | `bloc_test`, `mocktail`, `http_mock_adapter`, `integration_test` |
| Codegen | `build_runner` |

## Skill routing

| When the task involves… | Consult skill |
|---|---|
| Creating a project, feature, or folder; naming; where a file goes; main.dart wiring | `project-structure` |
| APIs, repositories, caching, models, mappers, persistence, auth tokens | `data-layer` |
| Cubits, Blocs, state classes, screens, BlocBuilder/Listener | `state-management` |
| Forms, validation, text fields, sign-in/sign-up flows | `forms` |
| Routes, navigation, tabs, deep links | `navigation` |
| Reusable widgets, theming, colors, spacing, dark mode | `design-system` |
| User-visible strings, translations | `localization` |
| Analytics, crash reporting, Firebase, feature flags | `monitoring` |
| Writing or fixing tests, mocking | `testing` |
| CI, GitHub Actions, builds, distribution | `ci-cd` |

## Agents

- Before building any **new feature or repository**, launch the `feature-planner`
  agent and follow its file-by-file plan.
- After completing a feature or any significant change, launch the
  `rwf-compliance-reviewer` agent and fix every violation it reports.

## Deviations from the book (do not "correct" these back)

lib/ folders instead of local packages · go_router instead of routemaster ·
App Links/Universal Links instead of Firebase Dynamic Links (service shut down 2025) ·
Dart 3 `sealed` classes instead of abstract state bases · mocktail only ·
one `lib/l10n/` with feature-prefixed keys instead of per-package l10n.

## Project notes (radius.cash)

- Always `fvm flutter`, never bare `flutter`. This project is pinned to
  3.41.8 in `.fvmrc`, and the global fvm default is older and fails the SDK
  constraint quietly. Check for the `Built` line before installing anything.
- `lib/mesh_transport/` plays the `remote_api/` role: the BLE mesh, Noise
  sessions and the Nostr relay path. Pure Dart plus the Bluetooth plugin.
  Only repositories, `local_storage/` and `main.dart` may import its barrel.
- `lib/location/` and `lib/keep_alive/` wrap a plugin and a platform channel
  the same way, each for one repository only.
- Deliberate deviation: `lib/local_storage/` imports the `mesh_transport`
  barrel for the `SeedVault` interface. Sideways, not a cycle;
  `mesh_transport/` must never import `local_storage/` back.
- HKDF info strings inside the transport still say `mesh-chat/...` so a seed
  carried over from the earlier app derives the same keys. Do not rename them.
- Devices on hand: Xiaomi `YPDAVGHIHQU8WKUO` over USB, iPhone
  `00008110-0018091E3C52401E`. Bundle id is `cash.radius`.
- Commit messages in my voice: no em dashes, no contractions, say what
  changed and why, never narrate feelings.
