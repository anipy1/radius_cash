/// Local notifications for things that happen while nobody is looking at the
/// screen: a bounty posted nearby, a claim on yours, an answer to your claim.
///
/// Sits beside the features: it reads repositories and never the transport,
/// and it has no widgets. main.dart builds one [BountyNotifier] and keeps it
/// for the life of the app.
library;

export 'src/bounty_notifier.dart' show BountyNotifier;
export 'src/notifier.dart' show Alert, NoNotifier, Notifier;
export 'src/local_notifier.dart' show LocalNotifier;
