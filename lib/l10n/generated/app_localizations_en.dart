// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Radius';

  @override
  String get bountyFeedAppBarTitle => 'Radius';

  @override
  String get bountyFeedSegmentNearby => 'Nearby';

  @override
  String get bountyFeedSegmentMine => 'Mine';

  @override
  String get bountyFeedSegmentClaimed => 'Claimed';

  @override
  String get bountyFeedPostButtonLabel => 'Post bounty';

  @override
  String get bountyFeedPeersButtonLabel => 'Nearby phones';

  @override
  String get bountyFeedAuthorYou => 'You';

  @override
  String get bountyFeedStatusOpen => 'open';

  @override
  String get bountyFeedStatusClaimed => 'claimed';

  @override
  String get bountyFeedStatusDone => 'done';

  @override
  String get bountyFeedStatusPaid => 'paid';

  @override
  String get bountyFeedStatusCancelled => 'cancelled';

  @override
  String get bountyFeedExpired => 'Expired';

  @override
  String get bountyFeedViaInternet => 'online';

  @override
  String get bountyFeedPosterAway => 'poster away';

  @override
  String get bountyFeedMyClaimPending => 'you asked';

  @override
  String get bountyFeedMyClaimAccepted => 'yours';

  @override
  String get bountyFeedMyClaimDeclined => 'not you';

  @override
  String get bountyFeedMyClaimDone => 'you finished';

  @override
  String bountyFeedTimeLeftDays(int days) {
    return '${days}d left';
  }

  @override
  String bountyFeedTimeLeftHours(int hours) {
    return '${hours}h left';
  }

  @override
  String bountyFeedTimeLeftMinutes(int minutes) {
    return '${minutes}m left';
  }

  @override
  String get bountyFeedMeshStopped => 'Mesh off';

  @override
  String get bountyFeedMeshWaiting => 'Turn Bluetooth on';

  @override
  String get bountyFeedMeshUnauthorized => 'Bluetooth permission needed';

  @override
  String get bountyFeedMeshUnsupported => 'No Bluetooth LE';

  @override
  String bountyFeedMeshRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peers in range',
      one: '1 peer in range',
      zero: 'Nobody in range',
    );
    return '$_temp0';
  }

  @override
  String get bountyFeedRelayConnected => 'Online';

  @override
  String get bountyFeedRetryButtonLabel => 'Try again';

  @override
  String get bountyFeedMeshUnavailableTitle => 'The radio could not start';

  @override
  String get bountyFeedMeshUnavailableBody =>
      'Bluetooth needs to be on for phones nearby to hear each other.';

  @override
  String get bountyFeedMeshUnauthorizedBody =>
      'Radius needs the Bluetooth permission to find phones nearby. Allow it in Settings and try again.';

  @override
  String get bountyFeedMeshUnsupportedBody =>
      'This phone has no Bluetooth LE, so it cannot join the mesh.';

  @override
  String get bountyFeedCacheFailedTitle => 'Could not read saved bounties';

  @override
  String get bountyFeedCacheFailedBody =>
      'Storage on this phone is not working. New bounties will still show while the app is open.';

  @override
  String get bountyFeedEmptyNearbyTitle => 'Nothing nearby yet';

  @override
  String get bountyFeedEmptyNearbyBody =>
      'Bounties posted by phones in range show up here.';

  @override
  String get bountyFeedEmptyMineTitle => 'You have not posted anything';

  @override
  String get bountyFeedEmptyMineBody =>
      'Post a task and whoever is in range can pick it up.';

  @override
  String get bountyFeedEmptyClaimedTitle => 'No claims yet';

  @override
  String get bountyFeedEmptyClaimedBody =>
      'Bounties you offer to do show up here.';

  @override
  String get bountyCreateAppBarTitle => 'Post a bounty';

  @override
  String get bountyCreateCancelButtonLabel => 'Cancel';

  @override
  String get bountyCreateTitleLabel => 'What needs doing?';

  @override
  String get bountyCreateTitleHint => 'Carry a booth to hall B';

  @override
  String get bountyCreateTitleEmptyError => 'A title is needed.';

  @override
  String get bountyCreateTitleTooLongError =>
      'Keep the title under 100 characters.';

  @override
  String get bountyCreateAmountLabel => 'Amount';

  @override
  String get bountyCreateAmountHint => '25';

  @override
  String get bountyCreateAmountSuffix => 'EUR';

  @override
  String get bountyCreateAmountEmptyError => 'How much is it worth?';

  @override
  String get bountyCreateAmountInvalidError =>
      'Enter an amount like 25 or 12.50.';

  @override
  String get bountyCreateAmountNotPositiveError =>
      'The amount has to be more than zero.';

  @override
  String get bountyCreateAmountTooLargeError =>
      'That is more than anyone nearby can pay.';

  @override
  String get bountyCreateDetailsLabel => 'Details';

  @override
  String get bountyCreateDetailsHint => 'Where, when, anything else';

  @override
  String get bountyCreateDetailsTooLongError =>
      'Keep the details under 500 characters.';

  @override
  String get bountyCreateExpiryLabel => 'Needed within';

  @override
  String bountyCreateExpiryPresetHours(int hours) {
    return '$hours h';
  }

  @override
  String bountyCreateExpiryPresetDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get bountyCreateExpiryCustomLabel => 'Pick a time';

  @override
  String bountyCreateExpiresAt(String when) {
    return 'Expires $when';
  }

  @override
  String get bountyCreateSubmitButtonLabel => 'Post bounty';

  @override
  String get bountyCreateValidationErrorMessage => 'Check the fields above.';

  @override
  String get bountyCreateMeshNotRunningErrorMessage =>
      'Neither the radio nor the internet is up, so nobody can hear this yet.';

  @override
  String get bountyCreateSendErrorMessage =>
      'The radio would not take it. Try again.';

  @override
  String get bountyCreateCacheErrorMessage =>
      'Could not save this on your phone.';

  @override
  String get bountyCreateGenericErrorMessage => 'Something went wrong.';

  @override
  String get bountyDetailAppBarTitle => 'Bounty';

  @override
  String get bountyDetailBackButtonLabel => 'Back';

  @override
  String get bountyDetailNotFoundTitle => 'Bounty not found';

  @override
  String get bountyDetailNotFoundBody => 'It is not on this phone any more.';

  @override
  String get bountyDetailAuthorYou => 'Posted by you';

  @override
  String bountyDetailAuthorLabel(String label) {
    return 'Posted by $label';
  }

  @override
  String bountyDetailExpiresAt(String when) {
    return 'Expires $when';
  }

  @override
  String get bountyDetailExpired => 'Expired';

  @override
  String bountyDetailClaimedBy(String label) {
    return 'Doing it: $label';
  }

  @override
  String get bountyDetailViaInternet =>
      'Seen over the internet, not the radio. A claim travels the same way, encrypted to the poster.';

  @override
  String bountyDetailPosterAway(int minutes) {
    return 'Nothing from the poster for $minutes minutes. Their phone may be off or out of reach. A claim waits until they are back.';
  }

  @override
  String get bountyDetailStatusOpen => 'open';

  @override
  String get bountyDetailStatusClaimed => 'claimed';

  @override
  String get bountyDetailStatusDone => 'done';

  @override
  String get bountyDetailStatusPaid => 'paid';

  @override
  String get bountyDetailStatusCancelled => 'cancelled';

  @override
  String get bountyDetailNotClaimable => 'This bounty is no longer open.';

  @override
  String get bountyDetailNoteLabel => 'A note for the poster';

  @override
  String get bountyDetailNoteHint => 'I am two floors down, five minutes.';

  @override
  String get bountyDetailClaimButtonLabel => 'Claim this bounty';

  @override
  String get bountyDetailMyClaimPending =>
      'You offered to do this. The poster\'s phone has not confirmed it arrived yet.';

  @override
  String get bountyDetailMyClaimDelivered =>
      'You offered to do this. Delivered to the poster\'s phone, waiting for them.';

  @override
  String get bountyDetailMyClaimAccepted =>
      'You are doing this one. Tell the poster when it is done.';

  @override
  String get bountyDetailMyClaimDeclined => 'The poster picked somebody else.';

  @override
  String get bountyDetailMyClaimDone => 'You marked this done.';

  @override
  String get bountyDetailDoneButtonLabel => 'I am done';

  @override
  String bountyDetailClaimsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count claims',
      one: '1 claim',
      zero: 'Claims',
    );
    return '$_temp0';
  }

  @override
  String get bountyDetailNoClaimsYet =>
      'Nobody has offered yet. Phones in range see it as long as it is open.';

  @override
  String get bountyDetailAcceptButtonLabel => 'Accept';

  @override
  String get bountyDetailDeclineButtonLabel => 'Decline';

  @override
  String get bountyDetailClaimPending => 'waiting';

  @override
  String get bountyDetailClaimAccepted => 'accepted';

  @override
  String get bountyDetailClaimDeclined => 'declined';

  @override
  String get bountyDetailClaimDone => 'done';

  @override
  String get bountyDetailMarkDoneButtonLabel => 'Mark done';

  @override
  String get bountyDetailMarkPaidButtonLabel => 'Mark paid';

  @override
  String get bountyDetailCancelButtonLabel => 'Cancel bounty';

  @override
  String get bountyDetailClosedErrorMessage => 'This bounty is no longer open.';

  @override
  String get bountyDetailMeshNotRunningErrorMessage =>
      'Neither the radio nor the internet is up, so nobody can hear this yet.';

  @override
  String get bountyDetailSendErrorMessage =>
      'The radio would not take it. Try again.';

  @override
  String get bountyDetailCacheErrorMessage =>
      'Could not save this on your phone.';

  @override
  String get bountyDetailValidationErrorMessage => 'That does not work here.';

  @override
  String get bountyDetailGenericErrorMessage => 'Something went wrong.';

  @override
  String get onboardingWelcomeTitle => 'Bounties for whoever is in range';

  @override
  String get onboardingWelcomeBody =>
      'Post a task and a price. Phones nearby see it over Bluetooth, no internet, no server, no account. Somebody claims it, does it, and gets paid.';

  @override
  String get onboardingIdentityTitleLoading => 'Making you an identity';

  @override
  String onboardingIdentityTitle(String label) {
    return 'You are $label';
  }

  @override
  String get onboardingIdentityBody =>
      'That is the name phones nearby will know you by. It was made on this phone just now and never leaves it. The address below reaches you over the internet, once somebody has met you on the mesh.';

  @override
  String get onboardingNpubLabel => 'Nostr address';

  @override
  String get onboardingCopyNpubLabel => 'Copy address';

  @override
  String get onboardingNpubCopied => 'Address copied.';

  @override
  String get onboardingRadioTitle => 'Bluetooth is the network';

  @override
  String get onboardingRadioBody =>
      'Radius uses Bluetooth to find phones around you and pass bounties along, even through phones in between. It never uses it to work out where you are. It will also ask for your position once, to file bounties by area over the internet; only a coarse grid cell ever leaves the phone.';

  @override
  String get onboardingNextButtonLabel => 'Next';

  @override
  String get onboardingStartButtonLabel => 'Turn on the radio';

  @override
  String get peersAppBarTitle => 'Nearby phones';

  @override
  String get peersBackButtonLabel => 'Back';

  @override
  String get peersMeLoading => 'This phone';

  @override
  String peersMeTitle(String label) {
    return 'You are $label';
  }

  @override
  String get peersMeshRunning => 'Radio on';

  @override
  String get peersMeshStopped => 'Radio off';

  @override
  String get peersMeshWaiting => 'Bluetooth off';

  @override
  String get peersMeshUnauthorized => 'No Bluetooth permission';

  @override
  String get peersMeshUnsupported => 'No Bluetooth LE';

  @override
  String get peersRelayConnected => 'Internet path up';

  @override
  String get peersRelayConnecting => 'Reaching relays';

  @override
  String get peersRelayStopped => 'No internet path';

  @override
  String peersInRangeTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phones in range',
      one: '1 phone in range',
      zero: 'Nobody in range',
    );
    return '$_temp0';
  }

  @override
  String get peersEmptyTitle => 'Nobody yet';

  @override
  String peersEmptyBodyRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count radios are nearby but none has said hello yet.',
      one: 'One radio is nearby but has not said hello yet.',
      zero:
          'The radio is scanning. Phones running Radius appear here as they come into range.',
    );
    return '$_temp0';
  }

  @override
  String get peersEmptyBodyStopped =>
      'The radio is not running, so nobody can be found.';

  @override
  String get peersPeerInRange => 'In range';

  @override
  String get peersPeerOutOfRange => 'Met before, out of range';

  @override
  String get peersPeerSecure => 'secure';

  @override
  String get peersPeerOnline => 'online';

  @override
  String get notificationChannelName => 'Bounties';

  @override
  String get notificationChannelDescription =>
      'New bounties nearby and news about your claims.';

  @override
  String notificationNewBountyTitle(String title) {
    return 'New bounty nearby: $title';
  }

  @override
  String notificationNewBountyBody(String amount, String label) {
    return '$amount from $label';
  }

  @override
  String notificationClaimReceivedTitle(String label, String title) {
    return '$label wants to do $title';
  }

  @override
  String get notificationClaimReceivedBodyEmpty =>
      'Open it to accept or decline.';

  @override
  String notificationClaimAcceptedTitle(String label, String title) {
    return '$label picked you for $title';
  }

  @override
  String get notificationClaimAcceptedBody =>
      'It is yours. Tell them when it is done.';

  @override
  String notificationClaimDeclinedTitle(String label, String title) {
    return '$label passed on your claim for $title';
  }

  @override
  String get notificationClaimDeclinedBody => 'Somebody else may be doing it.';

  @override
  String notificationClaimantDoneTitle(String label, String title) {
    return '$label says $title is done';
  }

  @override
  String get notificationClaimantDoneBody => 'Open it to mark done and paid.';

  @override
  String notificationBountyDoneTitle(String title) {
    return '$title is marked done';
  }

  @override
  String notificationBountyDoneBody(String label) {
    return '$label confirmed it. Payment comes next.';
  }

  @override
  String notificationBountyPaidTitle(String title) {
    return '$title is paid';
  }

  @override
  String notificationBountyPaidBody(String amount, String label) {
    return '$amount from $label. Nice work.';
  }

  @override
  String get settingsAppBarTitle => 'Settings';

  @override
  String get settingsBackButtonLabel => 'Back';

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsDarkModeLight => 'Light';

  @override
  String get settingsDarkModeDark => 'Dark';

  @override
  String get settingsDarkModeSystem => 'System';

  @override
  String get settingsPreferenceFailed =>
      'Could not save that. It applies until the app closes.';

  @override
  String get settingsIdentityTitle => 'Identity';

  @override
  String get settingsIdentityLoading => 'Loading your identity';

  @override
  String settingsIdentityLabel(String label) {
    return 'You are $label';
  }

  @override
  String settingsIdentityPeerId(String peerId) {
    return 'Mesh id $peerId';
  }

  @override
  String get settingsNpubTitle => 'Nostr public key';

  @override
  String get settingsCopyNpubButtonLabel => 'Copy public key';

  @override
  String get settingsNpubCopied => 'Copied.';

  @override
  String get settingsDangerTitle => 'Danger zone';

  @override
  String get settingsForgetExplanation =>
      'Forgetting your identity cancels your open bounties, withdraws your claims, and then erases the seed on this phone along with everything it knows about. Anything that could not be reached at that moment stays under the old name until it expires.';

  @override
  String get settingsForgetButtonLabel => 'Forget my identity';

  @override
  String get settingsForgetInProgress => 'Forgetting';

  @override
  String get settingsForgetFailed =>
      'The seed could not be erased. Nothing has changed.';

  @override
  String get settingsForgetConfirmTitle => 'Forget this identity?';

  @override
  String get settingsForgetConfirmBody =>
      'There is no way back. Your open bounties are cancelled and your claims withdrawn first, so nobody keeps waiting on a name that is gone.';

  @override
  String get settingsForgetUnreachableTitle => 'Nobody can hear you right now';

  @override
  String settingsForgetUnreachableBody(int bounties, int claims) {
    return 'No phone is in radio range and no relay is up, so $bounties open bounties and $claims claims of yours would stay as they are under the old name until they expire. Come back into range and try again, or forget anyway.';
  }

  @override
  String settingsForgetUnreachableItem(String title) {
    return 'Still open: $title';
  }

  @override
  String get settingsForgetAnywayButtonLabel => 'Forget anyway';

  @override
  String get settingsForgetConfirmButtonLabel => 'Yes, forget it';

  @override
  String get settingsForgetKeepButtonLabel => 'Keep it';

  @override
  String get settingsForgottenTitle => 'Identity forgotten';

  @override
  String get settingsForgottenBody => 'Starting over as a new phone.';

  @override
  String get bountyFeedSettingsButtonLabel => 'Settings';

  @override
  String bountyFeedWitnesses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count witnesses',
      one: '1 witness',
    );
    return '$_temp0';
  }

  @override
  String bountyDetailWitnessesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phones in the room signed that this happened',
      one: '1 phone in the room signed that this happened',
      zero: 'Witnesses',
    );
    return '$_temp0';
  }

  @override
  String get bountyDetailNoWitnesses =>
      'No witnesses. Nobody else was in radio range when this was finished, so it rests on the word of the two of you.';
}
