# Testing Templates

One ready-to-adapt example per test kind, mocktail throughout.

## 1. Mapper unit test — `test/repositories/user_repository/mappers_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/domain_models/domain_models.dart';
import 'package:my_app/local_storage/local_storage.dart';

// mappers are internal to the repository; tests may import them directly
import 'package:my_app/repositories/user_repository/src/mappers/mappers.dart';

void main() {
  group('User mappers:', () {
    test(
      'When mapping DarkModePreference.alwaysDark to CM, returns DarkModePreferenceCM.alwaysDark',
      () {
        expect(
          DarkModePreference.alwaysDark.toCacheModel(),
          DarkModePreferenceCM.alwaysDark,
        );
      },
    );
  });
}
```

## 2. Cubit test — `test/features/sign_in/sign_in_cubit_test.dart`

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/domain_models/domain_models.dart';
import 'package:my_app/features/sign_in/src/sign_in_cubit.dart';
import 'package:my_app/form_fields/form_fields.dart';
import 'package:my_app/repositories/user_repository/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  group('SignInCubit:', () {
    late MockUserRepository userRepository;

    setUp(() => userRepository = MockUserRepository());

    SignInCubit buildCubit() => SignInCubit(userRepository: userRepository);

    const validState = SignInState(
      email: Email.validated('user@example.com'),
      password: Password.validated('password123'),
    );

    blocTest<SignInCubit, SignInState>(
      'When sign in completes successfully, emits inProgress then success',
      setUp: () => when(() => userRepository.signIn(any(), any()))
          .thenAnswer((_) async {}),
      build: buildCubit,
      seed: () => validState,
      act: (cubit) => cubit.onSubmit(),
      expect: () => [
        validState.copyWith(submissionStatus: SubmissionStatus.inProgress),
        validState.copyWith(submissionStatus: SubmissionStatus.success),
      ],
    );

    blocTest<SignInCubit, SignInState>(
      'When credentials are invalid, emits invalidCredentialsError',
      setUp: () => when(() => userRepository.signIn(any(), any()))
          .thenThrow(InvalidCredentialsException()),
      build: buildCubit,
      seed: () => validState,
      act: (cubit) => cubit.onSubmit(),
      expect: () => [
        validState.copyWith(submissionStatus: SubmissionStatus.inProgress),
        validState.copyWith(submissionStatus: SubmissionStatus.invalidCredentialsError),
      ],
    );
  });
}
```

## 3. Repository unit test — `test/repositories/user_repository/user_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/local_storage/local_storage.dart';
import 'package:my_app/remote_api/remote_api.dart';
import 'package:my_app/repositories/user_repository/user_repository.dart';
import 'package:my_app/repositories/user_repository/src/user_secure_storage.dart';

class MockUserSecureStorage extends Mock implements UserSecureStorage {}
class MockAppApi extends Mock implements AppApi {}
class MockKeyValueStorage extends Mock implements KeyValueStorage {}

void main() {
  group('UserRepository:', () {
    test('When user is not authenticated, getUserToken returns null', () async {
      final secureStorage = MockUserSecureStorage();
      when(secureStorage.getUserToken).thenAnswer((_) async => null);

      final repository = UserRepository(
        remoteApi: MockAppApi(),
        noSqlStorage: MockKeyValueStorage(),
        secureStorage: secureStorage, // @visibleForTesting seam
      );

      expect(await repository.getUserToken(), isNull);
    });
  });
}
```

## 4. API-client test — `test/remote_api/sign_in_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/remote_api/remote_api.dart';

void main() {
  group('Sign in:', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late AppApi api;

    setUp(() {
      dio = Dio(BaseOptions());
      dioAdapter = DioAdapter(dio: dio);
      api = AppApi(userTokenSupplier: () => Future.value(), dio: dio);
    });

    test('When call completes successfully, returns an instance of UserRM', () async {
      const url = 'https://api.example.com/session';
      dioAdapter.onPost(
        url,
        (server) => server.reply(200, {'User-Token': 'token', 'login': 'user', 'email': 'user@example.com'}),
        data: {'user': {'login': 'user@example.com', 'password': 'password'}},
      );

      expect(await api.signIn('user@example.com', 'password'), isA<UserRM>());
    });

    test('When credentials are wrong, throws InvalidCredentialsApiException', () async {
      const url = 'https://api.example.com/session';
      dioAdapter.onPost(
        url,
        (server) => server.reply(200, {'error_code': 21, 'message': 'Invalid login or password.'}),
        data: {'user': {'login': 'user@example.com', 'password': 'wrong'}},
      );

      expect(
        api.signIn('user@example.com', 'wrong'),
        throwsA(isA<InvalidCredentialsApiException>()),
      );
    });
  });
}
```

## 5. Widget test — `test/component_library/favorite_icon_button_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/component_library/component_library.dart';
import 'package:my_app/l10n/app_localizations.dart';

void main() {
  group('FavoriteIconButton:', () {
    testWidgets(
      'When isFavorite is false, shows the outlined heart and reports taps',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FavoriteIconButton(
                isFavorite: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.favorite_border_outlined), findsOneWidget);
        await tester.tap(find.byType(FavoriteIconButton));
        expect(tapped, isTrue);
      },
    );
  });
}
```

For a feature View, wrap with the mocked bloc:

```dart
class MockSignInCubit extends MockCubit<SignInState> implements SignInCubit {}

await tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: BlocProvider<SignInCubit>.value(
      value: cubit..let((c) => whenListen(c, Stream.value(const SignInState()), initialState: const SignInState())),
      child: SignInView(onSignInSuccess: () {}),
    ),
  ),
);
```

## 6. Integration test — `integration_test/app_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/component_library/component_library.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end:', () {
    testWidgets('When searching, results appear in the list', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.enterText(find.byType(SearchBar), 'life');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(QuoteCard), findsWidgets);
    });
  });
}
```
