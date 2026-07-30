/// Android application id of this app, as declared in `build.gradle.kts`.
///
/// Needed wherever the app has to recognise its own notifications: the capture
/// pipeline drops them, so transaction alerts never loop back in as fresh
/// transactions, and the bank list hides us, so we never look like a bank.
const String appPackage = 'com.trustsoft.tingting';

/// What the app's two notification listeners are called in the system's
/// Notification access list, spelled exactly as they appear there.
///
/// There are two of them and both have to be on, which is not something the
/// screen can show or the app can turn on for the user. The first carries
/// notifications to Dart while the app runs; the second is bound by the system
/// and writes to disk, and is the only one still listening after HyperOS kills
/// the process on a recents swipe. Granting one and not the other leaves
/// capture looking healthy right up until that swipe, so anywhere we ask for
/// the permission has to name both — see `AndroidManifest.xml`, where the two
/// `android:label`s are these strings.
const String captureListenerName = 'Đọc thông báo ngân hàng';
const String backupListenerName = 'Ting Ting — ghi sổ thu chi';
