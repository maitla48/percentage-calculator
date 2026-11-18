// AdMob configuration for Percentage Calculator.
//
// BEFORE PRODUCTION: replace the TEST IDs below with the real IDs from
// the AdMob account on eagle202090@yahoo.com.
// Play Console / AdMob account: eagle202090@yahoo.com
// 1. In AdMob, create an app (Android) for Percentage Calculator.
// 2. Create a Banner ad unit and an Interstitial ad unit.
// 3. Paste the real App ID into android/app/src/main/AndroidManifest.xml
//    (meta-data com.google.android.gms.ads.APPLICATION_ID).
// 4. Paste the real ad unit IDs below.
// 5. Rebuild the AAB and upload to Play Console.
//
// TEST IDs below are Google's official test IDs — they always return test
// ads and earn nothing. Never ship production with them.

class AdsConfig {
  // TODO(RELEASE): replace with real Banner ad unit ID.
  static const String bannerAdUnitId =
      'ca-app-pub-6955275421921843/1817323472';

  // TODO(RELEASE): replace with real Interstitial ad unit ID.
  static const String interstitialAdUnitId =
      'ca-app-pub-6955275421921843/7480713691';

  // Policy: never show an interstitial on app load or on exit, and never
  // more than one per two user actions. This app shows one only after
  // every 5th completed calculation, and only if one is already loaded.
  static const int calculationsBeforeInterstitial = 5;
}
