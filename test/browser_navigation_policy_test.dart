import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/ui/browser/browser_navigation_policy.dart';

void main() {
  test('YouTube app links resolve to websites in the same browser', () {
    for (final link in [
      'youtube://dQw4w9WgXcQ',
      'youtube://watch?v=dQw4w9WgXcQ',
      'vnd.youtube:dQw4w9WgXcQ',
    ]) {
      expect(
        browserWebDestination(link).toString(),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    }
    expect(
      browserWebDestination('youtube://').toString(),
      'https://www.youtube.com/',
    );
  });

  test('Facebook app links and Android intents retain web destinations', () {
    expect(
      browserWebDestination('fb://profile/123456').toString(),
      'https://www.facebook.com/123456',
    );
    expect(
      browserWebDestination(
        'fb://facewebmodal/f?href=https%3A%2F%2Fwww.facebook.com%2Fexample',
      ).toString(),
      'https://www.facebook.com/example',
    );
    expect(
      browserWebDestination(
        'intent://www.youtube.com/watch?v=dQw4w9WgXcQ#Intent;scheme=https;package=com.google.android.youtube;end',
      ).toString(),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(
      browserWebDestination(
        'intent://launch#Intent;S.browser_fallback_url=https%3A%2F%2Fwww.facebook.com%2F;end',
      ).toString(),
      'https://www.facebook.com/',
    );
  });

  test('unknown app schemes and unsafe fallback URLs cannot be opened', () {
    for (final link in [
      'javascript:alert(1)',
      'file:///etc/passwd',
      'data:text/html,test',
      'unknown-app://launch',
      'https:///missing-host',
      'intent://launch#Intent;S.browser_fallback_url=javascript%3Aalert(1);end',
    ]) {
      expect(browserWebDestination(link), isNull, reason: link);
    }
    expect(
      browserWebDestination('https://www.youtube.com/').toString(),
      'https://www.youtube.com/',
    );
  });

  test('desktop user agent preserves the installed engine version', () {
    final chrome = desktopBrowserUserAgent(
      'Mozilla/5.0 (Linux; Android 16; wv) AppleWebKit/537.36 Version/4.0 Chrome/142.0.7444.48 Mobile Safari/537.36',
    );
    expect(chrome, contains('Chrome/142.0.7444.48'));
    expect(chrome, isNot(contains('Mobile')));
    expect(chrome, isNot(contains('wv')));
    final safari = desktopBrowserUserAgent(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/619.1.26 Mobile/15E148',
    );
    expect(safari, contains('Macintosh'));
    expect(safari, contains('AppleWebKit/619.1.26'));
    expect(safari, contains('Version/26.0'));
    expect(safari, isNot(contains('Mobile')));
  });
}
