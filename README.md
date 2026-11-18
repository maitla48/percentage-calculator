# Percentage Calculator — Android app

Package: `com.seotoolsarena.percentagecalculator`
Version: 1.0.0+1 • Target API 36 (Android 16) • minSdk 21 • Flutter

Inspired by percentagecalculator.net — original code, wording and design.
Not a copy of the site and not a WebView wrapper: all calculations run
natively on-device, offline, with no account.

## What it does
- What is X% of Y?
- X is what % of Y?
- X is Y% of what number?
- % increase / decrease (from → to)
- Discount & sale price (you pay / you save)
- Tip, tax & split the bill
- History (last 100, stored only on device, clearable)
- Learn tab: what a percentage is, with everyday examples
- Copy result, live calculation as you type, light/dark mode

## Ads (AdMob)
- Banner at the bottom of every screen (test ID in `lib/ads_config.dart`)
- Interstitial only after every 5th calculation, never on load or exit,
  only if already loaded — see `AdsConfig.calculationsBeforeInterstitial`
- BEFORE PRODUCTION, replace test IDs:
  1. `lib/ads_config.dart` — banner + interstitial ad unit IDs
  2. `android/app/src/main/AndroidManifest.xml` — AdMob App ID
  3. Use the real IDs from AdMob on eagle202090@yahoo.com

## Build
```bash
source ~/android-build/env.sh   # Flutter + JDK + Android SDK paths
cd percentage-calculator
flutter pub get
flutter analyze
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # build/app/outputs/bundle/release/app-release.aab
```

Signing: create a release keystore once, keep it safe, and add
`key.properties` — never commit the keystore. Upload the AAB to Play Console.

## Publish checklist (Play Console)
- [ ] Replace AdMob test IDs with real IDs, rebuild AAB
- [ ] Privacy policy URL (see PRIVACY_POLICY.md — host it, e.g. on seotoolsarena.com)
- [ ] Data Safety form: ads collect device/ad IDs via AdMob SDK; no personal data collected by the app itself; history stays on device
- [ ] Ads declaration: Yes, app contains ads
- [ ] Store listing: see STORE_LISTING.md (title, short/long description, screenshots)
- [ ] Closed test: 12 testers, 14 days (personal account created after 13 Nov 2023), then apply for production access
- [ ] App icon 512×512, feature graphic 1024×500, screenshots (phone)
