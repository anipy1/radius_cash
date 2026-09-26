---
name: state-management
description: Cubit vs Bloc decision, state class modeling, Screen/View split, BlocBuilder/BlocListener/BlocConsumer usage, event transformers, and repository-stream subscriptions. Use when building any screen, writing business logic, creating Cubits/Blocs/state classes, or handling loading/error/success UI states.
---

# State Management (bloc library)

Source: *Real-World Flutter by Tutorials* ch. 3 (Cubits) & ch. 5 (Blocs).
Full skeletons in [references/templates.md](references/templates.md).

## What Cubits/Blocs are for

A Bloc or Cubit takes **everything that isn't capturing user input or building
widgets** out of your widget code. Widgets stay dumb; the state manager talks to
repositories and emits states.

## Cubit vs Bloc — the decision rule

> Default to a Cubit for its simplicity. Upgrade to a Bloc only when the feature
> must **control how incoming events are processed** (order, timing, cancellation).
> — the ch. 5 rule, paraphrased.

Use a **Bloc** when the feature needs any of:
- event debouncing (search-as-you-type),
- `restartable()` / other `bloc_concurrency` transformers (new event cancels
  in-flight work),
- reacting to repository streams (auth state, preferences) by funneling them into
  events.

Otherwise use a **Cubit** (forms, detail screens, simple async flows). One isn't
better than the other; a Bloc without a custom transformer behaves exactly like a
Cubit with more boilerplate.

## File shape

```
src/<feature>_cubit.dart      // or <feature>_bloc.dart
src/<feature>_state.dart      // part of the cubit/bloc file
src/<feature>_event.dart      // blocs only; part of the bloc file
```

State/event files start with `part of '<feature>_bloc.dart';` — they are never
standalone libraries and are never exported from the feature barrel.

## Modeling state classes (all extend Equatable)

**Form-shaped screens** (same layout always visible) → single class + `copyWith` +
`SubmissionStatus`:

```dart
class SignInState extends Equatable {
  const SignInState({
    this.email = const Email.unvalidated(),
    this.password = const Password.unvalidated(),
    this.submissionStatus = SubmissionStatus.idle,
  });

  final Email email;
  final Password password;
  final SubmissionStatus submissionStatus;

  SignInState copyWith({Email? email, Password? password, SubmissionStatus? submissionStatus}) =>
      SignInState(
        email: email ?? this.email,
        password: password ?? this.password,
        submissionStatus: submissionStatus ?? this.submissionStatus,
      );

  @override
  List<Object?> get props => [email, password, submissionStatus];
}

enum SubmissionStatus { idle, inProgress, success, genericError, invalidCredentialsError }
```

**Phase-shaped screens** (loading → data/error swap the whole layout) → `sealed`
hierarchy (kit modernization of the book's `abstract` base; same naming):

```dart
sealed class QuoteDetailsState extends Equatable {
  const QuoteDetailsState();
  @override
  List<Object?> get props => [];
}

class QuoteDetailsInProgress extends QuoteDetailsState {}

class QuoteDetailsSuccess extends QuoteDetailsState {
  const QuoteDetailsSuccess({required this.quote});
  final Quote quote;
  @override
  List<Object?> get props => [quote];
}

class QuoteDetailsFailure extends QuoteDetailsState {}
```

Complex list states may combine both styles: one class with named auxiliary
constructors (`.loadingNewTag()`, `.noItemsFound()`) plus targeted copy helpers
(`copyWithNewError`, `copyWithUpdatedItem`).

Name loading states `InProgress`, loaded states `Success`/`Loaded`, error states
`Failure`. Name Bloc events as past-tense user actions:
`QuoteListSearchTermChanged`, `ProfileMenuSignedOut`.

## The Screen/View split (every feature)

```dart
class SignInScreen extends StatelessWidget {           // public — in the barrel
  const SignInScreen({required this.userRepository, required this.onSignInSuccess, super.key});
  final UserRepository userRepository;
  final VoidCallback onSignInSuccess;

  @override
  Widget build(BuildContext context) => BlocProvider<SignInCubit>(
        create: (_) => SignInCubit(userRepository: userRepository),
        child: SignInView(onSignInSuccess: onSignInSuccess),
      );
}

@visibleForTesting
class SignInView extends StatelessWidget { /* the actual UI */ }
```

- Screen: takes repositories + navigation callbacks, owns the `BlocProvider`.
- View: `@visibleForTesting` so widget tests pump it directly with a mocked cubit.
- Inside the View, the first lines of `build` are
  `final l10n = AppLocalizations.of(context);` and
  `final theme = AppTheme.of(context);`.
- Dispatch with `context.read<SignInCubit>().method()` (or a `_bloc` getter in a
  StatefulWidget's State).

## BlocBuilder vs BlocListener vs BlocConsumer (ch. 3 rules)

- `BlocBuilder` → rebuild UI from state. Nothing else.
- **Never** show a snackbar/dialog or navigate from a builder — that's a one-off
  side effect: use `BlocListener` with a `listenWhen` guard
  (`(old, new) => old.submissionStatus != new.submissionStatus`).
- Need both → combine into a single `BlocConsumer`.
- Navigation from a listener means **calling the callback prop**
  (`onSignInSuccess()`), never `Navigator`/router calls inside the feature.
- UX rule: errors while **retrieving** data → error-state widget (with retry) in
  the layout; errors while **sending** data → snackbar or dialog.

## Bloc event transformers

Debounce only what needs debouncing, merge the rest, and make handlers restartable
so a newer event cancels stale in-flight work:

```dart
QuoteListBloc(...) : super(const QuoteListState()) {
  on<QuoteListEvent>(
    _handler,
    transformer: (events, mapper) {
      final debounced = events
          .whereType<QuoteListSearchTermChanged>()
          .debounceTime(const Duration(seconds: 1));
      final rest = events.where((e) => e is! QuoteListSearchTermChanged);
      return restartable<QuoteListEvent>()(MergeStream([rest, debounced]), mapper);
    },
  );
}
```

## Subscribing to repository streams

Blocs bridge repository streams into events in the constructor and clean up in
`close()`:

```dart
late final StreamSubscription _authSub;

QuoteListBloc({required UserRepository userRepository, ...}) : super(...) {
  _authSub = userRepository
      .getUser()
      .map((user) => user?.username)
      .distinct()
      .listen((username) => add(QuoteListUsernameObtained(username)));
}

@override
Future<void> close() {
  _authSub.cancel();
  return super.close();
}
```

(Alternatively `emit.onEach`/`emit.forEach` inside a handler with a `flatMap`
transformer, as the book's profile-menu Bloc does.)

## Hard rules

- Cubits/Blocs receive repositories via constructor (injected by the Screen).
  They never construct repositories, never touch `remote_api`/`local_storage`,
  and only catch **domain** exceptions.
- `Equatable` on every state — enables unit testing and prevents needless rebuilds
  (ch. 3 Key Points).
- Reset `SubmissionStatus` to `idle` after the listener shows an error so the user
  can retry.
- One Cubit/Bloc per feature; scoped by that feature's `BlocProvider`. No global
  blocs.

## Why (from the book)

Chapters 3 and 5, paraphrased: a Cubit is simply a slimmer Bloc — the only real
difference is the event channel (a Cubit takes one function per event, a Bloc one
class per event), so neither is inherently better. The single legitimate reason to
pay a Bloc's extra boilerplate is the ability to customize how its event stream is
processed — which is exactly what debouncing and restartable handlers require.
