part of 'bounty_create_cubit.dart';

enum SubmissionStatus {
  idle,
  inProgress,
  success,
  validationError,
  meshNotRunningError,
  sendError,
  cacheError,
  genericError,
}

class BountyCreateState extends Equatable {
  const BountyCreateState({
    required this.expiry,
    this.title = const BountyTitle.unvalidated(),
    this.details = const BountyDetails.unvalidated(),
    this.amount = const EuroAmount.unvalidated(),
    this.expiryPreset = BountyExpiry.defaultPreset,
    this.submissionStatus = SubmissionStatus.idle,
    this.postedBountyId,
  });

  /// The default expiry is the default preset from [now].
  factory BountyCreateState.initial(DateTime now) => BountyCreateState(
    expiry: BountyExpiry.unvalidated(
      now.add(BountyExpiry.defaultPreset),
      now: now,
    ),
  );

  final BountyTitle title;
  final BountyDetails details;
  final EuroAmount amount;
  final BountyExpiry expiry;

  /// Which preset chip is lit, or null when the user picked a moment.
  final Duration? expiryPreset;
  final SubmissionStatus submissionStatus;
  final String? postedBountyId;

  BountyCreateState copyWith({
    BountyTitle? title,
    BountyDetails? details,
    EuroAmount? amount,
    BountyExpiry? expiry,
    Duration? expiryPreset,
    bool clearPreset = false,
    SubmissionStatus? submissionStatus,
    String? postedBountyId,
  }) => BountyCreateState(
    title: title ?? this.title,
    details: details ?? this.details,
    amount: amount ?? this.amount,
    expiry: expiry ?? this.expiry,
    expiryPreset: clearPreset ? null : (expiryPreset ?? this.expiryPreset),
    submissionStatus: submissionStatus ?? this.submissionStatus,
    postedBountyId: postedBountyId ?? this.postedBountyId,
  );

  @override
  List<Object?> get props => [
    title,
    details,
    amount,
    expiry,
    expiryPreset,
    submissionStatus,
    postedBountyId,
  ];
}
