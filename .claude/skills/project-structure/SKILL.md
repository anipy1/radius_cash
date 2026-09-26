---
name: project-structure
description: Project layout, folder organization, naming conventions, barrel files, and main.dart composition for RWF-architecture Flutter apps. Use when creating a project, adding a feature or repository folder, deciding where a file goes, naming files/classes, or wiring dependencies in main.dart.
---

# Project Structure

Source: *Real-World Flutter by Tutorials* ch. 1–2 & 6 (WonderWords), adapted from
local packages to `lib/` folders.

## The lib/ layout

```
lib/
├── main.dart                     # Composition root — the ONLY place objects are wired
├── routing/                      # go_router setup; the only place that knows all features
│   ├── routing.dart              # barrel
│   └── src/routes.dart
├── features/
│   └── <feature_name>/           # one folder per screen/flow (e.g. sign_in, quote_list)
│       ├── <feature_name>.dart   # barrel: exports ONLY the Screen (+ public types)
│       └── src/
│           ├── <feature_name>_screen.dart
│           ├── <feature_name>_cubit.dart      (or _bloc.dart + _event.dart)
│           └── <feature_name>_state.dart      (part of the cubit/bloc file)
├── repositories/
│   └── <entity>_repository/      # one folder per data domain (e.g. user_repository)
│       ├── <entity>_repository.dart           # barrel: Repository + fetch-policy enum
│       └── src/
│           ├── <entity>_repository.dart
│           ├── <entity>_local_storage.dart    # thin wrapper over local_storage
│           └── mappers/
│               ├── mappers.dart               # internal barrel
│               ├── remote_to_domain.dart      # extension methods, one file/direction
│               ├── remote_to_cache.dart
│               ├── cache_to_domain.dart
│               └── domain_to_remote.dart
├── domain_models/                # pure domain classes + domain exceptions
│   ├── domain_models.dart
│   └── src/{<model>.dart, exceptions.dart}
├── component_library/            # design system: theme, tokens, shared widgets
│   ├── component_library.dart
│   └── src/{theme/, <widget>.dart}
├── form_fields/                  # Formz inputs shared by ≥2 features
│   ├── form_fields.dart
│   └── src/<field>.dart
├── remote_api/                   # Dio client + *RM models + API exceptions
│   ├── remote_api.dart
│   └── src/{<name>_api.dart, url_builder.dart, models/}
├── local_storage/                # Hive wrapper + *CM models + adapters
│   ├── local_storage.dart
│   └── src/{key_value_storage.dart, models/}
├── monitoring/                   # wrappers around Firebase — nothing else imports firebase_*
│   ├── monitoring.dart
│   └── src/{analytics_service.dart, error_reporting_service.dart, remote_value_service.dart}
└── l10n/                         # ARB files + generated localizations (committed)
```

## The four commandments

1. **No circular dependencies.** If folder A imports folder B, B must never import A.
   Allowed direction: `main/routing → features → (component_library, form_fields,
   repositories) → (remote_api, local_storage) → domain_models`.
2. **No `common`, `shared`, or `utils` folder.** Shared code belongs in the most
   specialized home: `domain_models/`, `component_library/`, or `form_fields/`.
   Never create a folder for a single utility function.
3. **One barrel file per folder** (`<folder_name>.dart` at the folder root),
   exporting only the minimal public surface:
   - feature → the Screen widget (and any public types its constructor needs)
   - repository → the Repository class + its fetch-policy enum
   - never export Cubits, Blocs, States, Events, mappers, `*RM`/`*CM` models
4. **Everything else lives in `src/`.** Files outside the folder import only the
   barrel — importing another folder's `src/` file is a violation. (Within the same
   folder, `src/` files import each other freely.)

## When to create a new folder

