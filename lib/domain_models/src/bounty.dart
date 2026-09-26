import 'package:equatable/equatable.dart';

import 'geohash.dart';

enum BountyStatus {
  /// Posted, nobody accepted yet.
  open,

  /// The author accepted somebody.
  claimed,

  /// The author confirmed the work is done.
  done,

  /// The author says the money changed hands. Off-app, for now.
  paid,

  /// Withdrawn by the author.
  cancelled,
}

/// A task somebody nearby will pay for.
class Bounty extends Equatable {
  const Bounty({
    required this.id,
    required this.authorId,
    required this.authorLabel,
    required this.isMine,
    required this.title,
    required this.details,
    required this.amountCents,
    required this.createdAt,
    required this.expiresAt,
    required this.updatedAt,
    required this.status,
    required this.claimantId,
    required this.claimantLabel,
    this.geohash,
    this.viaInternet = false,
  });

  final String id;
  final String authorId;

  /// The four character label people read off a screen.
  final String authorLabel;

  /// Posted from this device.
  final bool isMine;
  final String title;
  final String details;

  /// Euro cents. The currency is fixed until there is a reason for it not to be.
  final int amountCents;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime updatedAt;
  final BountyStatus status;

  /// Who the author accepted, once they did.
  final String? claimantId;
  final String? claimantLabel;

  /// Where the poster was, as a coarse cell, when they shared it.
  final Geohash? geohash;

  /// Arrived over the internet and has never been heard on the radio, so
  /// the poster may be further away than a walk.
  final bool viaInternet;

  /// How long a poster may go without renewing an open bounty before it
  /// is shown as theirs but not vouched for. A poster republishes every two
  /// minutes on whichever path can carry it, so five missed renewals is a
  /// phone that is off, out of both radio and internet, or gone for good.
  static const posterLease = Duration(minutes: 10);

  /// Twice the lease and the bounty leaves the nearby feed. Whoever posted it
  /// cannot answer a claim, and it is kinder to hide it than to collect offers
  /// nobody will read.
  static const posterLapse = Duration(minutes: 20);

  /// Time since the poster last signed anything about this bounty. Every
  /// revision and every renewal carries a fresh updatedAt, so this is the
  /// most recent proof that the key behind it was alive.
  Duration sinceHeardFromPosterAt(DateTime now) => now.difference(updatedAt);

  /// An open bounty from somebody else whose poster has gone quiet for a
  /// lease. My own never count: I know where I am.
  bool isPosterAwayAt(DateTime now) =>
      !isMine &&
      status == BountyStatus.open &&
      sinceHeardFromPosterAt(now) >= posterLease;

  /// Quiet for two leases: treated like expired for the nearby feed.
  bool isLapsedAt(DateTime now) =>
      !isMine &&
      status == BountyStatus.open &&
      sinceHeardFromPosterAt(now) >= posterLapse;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Open, and not past its time.
  bool isClaimableAt(DateTime now) =>
      status == BountyStatus.open && !isExpiredAt(now);

  @override
  List<Object?> get props => [
    id,
    authorId,
    authorLabel,
    isMine,
    title,
    details,
    amountCents,
    createdAt,
    expiresAt,
    updatedAt,
    status,
    claimantId,
    claimantLabel,
    geohash,
    viaInternet,
  ];
}
