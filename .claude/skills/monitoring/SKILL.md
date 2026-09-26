---
name: monitoring
description: Analytics, crash reporting, remote config feature flags, and A/B testing via wrapped Firebase services. Use when adding analytics events, screen tracking, error reporting, feature flags, remote configuration, or integrating any monitoring/observability SDK.
---

# Monitoring (analytics, crashes, feature flags)

Source: *Real-World Flutter by Tutorials* ch. 12 (Supporting the Development
Lifecycle With Firebase) & ch. 13 (A/B Testing & Feature Flags).

## The wrapping rule

**All third-party monitoring SDKs live behind thin wrapper classes in
`lib/monitoring/`. Nothing else in the codebase imports `firebase_*`.** If the
vendor is ever swapped, only this folder changes. Each wrapper is one class per
capability with a `@visibleForTesting` constructor seam:

```
lib/monitoring/
├── monitoring.dart                 # barrel + initializeMonitoringPackage()
└── src/
    ├── analytics_service.dart      # wraps FirebaseAnalytics
    ├── error_reporting_service.dart# wraps FirebaseCrashlytics
    └── remote_value_service.dart   # wraps FirebaseRemoteConfig (feature flags)
```

```dart
// monitoring.dart
export 'src/analytics_service.dart';
export 'src/error_reporting_service.dart';
export 'src/remote_value_service.dart';

Future<void> initializeMonitoringPackage() => Firebase.initializeApp();
```

Wrappers are injected top-down from `main.dart` like any other dependency — never
accessed statically from features.

## Initialization & error capture (main.dart)

Call `initializeMonitoringPackage()` before anything else, and capture **all three**
error channels (ch. 12: Crashlytics records the errors you'd otherwise miss):

```dart
void main() => runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        await initializeMonitoringPackage();
        final errorReportingService = ErrorReportingService();
        FlutterError.onError = errorReportingService.recordFlutterError;
        Isolate.current.addErrorListener(
          RawReceivePort((pair) async {
            final errorAndStacktrace = pair as List<dynamic>;
            await errorReportingService.recordError(
              errorAndStacktrace.first,
              errorAndStacktrace.last,
            );
          }).sendPort,
        );
        final remoteValueService = RemoteValueService();
        await remoteValueService.load();
        runApp(MyApp(remoteValueService: remoteValueService));
      },
      (error, stack) => ErrorReportingService().recordError(error, stack, fatal: true),
    );
```

## Screen tracking

Track screen views from a router observer reading route **names** — never from
individual screens:

```dart
class ScreenViewObserver extends NavigatorObserver {
  ScreenViewObserver({required this.analyticsService});
  final AnalyticsService analyticsService;

  void _send(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) analyticsService.setCurrentScreen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _send(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _send(previousRoute);
}
```

Register it in the router's `observers` (see `navigation` skill — this is why every
route gets a `name`). Custom events go through `analyticsService.logEvent(name,
parameters)`; give events stable snake_case names.

## Feature flags & A/B testing (ch. 13)

Remote Config lets you change app behavior **without releasing a new version**, and
A/B experiments distribute flag variants to measure what works. Pattern:

- Flag key **and default** live inside the wrapper; consumers see one typed getter:

```dart
class RemoteValueService {
  static const _gridQuotesViewEnabledKey = 'grid_quotes_view_enabled';

  Future<void> load() async {
    await _remoteConfig.setDefaults(const {_gridQuotesViewEnabledKey: true});
    await _remoteConfig.fetchAndActivate();
  }

  bool get isGridQuotesViewEnabled =>
      _remoteConfig.getBool(_gridQuotesViewEnabledKey);
}
```

- The service is injected top-down (constructor param on the Screen, wired in
  routing) and consumed as a **single ternary at the widget**:

```dart
widget.remoteValueService.isGridQuotesViewEnabled
    ? ItemPagedGridView(...)
    : ItemPagedListView(...)
```

- Never scatter `getBool(...)` string lookups through features; never branch on
  flags inside repositories or Cubits when a widget-level swap suffices.

## Hard rules

- `firebase_*` imports outside `lib/monitoring/` → violation.
- Analytics/error/flag services arrive via constructors; no singletons, no static
  access from features.
- Don't log PII in analytics events or crash keys.
- New monitoring vendor (Sentry, Mixpanel, …) → same pattern: one wrapper class in
  `lib/monitoring/`, same injected interfaces.

## Why (from the book)

Chapters 12–13, paraphrased: analytics and crash reporting are essential once an
app has a life beyond development — they surface the errors and usage patterns
you'd otherwise miss; remote config changes app behavior without shipping a new
release, and A/B experiments turn those flags into measurable product decisions.
Wrapping the SDKs keeps all that power without coupling the codebase to a vendor.