- New user-facing screen or flow → new `lib/features/<name>/`.
- New data domain (orders, products, …) → new `lib/repositories/<name>_repository/`.
- A widget needed by a **second** feature → move it to `component_library/`
  (until then it stays in the feature's `src/`).
- A Formz field needed by a second feature → `form_fields/`.

## Naming conventions

| Thing | Pattern | Example |
|---|---|---|
| Files | `lower_snake_case.dart` | `quote_list_bloc.dart` |
| Screen | `<Feature>Screen` in `<feature>_screen.dart` | `SignInScreen` |
| View | `<Feature>View`, `@visibleForTesting`, same file as Screen | `SignInView` |
| Cubit / Bloc | `<Feature>Cubit` / `<Feature>Bloc` | `SignInCubit`, `QuoteListBloc` |
| State | `<Feature>State`; subclasses `<Feature>InProgress/Success/Failure` | `QuoteDetailsSuccess` |
| Event | `<Feature><PastTenseAction>` | `QuoteListSearchTermChanged` |
| Remote model | `<Entity>RM` (requests: `<Name>RequestRM`) | `QuoteRM` |
| Cache model | `<Entity>CM` | `QuoteCM` |
| Domain model | plain name | `Quote`, `User` |
| Repository | `<Entity>Repository` | `QuoteRepository` |
| Domain exception | `<Descriptive>Exception` | `InvalidCredentialsException` |
| Test file | `<subject>_test.dart` | `sign_in_cubit_test.dart` |

## Feature scaffolding checklist

To add feature `foo_bar`:

1. `lib/features/foo_bar/foo_bar.dart` — barrel exporting `src/foo_bar_screen.dart`.
2. `lib/features/foo_bar/src/foo_bar_screen.dart` — `FooBarScreen` (BlocProvider) +
   `@visibleForTesting FooBarView`.
3. `lib/features/foo_bar/src/foo_bar_cubit.dart` (default) or `foo_bar_bloc.dart` +
   `foo_bar_event.dart` — see `state-management` skill for the Cubit-vs-Bloc rule.
4. `lib/features/foo_bar/src/foo_bar_state.dart` — `part of` the cubit/bloc file.
5. Route entry in `lib/routing/src/routes.dart` injecting repositories + callbacks.
6. Strings in `lib/l10n/` ARB files, keys prefixed `fooBar…`.
7. `test/features/foo_bar/foo_bar_cubit_test.dart`.

## main.dart — the composition root

Every service, API client, storage, and repository is instantiated exactly once in
the root widget's `State`, then passed down through the routing layer via
constructors. Use `late final` to break chicken-and-egg wiring (the API client needs
a token supplier backed by the user repository):

```dart
class _MyAppState extends State<MyApp> {
  final _keyValueStorage = KeyValueStorage();
  final _analyticsService = AnalyticsService();
  late final _api = AppApi(
    userTokenSupplier: () => _userRepository.getUserToken(),
  );
  late final _quoteRepository = QuoteRepository(
    remoteApi: _api,
    keyValueStorage: _keyValueStorage,
  );
  late final _userRepository = UserRepository(
    remoteApi: _api,
    noSqlStorage: _keyValueStorage,
  );
  late final _router = buildRouter(
    userRepository: _userRepository,
    quoteRepository: _quoteRepository,
  );
  // ...MaterialApp.router(routerConfig: _router, ...)
}
```

Bootstrap with full error capture (see `monitoring` skill for details):

```dart
void main() => runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        await initializeMonitoringPackage();
        FlutterError.onError = _errorReportingService.recordFlutterError;
        runApp(const MyApp());
      },
      (error, stack) =>
          _errorReportingService.recordError(error, stack, fatal: true),
    );
```

Rules:
- No service locator, no `GetIt`, no `RepositoryProvider`, no
  `context.read<Repository>()`. Constructor injection only.
- A class instantiates a dependency itself only when that dependency is defined in
  the **same** folder (e.g. `QuoteRepository` builds its own `QuoteLocalStorage`);
  anything from another folder is required through the constructor. Provide
  `@visibleForTesting` optional constructor params as test seams.

## Why (from the book)

Chapter 1 argues that splitting the codebase into isolated modules enforces
separation of concerns, keeps public APIs deliberate, makes room for safe
experimentation, contains mistakes, and reduces merge conflicts — and that a
catch-all common module is an anti-pattern: shared code deserves a specialized
home. It also recommends mixing feature-based and layer-based organization rather
than committing to either extreme. This kit keeps every one of those boundaries but
expresses them as `lib/` folders (owner's decision) — discipline replaces the
compiler as enforcer, and the `rwf-compliance-reviewer` agent audits it.
