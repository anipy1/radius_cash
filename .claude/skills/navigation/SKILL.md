---
name: navigation
description: Routing with go_router, feature decoupling via navigation callbacks, path constants, tab shells, and deep linking with App Links/Universal Links. Use when adding a screen to navigation, wiring navigation between features, setting up tabs, or implementing deep links.
---

# Navigation & Deep Linking

Source: *Real-World Flutter by Tutorials* ch. 7 (Routing & Navigating) & ch. 8
(Deep Linking). **Kit deviation**: the book uses `routemaster` (now unmaintained)
and Firebase Dynamic Links (service shut down Aug 2025). This kit keeps the book's
routing *architecture* on **go_router** + platform **App Links / Universal Links**.

## The architecture rule (unchanged from the book)

> In an app built from isolated features, all integration between features — which
> is what navigation is — belongs in a layer that sits above every feature.
> — the ch. 7 rule, paraphrased.

Concretely:
- Features **never** navigate. No `context.go(...)`, no `Navigator.push`, no route
  names inside `lib/features/`. A feature exposes callbacks
  (`onItemSelected`, `onSignUpTap`, `onAuthenticationError`) and calls them from its
  `BlocListener`s or tap handlers.
- `lib/routing/` is the **only** place that imports more than one feature. Each
  route entry constructs the feature's Screen, injects its repositories, and
  satisfies its callbacks with router calls.

## Route table shape — `lib/routing/src/routes.dart`

Keep path strings in one private constants class whose getters compose, so the same
source builds both patterns and concrete URLs:

```dart
abstract class _PathConstants {
  const _PathConstants._();

  static String get tabContainerPath => '/';
  static String get quoteListPath => '${tabContainerPath}quotes';
  static String get profileMenuPath => '${tabContainerPath}user';
  static String get signInPath => '${tabContainerPath}sign-in';
  static const idPathParameter = 'id';
  static String quoteDetailsPath({int? quoteId}) =>
      '$quoteListPath/${quoteId ?? ':$idPathParameter'}';
}
```

Build the router in a function that receives every dependency (mirrors the book's
`buildRoutingTable`), called once from `main.dart`:

```dart
GoRouter buildRouter({
  required QuoteRepository quoteRepository,
  required UserRepository userRepository,
  required AnalyticsService analyticsService,
}) =>
    GoRouter(
      observers: [ScreenViewObserver(analyticsService: analyticsService)],
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => TabContainerScreen(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: _PathConstants.quoteListPath,
                name: 'quotes-list', // route names feed analytics
                builder: (context, state) => QuoteListScreen(
                  quoteRepository: quoteRepository,
                  userRepository: userRepository,
                  onAuthenticationError: () =>
                      context.push(_PathConstants.signInPath),
                  onQuoteSelected: (id) => context
                      .push<Quote?>(_PathConstants.quoteDetailsPath(quoteId: id)),
                ),
                routes: [
                  GoRoute(
                    path: ':${_PathConstants.idPathParameter}',
                    name: 'quote-details',
                    builder: (context, state) => QuoteDetailsScreen(
                      quoteId: int.parse(
                          state.pathParameters[_PathConstants.idPathParameter]!),
                      quoteRepository: quoteRepository,
                      onAuthenticationError: (context) =>
                          context.push(_PathConstants.signInPath),
                    ),
                  ),
                ],
              ),
            ]),
            // ...profile branch
          ],
        ),
        // full-screen routes (sign-in, sign-up) outside the shell
      ],
    );
```

Rules:
- Give every route a `name` — the analytics screen-view observer logs it
  (see `monitoring` skill).
- Detail screens take path parameters (`/quotes/:id`) so every screen is
  deep-linkable — ch. 7 treats deep-link support as the test of a solid routing
  strategy.
- Results flow back through `context.push<T>` return values or callbacks, not
  shared state.
- Tabs: `StatefulShellRoute.indexedStack` (replaces the book's
  `CupertinoTabPage`), with a thin `TabContainerScreen` in `lib/routing/`.

## Deep linking (kit replacement for Dynamic Links)

Firebase Dynamic Links no longer exists. Use platform deep links pointing at the
same route paths — go_router handles incoming links automatically once the platform
is configured:

- **Android App Links**: `intent-filter` with `android:autoVerify="true"` in
  `AndroidManifest.xml` + `assetlinks.json` hosted at
  `https://<domain>/.well-known/assetlinks.json`.
- **iOS Universal Links**: Associated Domains entitlement
  (`applinks:<domain>`) + `apple-app-site-association` file on the domain.
- The book's principle still applies: handle both launch states — app **closed**
  (initial link) and app **minimized** (link stream). go_router covers both when
  configured; if handling links manually (e.g. `app_links` package), push the
  incoming path into the router exactly like the book pushed
  `dynamicLinkService.onNewDynamicLinkPath().listen(_routerDelegate.push)`.
- Share features that used to generate short Dynamic Links now share plain
  `https://<domain>/<route-path>` URLs (inject a `shareableLinkGenerator` callback
  from routing, same shape as the book).

## Why (from the book)

Chapter 7's assessment, paraphrased: Navigator 1 is easy but weak at deep linking;
Navigator 2 handles deep links well but is notoriously hard to use raw, so the
practical answer is a wrapper package that restores named-route simplicity on top
of it. The wrapper of 2026 is go_router; the decoupling architecture is unchanged.
