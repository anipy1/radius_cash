---
name: data-layer
description: Repository pattern, RM/CM/domain model separation, mappers, fetch policies, caching, Dio API client, Hive storage, secure storage, and auth-token flow. Use when integrating an API, creating or modifying a repository, adding models, caching data, persisting anything, or handling authentication tokens.
---

# Data Layer

Source: *Real-World Flutter by Tutorials* ch. 2 (Repository Pattern) & ch. 6
(Authenticating Users). Full worked example in [references/templates.md](references/templates.md).

## Repositories

- A repository is **an orchestrator of data sources**: it abstracts where data comes
  from (network, cache) away from state managers. It becomes indispensable the moment
  an operation involves more than one source — the classic case is caching API results.
- One folder per data domain: `lib/repositories/<entity>_repository/`. Features never
  touch `remote_api/` or `local_storage/` directly — the repository is the single
  access point.
- Constructor takes the shared infrastructure (`remoteApi`, `keyValueStorage`) and
  builds its own private local-storage facade, with a `@visibleForTesting` seam:

```dart
class QuoteRepository {
  QuoteRepository({
    required KeyValueStorage keyValueStorage,
    required this.remoteApi,
    @visibleForTesting QuoteLocalStorage? localStorage,
  }) : _localStorage =
            localStorage ?? QuoteLocalStorage(keyValueStorage: keyValueStorage);
}
```

### Return types
- `Future<T>` for one-shot operations (submit a form, fetch one item network-only).
- `Stream<T>` when more than one value can be emitted: fetch policies that yield
  cache **then** network, or reactive app state (`BehaviorSubject` — see below).
- Always return **domain models**. `*RM`/`*CM` types must never escape the repository.

### Fetch policies
When one loading strategy isn't enough, let the **caller** choose per call:

```dart
enum QuoteListPageFetchPolicy {
  cacheAndNetwork,    // emit cache first (if any), then fetch & emit fresh
  networkOnly,        // skip cache entirely
  networkPreferably,  // try network; on failure fall back to cache
  cachePreferably,    // emit cache if present; only fetch when cache is empty
}

Stream<QuoteListPage> getQuoteListPage(
  int pageNumber, {
  required QuoteListPageFetchPolicy fetchPolicy,
}) async* {
  final cachedPage = await _localStorage.getQuoteListPage(pageNumber);
  final shouldEmitCacheInAdvance =
      fetchPolicy == QuoteListPageFetchPolicy.cacheAndNetwork ||
          fetchPolicy == QuoteListPageFetchPolicy.cachePreferably;
  if (shouldEmitCacheInAdvance && cachedPage != null) {
    yield cachedPage.toDomainModel();
    if (fetchPolicy == QuoteListPageFetchPolicy.cachePreferably) return;
  }
  try {
    final freshPage = await _getFromNetworkAndUpdateCache(pageNumber);
    yield freshPage;
  } catch (_) {
    if (fetchPolicy == QuoteListPageFetchPolicy.networkPreferably &&
        cachedPage != null) {
      yield cachedPage.toDomainModel();
      return;
    }
    rethrow;
  }
}
```

Skip the cache lookup entirely when the request is search/filtered (don't cache
volatile filtered results) — map those straight `remote_to_domain`.

### Exception translation (the repository's job)
Catch every data-source exception and rethrow the matching domain exception —
one-for-one. Features must only ever see `domain_models` exceptions:

```dart
try {
  return (await remoteApi.signIn(email, password)).toDomainModel();
} on InvalidCredentialsApiException {
  throw InvalidCredentialsException();
}
```

Domain exceptions are simple marker classes in
`lib/domain_models/src/exceptions.dart`:
`class InvalidCredentialsException implements Exception {}`.

### Write-through caching
Mutations (favorite, upvote…) call the network, then update the cache from the
response so caches never go stale. Use a private extension on `Future<XRM>` to share
that logic across sibling mutation methods and invalidate dependent cached lists
(e.g. clearing the favorites list cache after un/favoriting).

## Three model families

