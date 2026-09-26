# State-Management Templates

Two complete feature skeletons: a Cubit feature (form-shaped) and a Bloc feature
(list with search). Names use fictional features; keep the shapes.

## 1. Cubit feature — `lib/features/edit_note/`

### `edit_note.dart` (barrel)

```dart
export 'src/edit_note_screen.dart';
```

### `src/edit_note_cubit.dart`

```dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_app/domain_models/domain_models.dart';
import 'package:my_app/repositories/note_repository/note_repository.dart';

part 'edit_note_state.dart';

class EditNoteCubit extends Cubit<EditNoteState> {
  EditNoteCubit({required this.noteRepository}) : super(const EditNoteState());

  final NoteRepository noteRepository;

  void onTitleChanged(String value) =>
      emit(state.copyWith(title: value, submissionStatus: SubmissionStatus.idle));

  Future<void> onSubmit() async {
    emit(state.copyWith(submissionStatus: SubmissionStatus.inProgress));
    try {
      await noteRepository.saveNote(state.title);
      emit(state.copyWith(submissionStatus: SubmissionStatus.success));
    } on UserAuthenticationRequiredException {
      emit(state.copyWith(submissionStatus: SubmissionStatus.authError));
    } catch (_) {
      emit(state.copyWith(submissionStatus: SubmissionStatus.genericError));
    }
  }
}
```

### `src/edit_note_state.dart`

```dart
part of 'edit_note_cubit.dart';

class EditNoteState extends Equatable {
  const EditNoteState({this.title = '', this.submissionStatus = SubmissionStatus.idle});

  final String title;
  final SubmissionStatus submissionStatus;

  EditNoteState copyWith({String? title, SubmissionStatus? submissionStatus}) =>
      EditNoteState(
        title: title ?? this.title,
        submissionStatus: submissionStatus ?? this.submissionStatus,
      );

  @override
  List<Object?> get props => [title, submissionStatus];
}

enum SubmissionStatus { idle, inProgress, success, authError, genericError }
```

### `src/edit_note_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/component_library/component_library.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/repositories/note_repository/note_repository.dart';

import 'edit_note_cubit.dart';

class EditNoteScreen extends StatelessWidget {
  const EditNoteScreen({
    required this.noteRepository,
    required this.onSaveSuccess,
    required this.onAuthenticationError,
    super.key,
  });

  final NoteRepository noteRepository;
  final VoidCallback onSaveSuccess;
  final VoidCallback onAuthenticationError;

  @override
  Widget build(BuildContext context) => BlocProvider<EditNoteCubit>(
        create: (_) => EditNoteCubit(noteRepository: noteRepository),
        child: EditNoteView(
          onSaveSuccess: onSaveSuccess,
          onAuthenticationError: onAuthenticationError,
        ),
      );
}

@visibleForTesting
class EditNoteView extends StatelessWidget {
  const EditNoteView({
    required this.onSaveSuccess,
    required this.onAuthenticationError,
    super.key,
  });

