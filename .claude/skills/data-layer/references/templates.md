# Data-Layer Templates — Worked Example: `article_repository`

A complete repository for a fictional `Article` entity, showing every file the
pattern requires. Adapt names; keep the shapes.

## File tree

```
lib/domain_models/src/article.dart
lib/domain_models/src/exceptions.dart            (add the new exceptions)
lib/remote_api/src/models/article_rm.dart
lib/local_storage/src/models/article_cm.dart
lib/repositories/article_repository/
├── article_repository.dart
└── src/
    ├── article_repository.dart
    ├── article_local_storage.dart
    └── mappers/
        ├── mappers.dart
        ├── remote_to_domain.dart
        ├── remote_to_cache.dart
        └── cache_to_domain.dart
```

## Domain model — `lib/domain_models/src/article.dart`

```dart
import 'package:equatable/equatable.dart';

class Article extends Equatable {
  const Article({required this.id, required this.title, this.isBookmarked = false});

  final int id;
  final String title;
  final bool isBookmarked;

  @override
  List<Object?> get props => [id, title, isBookmarked];
}
```

## Domain exceptions — `lib/domain_models/src/exceptions.dart`

```dart
class ArticleNotFoundException implements Exception {}

class UserAuthenticationRequiredException implements Exception {}
```

## Remote model — `lib/remote_api/src/models/article_rm.dart`

```dart
import 'package:json_annotation/json_annotation.dart';

part 'article_rm.g.dart';

@JsonSerializable(createToJson: false)
class ArticleRM {
  const ArticleRM({required this.id, required this.title, this.isBookmarked});

  @JsonKey(name: 'id')
  final int id;
  @JsonKey(name: 'title')
  final String title;
  @JsonKey(name: 'bookmarked')
  final bool? isBookmarked;

  static const fromJson = _$ArticleRMFromJson;
}
```

Request models invert the direction:

```dart
@JsonSerializable(createFactory: false)
class BookmarkArticleRequestRM {
  const BookmarkArticleRequestRM({required this.articleId});

  @JsonKey(name: 'article_id')
  final int articleId;

  Map<String, dynamic> toJson() => _$BookmarkArticleRequestRMToJson(this);
}
```

## Cache model — `lib/local_storage/src/models/article_cm.dart`

```dart
import 'package:hive_ce/hive.dart';

part 'article_cm.g.dart';

@HiveType(typeId: 3)
class ArticleCM {
  const ArticleCM({required this.id, required this.title, this.isBookmarked});

  @HiveField(0)
  final int id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final bool? isBookmarked;
}
```

Register `ArticleCMAdapter()` inside `KeyValueStorage`'s constructor and add a box
name constant + lazy box getter there.

## Mappers

`src/mappers/mappers.dart`:

```dart
export 'cache_to_domain.dart';
export 'remote_to_cache.dart';
export 'remote_to_domain.dart';
```

`src/mappers/remote_to_domain.dart`:

```dart
import 'package:my_app/domain_models/domain_models.dart';
import 'package:my_app/remote_api/remote_api.dart';

extension ArticleRMToDomain on ArticleRM {
  Article toDomainModel() =>
      Article(id: id, title: title, isBookmarked: isBookmarked ?? false);
}
```

(`remote_to_cache.dart` and `cache_to_domain.dart` follow the same one-extension-
per-file shape.)

## Local storage facade — `src/article_local_storage.dart`

```dart
class ArticleLocalStorage {
  ArticleLocalStorage({required this.keyValueStorage});

  final KeyValueStorage keyValueStorage;

  Future<ArticleCM?> getArticle(int id) async {
    final box = await keyValueStorage.articlesBox;
    return box.get(id);
  }

  Future<void> upsertArticle(ArticleCM article) async {
    final box = await keyValueStorage.articlesBox;
    await box.put(article.id, article);
  }
}
```

## Repository — `src/article_repository.dart`

```dart
import 'package:meta/meta.dart';
import 'package:my_app/domain_models/domain_models.dart';
import 'package:my_app/local_storage/local_storage.dart';
import 'package:my_app/remote_api/remote_api.dart';

import 'article_local_storage.dart';
import 'mappers/mappers.dart';

enum ArticleFetchPolicy { cacheAndNetwork, networkOnly, networkPreferably, cachePreferably }

class ArticleRepository {
  ArticleRepository({
    required KeyValueStorage keyValueStorage,
    required this.remoteApi,
    @visibleForTesting ArticleLocalStorage? localStorage,
  }) : _localStorage =
            localStorage ?? ArticleLocalStorage(keyValueStorage: keyValueStorage);

  final AppApi remoteApi;
  final ArticleLocalStorage _localStorage;

  Stream<Article> getArticle(
    int id, {
    ArticleFetchPolicy fetchPolicy = ArticleFetchPolicy.cacheAndNetwork,
  }) async* {
    final cached = fetchPolicy == ArticleFetchPolicy.networkOnly
        ? null
        : await _localStorage.getArticle(id);

    final emitCacheFirst = cached != null &&
        (fetchPolicy == ArticleFetchPolicy.cacheAndNetwork ||
            fetchPolicy == ArticleFetchPolicy.cachePreferably);
    if (emitCacheFirst) {
      yield cached.toDomainModel();
      if (fetchPolicy == ArticleFetchPolicy.cachePreferably) return;
    }

    try {
      final remote = await remoteApi.getArticle(id);
      await _localStorage.upsertArticle(remote.toCacheModel());
      yield remote.toDomainModel();
    } on ArticleNotFoundApiException {
      throw ArticleNotFoundException(); // translate at the boundary
    } catch (_) {
      if (fetchPolicy == ArticleFetchPolicy.networkPreferably && cached != null) {
        yield cached.toDomainModel();
        return;
      }
      rethrow;
    }
  }

  Future<Article> bookmarkArticle(int id) async {
    try {
      final remote = await remoteApi.bookmarkArticle(id);
      await _localStorage.upsertArticle(remote.toCacheModel()); // write-through
      return remote.toDomainModel();
    } on UserAuthRequiredApiException {
      throw UserAuthenticationRequiredException();
    }
  }
}
```

## Barrel — `article_repository.dart`

```dart
export 'src/article_repository.dart';
```

(The enum lives in the same file as the repository, so this single export exposes
both. `ArticleLocalStorage` and the mappers stay internal.)

## Reactive repository variant (user/preferences style)

```dart
class UserRepository {
  final BehaviorSubject<User?> _userSubject = BehaviorSubject();

  Stream<User?> getUser() {
    if (!_userSubject.hasValue) {
      _secureStorage.getUser().then(_userSubject.add);
    }
    return _userSubject.stream;
  }

  Future<void> signIn(String email, String password) async {
    try {
      final userRM = await remoteApi.signIn(email, password);
      await Future.wait([
        _secureStorage.upsertUserToken(userRM.token),
        _secureStorage.upsertUserInfo(userRM.email, userRM.username),
      ]);
      _userSubject.add(userRM.toDomainModel());
    } on InvalidCredentialsApiException {
      throw InvalidCredentialsException();
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _secureStorage.deleteAll(),
      _noSqlStorage.clearCaches(),
    ]);
    _userSubject.add(null);
  }
}
```
