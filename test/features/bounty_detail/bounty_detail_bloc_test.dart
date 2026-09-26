import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/bounty_detail/src/bounty_detail_bloc.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';

class MockBountyRepository extends Mock implements BountyRepository {}

Bounty bounty(
  String id, {
  bool isMine = false,
  BountyStatus status = BountyStatus.open,
}) => Bounty(
  id: id,
  authorId: isMine ? 'me' : 'them',
  authorLabel: 'ABCD',
  isMine: isMine,
  title: 't',
  details: '',
  amountCents: 100,
  createdAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2027),
  updatedAt: DateTime.utc(2026),
  status: status,
  claimantId: null,
  claimantLabel: null,
);

Claim claim(String bountyId, {bool isMine = false}) => Claim(
  bountyId: bountyId,
  claimantId: isMine ? 'me' : 'x',
  claimantLabel: 'XXXX',
  note: '',
  sentAt: DateTime.utc(2026),
  status: ClaimStatus.pending,
  isMine: isMine,
);

void main() {
  group('BountyDetailBloc:', () {
    late MockBountyRepository repository;
    late StreamController<List<Bounty>> bounties;
    late StreamController<List<Claim>> claims;

    setUp(() {
      repository = MockBountyRepository();
      bounties = StreamController();
      claims = StreamController();
      when(repository.getBounties).thenAnswer((_) => bounties.stream);
      when(repository.getClaims).thenAnswer((_) => claims.stream);
    });

    BountyDetailBloc build() =>
        BountyDetailBloc(bountyId: 'b', bountyRepository: repository);

    final target = bounty('b');
    final loaded = BountyDetailSuccess(bounty: target, claims: const []);

    blocTest<BountyDetailBloc, BountyDetailState>(
      'When the repository has the bounty, shows it with its claims only',
      build: build,
      act: (_) async {
        bounties.add([bounty('other'), target]);
        claims.add([claim('other'), claim('b')]);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        loaded,
        loaded.copyWith(claims: [claim('b')]),
      ],
    );

    blocTest<BountyDetailBloc, BountyDetailState>(
      'When the bounty is not known, fails',
      build: build,
      act: (_) async {
        bounties.add([bounty('other')]);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [const BountyDetailFailure()],
    );

    blocTest<BountyDetailBloc, BountyDetailState>(
      'When claiming, goes busy then idle and calls the repository',
      setUp: () => when(
        () => repository.claim('b', note: 'soon'),
      ).thenAnswer((_) async {}),
      build: build,
      seed: () => loaded,
      act: (bloc) => bloc.add(const BountyDetailClaimRequested(note: 'soon')),
      expect: () => [
        loaded.copyWith(actionStatus: ActionStatus.inProgress),
        loaded,
      ],
      verify: (_) =>
          verify(() => repository.claim('b', note: 'soon')).called(1),
    );

    blocTest<BountyDetailBloc, BountyDetailState>(
      'When the bounty closed underneath, says so',
      setUp: () => when(
        () => repository.claim('b', note: ''),
      ).thenThrow(BountyClosedException()),
      build: build,
      seed: () => loaded,
      act: (bloc) => bloc.add(const BountyDetailClaimRequested()),
      expect: () => [
        loaded.copyWith(actionStatus: ActionStatus.inProgress),
        loaded.copyWith(actionStatus: ActionStatus.closedError),
      ],
    );

    blocTest<BountyDetailBloc, BountyDetailState>(
      'When an action outcome lands after the stream moved on, it is applied to the newer state',
      setUp: () => when(() => repository.accept('b', 'x')).thenAnswer((
        _,
      ) async {
        bounties.add([bounty('b', isMine: true, status: BountyStatus.claimed)]);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        throw BountySendException();
      }),
      build: build,
      seed: () => loaded,
      act: (bloc) => bloc.add(const BountyDetailAcceptRequested('x')),
      wait: const Duration(milliseconds: 20),
      expect: () => [
        loaded.copyWith(actionStatus: ActionStatus.inProgress),
        isA<BountyDetailSuccess>()
            .having((s) => s.bounty.status, 'status', BountyStatus.claimed)
            .having((s) => s.actionStatus, 'action', ActionStatus.inProgress),
        isA<BountyDetailSuccess>()
            .having((s) => s.bounty.status, 'status', BountyStatus.claimed)
            .having((s) => s.actionStatus, 'action', ActionStatus.sendError),
      ],
    );

    blocTest<BountyDetailBloc, BountyDetailState>(
      'When the error was shown, status goes back to idle',
      build: build,
      seed: () => loaded.copyWith(actionStatus: ActionStatus.sendError),
      act: (bloc) => bloc.add(const BountyDetailErrorShown()),
      expect: () => [loaded],
    );

    test('myClaim picks out mine', () {
      final s = BountyDetailSuccess(
        bounty: target,
        claims: [claim('b'), claim('b', isMine: true)],
      );
      expect(s.myClaim?.isMine, isTrue);
    });
  });
}