| Family | Suffix | Lives in | Serialization |
|---|---|---|---|
| Remote | `RM` | `lib/remote_api/src/models/` | `@JsonSerializable` |
| Cache | `CM` | `lib/local_storage/src/models/` | Hive `@HiveType`/`@HiveField` |
| Domain | none | `lib/domain_models/` | none — pure Dart + `Equatable` |

- Response RMs: `@JsonSerializable(createToJson: false)` (read-only).
  Request RMs: `@JsonSerializable(createFactory: false)` (write-only).
- Domain models are immutable (`const` constructors, `final` fields), extend
  `Equatable`, list all fields in `props`, use enums for finite value sets.
- **Every data source needs its own models**; mappers convert them to neutral domain
  models so implementation details never leak (ch. 2 Key Points).

## Mappers

Extension methods, in the repository's `src/mappers/`, **one file per direction**,
aggregated by an internal `mappers.dart` barrel, never exported:

```dart
// src/mappers/cache_to_domain.dart
extension QuoteCMToDomain on QuoteCM {
  Quote toDomainModel() => Quote(id: id, body: body, author: author);
}
```

Directions as needed: `remote_to_cache`, `cache_to_domain`, `remote_to_domain`,
`domain_to_remote` (and `domain_to_cache` for preference-style repositories).

## Reactive app state (BehaviorSubject)

For state multiple screens observe (signed-in user, dark-mode preference), the
repository holds a `BehaviorSubject` from rxdart, hydrated lazily from storage on
first listen, and exposes it as a `Stream`:

```dart
final BehaviorSubject<User?> _userSubject = BehaviorSubject();

Stream<User?> getUser() {
  if (!_userSubject.hasValue) _hydrateUserFromStorage();
  return _userSubject.stream;
}
```

Sign-in: call API → persist token to secure storage → `_userSubject.add(user)`.
Sign-out: clear secure storage + caches → `_userSubject.add(null)`.

## Remote API (`lib/remote_api/`)

- Single Dio-based client class. The **app token** (compile-time secret) goes in base
  headers; the **user token** is fetched per request via an injected supplier:

```dart
typedef UserTokenSupplier = Future<String?> Function();

extension on Dio {
  void setUpAuthHeaders(UserTokenSupplier userTokenSupplier) {
    const appToken = String.fromEnvironment('app-token');
    options = BaseOptions(headers: {'Authorization': 'Token token=$appToken'});
    interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) async {
        final userToken = await userTokenSupplier();
        if (userToken != null) options.headers['User-Token'] = userToken;
        handler.next(options);
      }),
    );
  }
}
```

- API-specific exceptions (`InvalidCredentialsApiException`, …) are defined here and
  thrown by parsing error responses; they never cross the repository boundary.
- URL construction goes in a `UrlBuilder` class, not inline strings.
- Keep a `@visibleForTesting Dio? dio` constructor seam for `http_mock_adapter`.

## Local storage (`lib/local_storage/`)

- One `KeyValueStorage` class wraps Hive: owns all box name constants, registers all
  CM adapters in its constructor, exposes boxes as lazy getters. Nothing else opens
  boxes. Guard against double instantiation (adapters register once).
- Caches → temporary directory; user preferences → application documents directory
  (`path_provider`).
- Keep a `@visibleForTesting HiveInterface? hive` seam.

## Secrets & sensitive data

- Never store users' private data (JWTs, PII) in regular databases — use
  `flutter_secure_storage` (Keychain/Keystore) via a `UserSecureStorage` wrapper
  inside the user repository (ch. 6 Key Points).
- API keys never live in code: pass with
  `flutter run --dart-define=app-token=YOUR_KEY`, read with
  `String.fromEnvironment` (ch. 1 Key Points).

## Codegen

After changing any `@JsonSerializable` or Hive-annotated model:
`dart run build_runner build --delete-conflicting-outputs`.

## Why (from the book)

Chapter 2's core lessons, paraphrased: the repository's job is to orchestrate data
sources so state managers never know where data came from; caching makes the app
faster, cheaper on data, and usable offline; when one loading strategy can't fit
every screen, expose the choice to the caller as a fetch policy; and reach for a
Stream instead of a Future whenever an operation can produce more than one result.