  final VoidCallback onSaveSuccess;
  final VoidCallback onAuthenticationError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return BlocConsumer<EditNoteCubit, EditNoteState>(
      listenWhen: (old, current) => old.submissionStatus != current.submissionStatus,
      listener: (context, state) {
        switch (state.submissionStatus) {
          case SubmissionStatus.success:
            onSaveSuccess();
          case SubmissionStatus.authError:
            onAuthenticationError();
          case SubmissionStatus.genericError:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const GenericErrorSnackBar());
          case _:
            break;
        }
      },
      builder: (context, state) {
        final cubit = context.read<EditNoteCubit>();
        final isBusy = state.submissionStatus == SubmissionStatus.inProgress;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.editNoteAppBarTitle)),
          body: Padding(
            padding: EdgeInsets.all(theme.screenMargin),
            child: Column(
              children: [
                TextField(enabled: !isBusy, onChanged: cubit.onTitleChanged),
                const SizedBox(height: Spacing.mediumLarge),
                isBusy
                    ? ExpandedElevatedButton.inProgress(label: l10n.editNoteSaveButtonLabel)
                    : ExpandedElevatedButton(
                        label: l10n.editNoteSaveButtonLabel,
                        onTap: cubit.onSubmit,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

## 2. Bloc feature — `lib/features/article_list/`

### `src/article_list_bloc.dart`

```dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_app/domain_models/domain_models.dart';
import 'package:my_app/repositories/article_repository/article_repository.dart';
import 'package:my_app/repositories/user_repository/user_repository.dart';
import 'package:rxdart/rxdart.dart';

part 'article_list_event.dart';
part 'article_list_state.dart';

class ArticleListBloc extends Bloc<ArticleListEvent, ArticleListState> {
  ArticleListBloc({
    required this.articleRepository,
    required UserRepository userRepository,
  }) : super(const ArticleListState()) {
    on<ArticleListEvent>(
      (event, emit) => switch (event) {
        ArticleListStarted() ||
        ArticleListRefreshed() =>
          _onRefresh(emit, ArticleFetchPolicy.cacheAndNetwork),
        ArticleListSearchTermChanged(:final term) => _onSearch(term, emit),
        ArticleListNextPageRequested(:final page) => _onNextPage(page, emit),
      },
      transformer: (events, mapper) {
        final debounced = events
            .whereType<ArticleListSearchTermChanged>()
            .debounceTime(const Duration(seconds: 1));
        final rest = events.where((e) => e is! ArticleListSearchTermChanged);
        return restartable<ArticleListEvent>()(MergeStream([rest, debounced]), mapper);
      },
    );

    _authChangesSubscription = userRepository
        .getUser()
        .map((user) => user?.username)
        .distinct()
        .listen((_) => add(const ArticleListRefreshed()));

    add(const ArticleListStarted());
  }

  final ArticleRepository articleRepository;
  late final StreamSubscription _authChangesSubscription;

  // _onRefresh/_onSearch/_onNextPage: call the repository (choosing a fetch
  // policy), emit InProgress → Success/Failure states, await emit.onEach for
  // multi-emission streams.

  @override
  Future<void> close() {
    _authChangesSubscription.cancel();
    return super.close();
  }
}
```

### `src/article_list_event.dart`

```dart
part of 'article_list_bloc.dart';

sealed class ArticleListEvent extends Equatable {
  const ArticleListEvent();
  @override
  List<Object?> get props => [];
}

class ArticleListStarted extends ArticleListEvent {
  const ArticleListStarted();
}

class ArticleListRefreshed extends ArticleListEvent {
  const ArticleListRefreshed();
}

class ArticleListSearchTermChanged extends ArticleListEvent {
  const ArticleListSearchTermChanged(this.term);
  final String term;
  @override
  List<Object?> get props => [term];
}

class ArticleListNextPageRequested extends ArticleListEvent {
  const ArticleListNextPageRequested(this.page);
  final int page;
  @override
  List<Object?> get props => [page];
}
```

### `src/article_list_state.dart` (single class + auxiliary constructors style)

```dart
part of 'article_list_bloc.dart';

class ArticleListState extends Equatable {
  const ArticleListState({
    this.itemList,
    this.nextPage,
    this.error,
    this.searchTerm = '',
    this.refreshError,
  });

  const ArticleListState.loadingNewSearch(String searchTerm)
      : this(searchTerm: searchTerm);

  final List<Article>? itemList;
  final int? nextPage;
  final dynamic error;
  final String searchTerm;
  final dynamic refreshError;

  ArticleListState copyWithNewError(dynamic error) => ArticleListState(
        itemList: itemList,
        nextPage: nextPage,
        error: error,
        searchTerm: searchTerm,
      );

  @override
  List<Object?> get props => [itemList, nextPage, error, searchTerm, refreshError];
}
```

### Phase-shaped state alternative (detail screens)

```dart
sealed class ArticleDetailsState extends Equatable {
  const ArticleDetailsState();
  @override
  List<Object?> get props => [];
}

class ArticleDetailsInProgress extends ArticleDetailsState {}

class ArticleDetailsSuccess extends ArticleDetailsState {
  const ArticleDetailsSuccess({required this.article});
  final Article article;
  @override
  List<Object?> get props => [article];
}

class ArticleDetailsFailure extends ArticleDetailsState {}
```

View side, with exhaustive switch (why we use `sealed`):

```dart
BlocBuilder<ArticleDetailsCubit, ArticleDetailsState>(
  builder: (context, state) => switch (state) {
    ArticleDetailsInProgress() => const CenteredCircularProgressIndicator(),
    ArticleDetailsSuccess(:final article) => _ArticleBody(article: article),
    ArticleDetailsFailure() => ExceptionIndicator(
        onTryAgain: () => context.read<ArticleDetailsCubit>().refetch(),
      ),
  },
)
```
