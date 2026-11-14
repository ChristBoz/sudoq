import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/app_filter.dart';

void main() {
  test('social, video and game apps are suggested', () {
    expect(isSuggestedApp(packageName: 'x.social', category: 4), isTrue);
    expect(isSuggestedApp(packageName: 'x.video', category: 2), isTrue);
    expect(isSuggestedApp(packageName: 'x.game', category: 0), isTrue);
  });

  test('well-known apps are suggested even without a category', () {
    expect(
      isSuggestedApp(packageName: 'com.zhiliaoapp.musically', category: -1),
      isTrue,
    );
  });

  test('FR02: calls and messaging are excluded by default', () {
    // WhatsApp declares itself "social", but is still left out.
    expect(isSuggestedApp(packageName: 'com.whatsapp', category: 4), isFalse);
    expect(
      isSuggestedApp(packageName: 'com.google.android.dialer', category: -1),
      isFalse,
    );
  });

  test('other apps are not suggested', () {
    expect(isSuggestedApp(packageName: 'x.maps', category: 6), isFalse);
    expect(isSuggestedApp(packageName: 'x.unknown', category: -1), isFalse);
  });
}
