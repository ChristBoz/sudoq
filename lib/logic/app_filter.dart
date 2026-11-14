// LOGIC: pure Dart rules. No Flutter, no Android, no storage.
// Decides which installed apps are offered by default on "Select apps"
// (FR02: entertainment and social apps; calls and messaging excluded).

/// Android's ApplicationInfo.category values that count as entertainment.
const Set<int> _entertainmentCategories = {
  0, // game
  1, // audio
  2, // video
  4, // social
  5, // news
};

/// Well-known entertainment apps, in case they declare no category.
const Set<String> _knownEntertainment = {
  'com.zhiliaoapp.musically', // TikTok
  'com.ss.android.ugc.trill', // TikTok (some regions)
  'com.instagram.android',
  'com.instagram.barcelona', // Threads
  'com.google.android.youtube',
  'com.facebook.katana',
  'com.facebook.lite',
  'com.snapchat.android',
  'com.twitter.android', // X
  'com.reddit.frontpage',
  'com.pinterest',
  'tv.twitch.android.app',
  'com.netflix.mediaclient',
  'com.tumblr',
  'com.discord',
};

/// Calls and essential messaging: never offered by default, even if
/// Android labels them "social".
const Set<String> _essential = {
  'com.whatsapp',
  'com.whatsapp.w4b',
  'org.telegram.messenger',
  'org.thoughtcrime.securesms', // Signal
  'com.facebook.orca', // Messenger
  'com.viber.voip',
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.google.android.dialer',
  'com.samsung.android.dialer',
  'com.samsung.android.app.contacts',
  'com.google.android.contacts',
  'com.google.android.gm', // Gmail
  'com.microsoft.office.outlook',
  'com.microsoft.teams',
  'us.zoom.videomeetings',
};

/// True when the app should be listed by default on "Select apps".
bool isSuggestedApp({required String packageName, required int category}) {
  if (_essential.contains(packageName)) return false;
  return _knownEntertainment.contains(packageName) ||
      _entertainmentCategories.contains(category);
}
