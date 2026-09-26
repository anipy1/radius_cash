---
name: testing
description: Unit, bloc, widget, and integration testing conventions — bloc_test, mocktail, http_mock_adapter, test naming, and what to test. Use when writing or fixing any test, mocking a dependency, or deciding what tests a change requires.
---

# Testing

Source: *Real-World Flutter by Tutorials* ch. 14 (Automated Testing).
Copy-paste examples in [references/templates.md](references/templates.md).

## The three test types (ch. 14 Key Points)

| Type | Tests | Speed/cost |
|---|---|---|
| **Unit** | functions & objects: mappers, FormzInputs, Cubits/Blocs, repositories, API client | fastest — write the most |
| **Widget** | behavior & appearance of a widget (tree) | medium |
| **Integration** | complete user flows on a device, units + widgets interacting | slowest — a few critical flows |

Good coverage is the goal — but earn it bottom-up: many unit tests, fewer widget
tests, few integration tests.

## Definition of done (what every change must ship with)

- New/changed Cubit or Bloc → `bloc_test`.
- New/changed mapper → unit test per direction.
- New/changed repository method → unit test with mocked storage/API.
- New component-library widget → widget test.
- New API-client method → `http_mock_adapter` test (success + error parsing).
- New critical user flow → consider an integration test.

## Conventions

- Location mirrors `lib/`: `test/features/sign_in/sign_in_cubit_test.dart`,
  `test/repositories/user_repository/mappers_test.dart`,
  `test/component_library/favorite_icon_button_widget_test.dart`,
  `integration_test/app_test.dart`.
- File names: `<subject>_test.dart`; widget tests may use
  `<widget>_widget_test.dart`.
- Structure: `group('<Subject>:', ...)` containing tests named as
  **"When <condition>, <expected outcome>"** sentences —
  `'When sign in succeeds, emits SubmissionStatus.success'`.
- Shared setup in `setUp()`; one behavior per test.

## Mocking — mocktail only

> Kit deviation: the book mixes mockito codegen and mocktail; this kit standardizes
> on **mocktail** (no codegen, no `.mocks.dart` files).

```dart
class MockUserRepository extends Mock implements UserRepository {}

when(() => userRepository.signIn(any(), any()))
    .thenAnswer((_) async {});
when(() => userRepository.signIn(any(), any()))
    .thenThrow(InvalidCredentialsException());
```

Register fallback values for custom argument types in `setUpAll` with
`registerFallbackValue(...)`.

**Inject through the designed seams**: repositories/API/storage classes expose
`@visibleForTesting` optional constructor params (`localStorage:`, `dio:`,
`secureStorage:`, `hive:`) precisely so tests can hand in mocks — that's the
pattern's purpose. Never mock what you own outright: mock at the boundary
(repository in a cubit test; storage/API in a repository test).

## Cubit/Bloc tests — bloc_test

```dart
blocTest<SignInCubit, SignInState>(
  'When sign in fails with invalid credentials, emits invalidCredentialsError',
  setUp: () => when(() => userRepository.signIn(any(), any()))
      .thenThrow(InvalidCredentialsException()),
  build: () => SignInCubit(userRepository: userRepository),
  seed: () => const SignInState(
    email: Email.validated('a@b.com'),
    password: Password.validated('password123'),
  ),
  act: (cubit) => cubit.onSubmit(),
  expect: () => [
    isA<SignInState>().having((s) => s.submissionStatus, 'status', SubmissionStatus.inProgress),
    isA<SignInState>().having((s) => s.submissionStatus, 'status', SubmissionStatus.invalidCredentialsError),
  ],
);
```

Equatable states make `expect:` lists work with plain equality — another reason
every state extends Equatable.

## API-client tests — http_mock_adapter

Use the `@visibleForTesting Dio? dio` seam:

```dart
final dio = Dio(BaseOptions());
final dioAdapter = DioAdapter(dio: dio);
final api = AppApi(userTokenSupplier: () => Future.value(), dio: dio);

dioAdapter.onPost(url, (server) => server.reply(200, successJson), data: requestJson);
// error branch:
dioAdapter.onPost(url, (server) => server.reply(401, errorJson), data: requestJson);
expect(api.signIn(email, password), throwsA(isA<InvalidCredentialsApiException>()));
```

## Widget tests

Pump the **View** (not the Screen) — the `@visibleForTesting` View split exists for
this — inside a `MaterialApp` with l10n delegates, a fixed locale, and any required
`BlocProvider.value`/`AppTheme` wrappers:

```dart
await tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: FavoriteIconButton(isFavorite: false, onTap: () => tapped = true),
    ),
  ),
);
expect(find.byIcon(Icons.favorite_border_outlined), findsOneWidget);
await tester.tap(find.byType(FavoriteIconButton));
```

Assert through finders (`find.byType`, `find.byIcon`, `find.text`) and callback
capture — behavior, not pixels. No golden tests unless explicitly requested.

## Integration tests

```dart
IntegrationTestWidgetsFlutterBinding.ensureInitialized();
import 'package:my_app/main.dart' as app;

testWidgets('search flow', (tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await tester.enterText(find.byType(SearchBar), 'life');
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.byType(QuoteCard), findsWidgets);
});
```

Real app, real dependencies, **no mocking** — find component-library widget types
to stay resilient to copy changes. Run with
`flutter test integration_test`.

## Running

- All tests: `flutter test`
- Coverage: `flutter test --coverage`
- Always run `flutter analyze && flutter test` before declaring a task complete.
