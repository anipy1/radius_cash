import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get appTitle;

  /// No description provided for @bountyFeedAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get bountyFeedAppBarTitle;

  /// No description provided for @bountyFeedSegmentNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get bountyFeedSegmentNearby;

  /// No description provided for @bountyFeedSegmentMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get bountyFeedSegmentMine;

  /// No description provided for @bountyFeedSegmentClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get bountyFeedSegmentClaimed;

  /// No description provided for @bountyFeedPostButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Post bounty'**
  String get bountyFeedPostButtonLabel;

  /// No description provided for @bountyFeedPeersButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Nearby phones'**
  String get bountyFeedPeersButtonLabel;

  /// No description provided for @bountyFeedAuthorYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get bountyFeedAuthorYou;

  /// No description provided for @bountyFeedStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get bountyFeedStatusOpen;

  /// No description provided for @bountyFeedStatusClaimed.
  ///
  /// In en, this message translates to:
  /// **'claimed'**
  String get bountyFeedStatusClaimed;

  /// No description provided for @bountyFeedStatusDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get bountyFeedStatusDone;

  /// No description provided for @bountyFeedStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'paid'**
  String get bountyFeedStatusPaid;

  /// No description provided for @bountyFeedStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get bountyFeedStatusCancelled;

  /// No description provided for @bountyFeedExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get bountyFeedExpired;

  /// No description provided for @bountyFeedViaInternet.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get bountyFeedViaInternet;

  /// No description provided for @bountyFeedPosterAway.
  ///
  /// In en, this message translates to:
  /// **'poster away'**
  String get bountyFeedPosterAway;

  /// No description provided for @bountyFeedMyClaimPending.
  ///
  /// In en, this message translates to:
  /// **'you asked'**
  String get bountyFeedMyClaimPending;

  /// No description provided for @bountyFeedMyClaimAccepted.
  ///
  /// In en, this message translates to:
  /// **'yours'**
  String get bountyFeedMyClaimAccepted;

  /// No description provided for @bountyFeedMyClaimDeclined.
  ///
  /// In en, this message translates to:
  /// **'not you'**
  String get bountyFeedMyClaimDeclined;

  /// No description provided for @bountyFeedMyClaimDone.
  ///
  /// In en, this message translates to:
  /// **'you finished'**
  String get bountyFeedMyClaimDone;

  /// No description provided for @bountyFeedTimeLeftDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d left'**
  String bountyFeedTimeLeftDays(int days);

  /// No description provided for @bountyFeedTimeLeftHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h left'**
  String bountyFeedTimeLeftHours(int hours);

  /// No description provided for @bountyFeedTimeLeftMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m left'**
  String bountyFeedTimeLeftMinutes(int minutes);

  /// No description provided for @bountyFeedMeshStopped.
  ///
  /// In en, this message translates to:
  /// **'Mesh off'**
  String get bountyFeedMeshStopped;

  /// No description provided for @bountyFeedMeshWaiting.
  ///
  /// In en, this message translates to:
  /// **'Turn Bluetooth on'**
  String get bountyFeedMeshWaiting;

  /// No description provided for @bountyFeedMeshUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission needed'**
  String get bountyFeedMeshUnauthorized;

  /// No description provided for @bountyFeedMeshUnsupported.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth LE'**
  String get bountyFeedMeshUnsupported;

  /// No description provided for @bountyFeedMeshRunning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody in range} =1{1 peer in range} other{{count} peers in range}}'**
  String bountyFeedMeshRunning(int count);

  /// No description provided for @bountyFeedRelayConnected.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get bountyFeedRelayConnected;

  /// No description provided for @bountyFeedRetryButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get bountyFeedRetryButtonLabel;

  /// No description provided for @bountyFeedMeshUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'The radio could not start'**
  String get bountyFeedMeshUnavailableTitle;

  /// No description provided for @bountyFeedMeshUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth needs to be on for phones nearby to hear each other.'**
  String get bountyFeedMeshUnavailableBody;

  /// No description provided for @bountyFeedMeshUnauthorizedBody.
  ///
  /// In en, this message translates to:
  /// **'Radius needs the Bluetooth permission to find phones nearby. Allow it in Settings and try again.'**
  String get bountyFeedMeshUnauthorizedBody;

  /// No description provided for @bountyFeedMeshUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'This phone has no Bluetooth LE, so it cannot join the mesh.'**
  String get bountyFeedMeshUnsupportedBody;

  /// No description provided for @bountyFeedCacheFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not read saved bounties'**
  String get bountyFeedCacheFailedTitle;

  /// No description provided for @bountyFeedCacheFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Storage on this phone is not working. New bounties will still show while the app is open.'**
  String get bountyFeedCacheFailedBody;

  /// No description provided for @bountyFeedEmptyNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing nearby yet'**
  String get bountyFeedEmptyNearbyTitle;

  /// No description provided for @bountyFeedEmptyNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Bounties posted by phones in range show up here.'**
  String get bountyFeedEmptyNearbyBody;

  /// No description provided for @bountyFeedEmptyMineTitle.
  ///
  /// In en, this message translates to:
  /// **'You have not posted anything'**
  String get bountyFeedEmptyMineTitle;

  /// No description provided for @bountyFeedEmptyMineBody.
  ///
  /// In en, this message translates to:
  /// **'Post a task and whoever is in range can pick it up.'**
  String get bountyFeedEmptyMineBody;

  /// No description provided for @bountyFeedEmptyClaimedTitle.
  ///
  /// In en, this message translates to:
  /// **'No claims yet'**
  String get bountyFeedEmptyClaimedTitle;

  /// No description provided for @bountyFeedEmptyClaimedBody.
  ///
  /// In en, this message translates to:
  /// **'Bounties you offer to do show up here.'**
  String get bountyFeedEmptyClaimedBody;

  /// No description provided for @bountyCreateAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Post a bounty'**
  String get bountyCreateAppBarTitle;

  /// No description provided for @bountyCreateCancelButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bountyCreateCancelButtonLabel;

  /// No description provided for @bountyCreateTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'What needs doing?'**
  String get bountyCreateTitleLabel;

  /// No description provided for @bountyCreateTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Carry a booth to hall B'**
  String get bountyCreateTitleHint;

  /// No description provided for @bountyCreateTitleEmptyError.
  ///
  /// In en, this message translates to:
  /// **'A title is needed.'**
  String get bountyCreateTitleEmptyError;

  /// No description provided for @bountyCreateTitleTooLongError.
  ///
  /// In en, this message translates to:
  /// **'Keep the title under 100 characters.'**
  String get bountyCreateTitleTooLongError;

  /// No description provided for @bountyCreateAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get bountyCreateAmountLabel;

  /// No description provided for @bountyCreateAmountHint.
  ///
  /// In en, this message translates to:
  /// **'25'**
  String get bountyCreateAmountHint;

  /// No description provided for @bountyCreateAmountSuffix.
  ///
  /// In en, this message translates to:
  /// **'EUR'**
  String get bountyCreateAmountSuffix;

  /// No description provided for @bountyCreateAmountEmptyError.
  ///
  /// In en, this message translates to:
  /// **'How much is it worth?'**
  String get bountyCreateAmountEmptyError;

  /// No description provided for @bountyCreateAmountInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 25 or 12.50.'**
  String get bountyCreateAmountInvalidError;

  /// No description provided for @bountyCreateAmountNotPositiveError.
  ///
  /// In en, this message translates to:
  /// **'The amount has to be more than zero.'**
  String get bountyCreateAmountNotPositiveError;

  /// No description provided for @bountyCreateAmountTooLargeError.
  ///
  /// In en, this message translates to:
  /// **'That is more than anyone nearby can pay.'**
  String get bountyCreateAmountTooLargeError;

  /// No description provided for @bountyCreateDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get bountyCreateDetailsLabel;

  /// No description provided for @bountyCreateDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Where, when, anything else'**
  String get bountyCreateDetailsHint;

  /// No description provided for @bountyCreateDetailsTooLongError.
  ///
  /// In en, this message translates to:
  /// **'Keep the details under 500 characters.'**
  String get bountyCreateDetailsTooLongError;

  /// No description provided for @bountyCreateExpiryLabel.
  ///
  /// In en, this message translates to:
  /// **'Needed within'**
  String get bountyCreateExpiryLabel;

  /// No description provided for @bountyCreateExpiryPresetHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String bountyCreateExpiryPresetHours(int hours);

  /// No description provided for @bountyCreateExpiryPresetDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String bountyCreateExpiryPresetDays(int days);

  /// No description provided for @bountyCreateExpiryCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get bountyCreateExpiryCustomLabel;

  /// No description provided for @bountyCreateExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires {when}'**
  String bountyCreateExpiresAt(String when);

  /// No description provided for @bountyCreateSubmitButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Post bounty'**
  String get bountyCreateSubmitButtonLabel;

  /// No description provided for @bountyCreateValidationErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check the fields above.'**
  String get bountyCreateValidationErrorMessage;

  /// No description provided for @bountyCreateMeshNotRunningErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Neither the radio nor the internet is up, so nobody can hear this yet.'**
  String get bountyCreateMeshNotRunningErrorMessage;

  /// No description provided for @bountyCreateSendErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The radio would not take it. Try again.'**
  String get bountyCreateSendErrorMessage;

  /// No description provided for @bountyCreateCacheErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not save this on your phone.'**
  String get bountyCreateCacheErrorMessage;

  /// No description provided for @bountyCreateGenericErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get bountyCreateGenericErrorMessage;

  /// No description provided for @bountyDetailAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Bounty'**
  String get bountyDetailAppBarTitle;

  /// No description provided for @bountyDetailBackButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get bountyDetailBackButtonLabel;

  /// No description provided for @bountyDetailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Bounty not found'**
  String get bountyDetailNotFoundTitle;

  /// No description provided for @bountyDetailNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It is not on this phone any more.'**
  String get bountyDetailNotFoundBody;

  /// No description provided for @bountyDetailAuthorYou.
  ///
  /// In en, this message translates to:
  /// **'Posted by you'**
  String get bountyDetailAuthorYou;

  /// No description provided for @bountyDetailAuthorLabel.
  ///
  /// In en, this message translates to:
  /// **'Posted by {label}'**
  String bountyDetailAuthorLabel(String label);

  /// No description provided for @bountyDetailExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires {when}'**
  String bountyDetailExpiresAt(String when);

  /// No description provided for @bountyDetailExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get bountyDetailExpired;

  /// No description provided for @bountyDetailClaimedBy.
  ///
  /// In en, this message translates to:
  /// **'Doing it: {label}'**
  String bountyDetailClaimedBy(String label);

  /// No description provided for @bountyDetailViaInternet.
  ///
  /// In en, this message translates to:
  /// **'Seen over the internet, not the radio. A claim travels the same way, encrypted to the poster.'**
  String get bountyDetailViaInternet;

  /// No description provided for @bountyDetailPosterAway.
  ///
  /// In en, this message translates to:
  /// **'Nothing from the poster for {minutes} minutes. Their phone may be off or out of reach. A claim waits until they are back.'**
  String bountyDetailPosterAway(int minutes);

  /// No description provided for @bountyDetailStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get bountyDetailStatusOpen;

  /// No description provided for @bountyDetailStatusClaimed.
  ///
  /// In en, this message translates to:
  /// **'claimed'**
  String get bountyDetailStatusClaimed;

  /// No description provided for @bountyDetailStatusDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get bountyDetailStatusDone;

  /// No description provided for @bountyDetailStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'paid'**
  String get bountyDetailStatusPaid;

  /// No description provided for @bountyDetailStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get bountyDetailStatusCancelled;

  /// No description provided for @bountyDetailNotClaimable.
  ///
  /// In en, this message translates to:
  /// **'This bounty is no longer open.'**
  String get bountyDetailNotClaimable;

  /// No description provided for @bountyDetailNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'A note for the poster'**
  String get bountyDetailNoteLabel;

  /// No description provided for @bountyDetailNoteHint.
  ///
  /// In en, this message translates to:
  /// **'I am two floors down, five minutes.'**
  String get bountyDetailNoteHint;

  /// No description provided for @bountyDetailClaimButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Claim this bounty'**
  String get bountyDetailClaimButtonLabel;

  /// No description provided for @bountyDetailMyClaimPending.
  ///
  /// In en, this message translates to:
  /// **'You offered to do this. The poster\'s phone has not confirmed it arrived yet.'**
  String get bountyDetailMyClaimPending;

  /// No description provided for @bountyDetailMyClaimDelivered.
  ///
  /// In en, this message translates to:
  /// **'You offered to do this. Delivered to the poster\'s phone, waiting for them.'**
  String get bountyDetailMyClaimDelivered;

  /// No description provided for @bountyDetailMyClaimAccepted.
  ///
  /// In en, this message translates to:
  /// **'You are doing this one. Tell the poster when it is done.'**
  String get bountyDetailMyClaimAccepted;

  /// No description provided for @bountyDetailMyClaimDeclined.
  ///
  /// In en, this message translates to:
  /// **'The poster picked somebody else.'**
  String get bountyDetailMyClaimDeclined;

  /// No description provided for @bountyDetailMyClaimDone.
  ///
  /// In en, this message translates to:
  /// **'You marked this done.'**
  String get bountyDetailMyClaimDone;

  /// No description provided for @bountyDetailDoneButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'I am done'**
  String get bountyDetailDoneButtonLabel;

  /// No description provided for @bountyDetailClaimsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Claims} =1{1 claim} other{{count} claims}}'**
  String bountyDetailClaimsTitle(int count);

  /// No description provided for @bountyDetailNoClaimsYet.
  ///
  /// In en, this message translates to:
  /// **'Nobody has offered yet. Phones in range see it as long as it is open.'**
  String get bountyDetailNoClaimsYet;

  /// No description provided for @bountyDetailAcceptButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get bountyDetailAcceptButtonLabel;

  /// No description provided for @bountyDetailDeclineButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get bountyDetailDeclineButtonLabel;

  /// No description provided for @bountyDetailClaimPending.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get bountyDetailClaimPending;

  /// No description provided for @bountyDetailClaimAccepted.
  ///
  /// In en, this message translates to:
  /// **'accepted'**
  String get bountyDetailClaimAccepted;

  /// No description provided for @bountyDetailClaimDeclined.
  ///
  /// In en, this message translates to:
  /// **'declined'**
  String get bountyDetailClaimDeclined;

  /// No description provided for @bountyDetailClaimDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get bountyDetailClaimDone;

  /// No description provided for @bountyDetailMarkDoneButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get bountyDetailMarkDoneButtonLabel;

  /// No description provided for @bountyDetailMarkPaidButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get bountyDetailMarkPaidButtonLabel;

  /// No description provided for @bountyDetailCancelButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel bounty'**
  String get bountyDetailCancelButtonLabel;

  /// No description provided for @bountyDetailClosedErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'This bounty is no longer open.'**
  String get bountyDetailClosedErrorMessage;

  /// No description provided for @bountyDetailMeshNotRunningErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Neither the radio nor the internet is up, so nobody can hear this yet.'**
  String get bountyDetailMeshNotRunningErrorMessage;

  /// No description provided for @bountyDetailSendErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The radio would not take it. Try again.'**
  String get bountyDetailSendErrorMessage;

  /// No description provided for @bountyDetailCacheErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not save this on your phone.'**
  String get bountyDetailCacheErrorMessage;

  /// No description provided for @bountyDetailValidationErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'That does not work here.'**
  String get bountyDetailValidationErrorMessage;

  /// No description provided for @bountyDetailGenericErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get bountyDetailGenericErrorMessage;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Bounties for whoever is in range'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Post a task and a price. Phones nearby see it over Bluetooth, no internet, no server, no account. Somebody claims it, does it, and gets paid.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingIdentityTitleLoading.
  ///
  /// In en, this message translates to:
  /// **'Making you an identity'**
  String get onboardingIdentityTitleLoading;

  /// No description provided for @onboardingIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'You are {label}'**
  String onboardingIdentityTitle(String label);

  /// No description provided for @onboardingIdentityBody.
  ///
  /// In en, this message translates to:
  /// **'That is the name phones nearby will know you by. It was made on this phone just now and never leaves it. The address below reaches you over the internet, once somebody has met you on the mesh.'**
  String get onboardingIdentityBody;

  /// No description provided for @onboardingNpubLabel.
  ///
  /// In en, this message translates to:
  /// **'Nostr address'**
  String get onboardingNpubLabel;

  /// No description provided for @onboardingCopyNpubLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get onboardingCopyNpubLabel;

  /// No description provided for @onboardingNpubCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied.'**
  String get onboardingNpubCopied;

  /// No description provided for @onboardingRadioTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is the network'**
  String get onboardingRadioTitle;

  /// No description provided for @onboardingRadioBody.
  ///
  /// In en, this message translates to:
  /// **'Radius uses Bluetooth to find phones around you and pass bounties along, even through phones in between. It never uses it to work out where you are. It will also ask for your position once, to file bounties by area over the internet; only a coarse grid cell ever leaves the phone.'**
  String get onboardingRadioBody;

  /// No description provided for @onboardingNextButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNextButtonLabel;

  /// No description provided for @onboardingStartButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Turn on the radio'**
  String get onboardingStartButtonLabel;

  /// No description provided for @peersAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby phones'**
  String get peersAppBarTitle;

  /// No description provided for @peersBackButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get peersBackButtonLabel;

  /// No description provided for @peersMeLoading.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get peersMeLoading;

  /// No description provided for @peersMeTitle.
  ///
  /// In en, this message translates to:
  /// **'You are {label}'**
  String peersMeTitle(String label);

  /// No description provided for @peersMeshRunning.
  ///
  /// In en, this message translates to:
  /// **'Radio on'**
  String get peersMeshRunning;

  /// No description provided for @peersMeshStopped.
  ///
  /// In en, this message translates to:
  /// **'Radio off'**
  String get peersMeshStopped;

  /// No description provided for @peersMeshWaiting.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth off'**
  String get peersMeshWaiting;

  /// No description provided for @peersMeshUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth permission'**
  String get peersMeshUnauthorized;

  /// No description provided for @peersMeshUnsupported.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth LE'**
  String get peersMeshUnsupported;

  /// No description provided for @peersRelayConnected.
  ///
  /// In en, this message translates to:
  /// **'Internet path up'**
  String get peersRelayConnected;

  /// No description provided for @peersRelayConnecting.
  ///
  /// In en, this message translates to:
  /// **'Reaching relays'**
  String get peersRelayConnecting;

  /// No description provided for @peersRelayStopped.
  ///
  /// In en, this message translates to:
  /// **'No internet path'**
  String get peersRelayStopped;

  /// No description provided for @peersInRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody in range} =1{1 phone in range} other{{count} phones in range}}'**
  String peersInRangeTitle(int count);

  /// No description provided for @peersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get peersEmptyTitle;

  /// No description provided for @peersEmptyBodyRunning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{The radio is scanning. Phones running Radius appear here as they come into range.} =1{One radio is nearby but has not said hello yet.} other{{count} radios are nearby but none has said hello yet.}}'**
  String peersEmptyBodyRunning(int count);

  /// No description provided for @peersEmptyBodyStopped.
  ///
  /// In en, this message translates to:
  /// **'The radio is not running, so nobody can be found.'**
  String get peersEmptyBodyStopped;

  /// No description provided for @peersPeerInRange.
  ///
  /// In en, this message translates to:
  /// **'In range'**
  String get peersPeerInRange;

  /// No description provided for @peersPeerOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Met before, out of range'**
  String get peersPeerOutOfRange;

  /// No description provided for @peersPeerSecure.
  ///
  /// In en, this message translates to:
  /// **'secure'**
  String get peersPeerSecure;

  /// No description provided for @peersPeerOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get peersPeerOnline;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Bounties'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'New bounties nearby and news about your claims.'**
  String get notificationChannelDescription;

  /// No description provided for @notificationNewBountyTitle.
  ///
  /// In en, this message translates to:
  /// **'New bounty nearby: {title}'**
  String notificationNewBountyTitle(String title);

  /// No description provided for @notificationNewBountyBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} from {label}'**
  String notificationNewBountyBody(String amount, String label);

  /// No description provided for @notificationClaimReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} wants to do {title}'**
  String notificationClaimReceivedTitle(String label, String title);

  /// No description provided for @notificationClaimReceivedBodyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open it to accept or decline.'**
  String get notificationClaimReceivedBodyEmpty;

  /// No description provided for @notificationClaimAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} picked you for {title}'**
  String notificationClaimAcceptedTitle(String label, String title);

  /// No description provided for @notificationClaimAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'It is yours. Tell them when it is done.'**
  String get notificationClaimAcceptedBody;

  /// No description provided for @notificationClaimDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} passed on your claim for {title}'**
  String notificationClaimDeclinedTitle(String label, String title);

  /// No description provided for @notificationClaimDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'Somebody else may be doing it.'**
  String get notificationClaimDeclinedBody;

  /// No description provided for @notificationClaimantDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} says {title} is done'**
  String notificationClaimantDoneTitle(String label, String title);

  /// No description provided for @notificationClaimantDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Open it to mark done and paid.'**
  String get notificationClaimantDoneBody;

  /// No description provided for @notificationBountyDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} is marked done'**
  String notificationBountyDoneTitle(String title);

  /// No description provided for @notificationBountyDoneBody.
  ///
  /// In en, this message translates to:
  /// **'{label} confirmed it. Payment comes next.'**
  String notificationBountyDoneBody(String label);

  /// No description provided for @notificationBountyPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} is paid'**
  String notificationBountyPaidTitle(String title);

  /// No description provided for @notificationBountyPaidBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} from {label}. Nice work.'**
  String notificationBountyPaidBody(String amount, String label);

  /// No description provided for @settingsAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsAppBarTitle;

  /// No description provided for @settingsBackButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get settingsBackButtonLabel;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsDarkModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsDarkModeLight;

  /// No description provided for @settingsDarkModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDarkModeDark;

  /// No description provided for @settingsDarkModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsDarkModeSystem;

  /// No description provided for @settingsPreferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save that. It applies until the app closes.'**
  String get settingsPreferenceFailed;

  /// No description provided for @settingsIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get settingsIdentityTitle;

  /// No description provided for @settingsIdentityLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your identity'**
  String get settingsIdentityLoading;

  /// No description provided for @settingsIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'You are {label}'**
  String settingsIdentityLabel(String label);

  /// No description provided for @settingsIdentityPeerId.
  ///
  /// In en, this message translates to:
  /// **'Mesh id {peerId}'**
  String settingsIdentityPeerId(String peerId);

  /// No description provided for @settingsNpubTitle.
  ///
  /// In en, this message translates to:
  /// **'Nostr public key'**
  String get settingsNpubTitle;

  /// No description provided for @settingsCopyNpubButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get settingsCopyNpubButtonLabel;

  /// No description provided for @settingsNpubCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied.'**
  String get settingsNpubCopied;

  /// No description provided for @settingsDangerTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerTitle;

  /// No description provided for @settingsForgetExplanation.
  ///
  /// In en, this message translates to:
  /// **'Forgetting your identity cancels your open bounties, withdraws your claims, and then erases the seed on this phone along with everything it knows about. Anything that could not be reached at that moment stays under the old name until it expires.'**
  String get settingsForgetExplanation;

  /// No description provided for @settingsForgetButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Forget my identity'**
  String get settingsForgetButtonLabel;

  /// No description provided for @settingsForgetInProgress.
  ///
  /// In en, this message translates to:
  /// **'Forgetting'**
  String get settingsForgetInProgress;

  /// No description provided for @settingsForgetFailed.
  ///
  /// In en, this message translates to:
  /// **'The seed could not be erased. Nothing has changed.'**
  String get settingsForgetFailed;

  /// No description provided for @settingsForgetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget this identity?'**
  String get settingsForgetConfirmTitle;

  /// No description provided for @settingsForgetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'There is no way back. Your open bounties are cancelled and your claims withdrawn first, so nobody keeps waiting on a name that is gone.'**
  String get settingsForgetConfirmBody;

  /// No description provided for @settingsForgetUnreachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Nobody can hear you right now'**
  String get settingsForgetUnreachableTitle;

  /// No description provided for @settingsForgetUnreachableBody.
  ///
  /// In en, this message translates to:
  /// **'No phone is in radio range and no relay is up, so {bounties} open bounties and {claims} claims of yours would stay as they are under the old name until they expire. Come back into range and try again, or forget anyway.'**
  String settingsForgetUnreachableBody(int bounties, int claims);

  /// No description provided for @settingsForgetUnreachableItem.
  ///
  /// In en, this message translates to:
  /// **'Still open: {title}'**
  String settingsForgetUnreachableItem(String title);

  /// No description provided for @settingsForgetAnywayButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Forget anyway'**
  String get settingsForgetAnywayButtonLabel;

  /// No description provided for @settingsForgetConfirmButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Yes, forget it'**
  String get settingsForgetConfirmButtonLabel;

  /// No description provided for @settingsForgetKeepButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get settingsForgetKeepButtonLabel;

  /// No description provided for @settingsForgottenTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity forgotten'**
  String get settingsForgottenTitle;

  /// No description provided for @settingsForgottenBody.
  ///
  /// In en, this message translates to:
  /// **'Starting over as a new phone.'**
  String get settingsForgottenBody;

  /// No description provided for @bountyFeedSettingsButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get bountyFeedSettingsButtonLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
