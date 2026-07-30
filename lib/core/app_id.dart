/// Android application id of this app, as declared in `build.gradle.kts`.
///
/// Needed wherever the app has to recognise its own notifications: the capture
/// pipeline drops them, so transaction alerts never loop back in as fresh
/// transactions, and the bank list hides us, so we never look like a bank.
const String appPackage = 'com.trustsoft.tingting';
